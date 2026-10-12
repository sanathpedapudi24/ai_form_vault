package com.aiformvault

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import org.json.JSONArray
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.io.File
import java.security.KeyStore
import java.security.SecureRandom
import java.util.zip.ZipEntry
import java.util.zip.ZipInputStream
import java.util.zip.ZipOutputStream
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.SecretKeyFactory
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.PBEKeySpec
import javax.crypto.spec.SecretKeySpec

/**
 * Everything at rest is AES-256-GCM with a hardware-backed Android Keystore key:
 * vault.bin (all metadata as JSON) and img/<docId>_<page>.bin (page images).
 * ponytail: whole vault is one encrypted JSON file held in memory, fine for hundreds of documents;
 * move to Room + SQLCipher if vaults grow into the thousands.
 */
object Store {
    private const val ALIAS = "vault"

    private fun key(): SecretKey {
        val ks = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (ks.getKey(ALIAS, null) as? SecretKey)?.let { return it }
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore").apply {
            init(
                KeyGenParameterSpec.Builder(ALIAS, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                    .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                    .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                    .setKeySize(256)
                    .build()
            )
        }.generateKey()
    }

    private fun seal(plain: ByteArray, k: SecretKey = key()): ByteArray {
        val c = Cipher.getInstance("AES/GCM/NoPadding").apply { init(Cipher.ENCRYPT_MODE, k) }
        return c.iv + c.doFinal(plain)
    }

    private fun open(sealed: ByteArray, k: SecretKey = key()): ByteArray {
        val c = Cipher.getInstance("AES/GCM/NoPadding").apply { init(Cipher.DECRYPT_MODE, k, GCMParameterSpec(128, sealed, 0, 12)) }
        return c.doFinal(sealed, 12, sealed.size - 12)
    }

    /** Write via temp file + rename so a crash mid-write can't corrupt the vault. */
    private fun atomicWrite(f: File, bytes: ByteArray) {
        f.parentFile?.mkdirs()
        val tmp = File(f.path + ".tmp")
        tmp.writeBytes(bytes)
        tmp.renameTo(f)
    }

    private fun vaultFile(ctx: Context) = File(ctx.filesDir, "vault.bin")
    private fun imgDir(ctx: Context) = File(ctx.filesDir, "img")
    private fun imgFile(ctx: Context, docId: String, page: Int) = File(imgDir(ctx), "${docId}_$page.bin")

    fun load(ctx: Context): VaultData = vaultFile(ctx).takeIf { it.exists() }?.let { fromJson(JSONObject(String(open(it.readBytes())))) } ?: VaultData()

    fun save(ctx: Context, data: VaultData) = atomicWrite(vaultFile(ctx), seal(toJson(data).toString().toByteArray()))

    /** Re-encodes each page as a ≤2000px JPEG before encrypting: keeps the vault small without losing readability. */
    fun saveImages(ctx: Context, docId: String, pages: List<Uri>) {
        val k = key()
        pages.forEachIndexed { i, uri ->
            val bmp = decodeScaled(ctx, uri, 2000) ?: return@forEachIndexed
            val out = ByteArrayOutputStream()
            bmp.compress(Bitmap.CompressFormat.JPEG, 88, out)
            atomicWrite(imgFile(ctx, docId, i), seal(out.toByteArray(), k))
        }
    }

    fun image(ctx: Context, docId: String, page: Int, maxPx: Int = 2000): Bitmap? {
        val f = imgFile(ctx, docId, page).takeIf { it.exists() } ?: return null
        val bytes = open(f.readBytes())
        val opts = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(bytes, 0, bytes.size, opts)
        opts.inSampleSize = sampleSize(opts.outWidth, opts.outHeight, maxPx)
        opts.inJustDecodeBounds = false
        return BitmapFactory.decodeByteArray(bytes, 0, bytes.size, opts)
    }

    /** Decrypted JPEG bytes, for sharing a page out of the app on the user's request. */
    fun imageBytes(ctx: Context, docId: String, page: Int): ByteArray? = imgFile(ctx, docId, page).takeIf { it.exists() }?.let { open(it.readBytes()) }

    fun deleteImages(ctx: Context, docId: String) {
        imgDir(ctx).listFiles { f -> f.name.startsWith("${docId}_") }?.forEach { it.delete() }
    }

    /** "Forgot PIN" last resort: there's no account to recover through, so the vault goes. */
    fun wipe(ctx: Context) {
        ctx.filesDir.deleteRecursively()
        ctx.cacheDir.deleteRecursively()
        KeyStore.getInstance("AndroidKeyStore").apply { load(null) }.deleteEntry(ALIAS)
    }

    fun decodeScaled(ctx: Context, uri: Uri, maxPx: Int): Bitmap? {
        val opts = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        ctx.contentResolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, opts) }
        opts.inSampleSize = sampleSize(opts.outWidth, opts.outHeight, maxPx)
        opts.inJustDecodeBounds = false
        return ctx.contentResolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, opts) }
    }

    private fun sampleSize(w: Int, h: Int, maxPx: Int): Int {
        var s = 1
        while (maxOf(w, h) / (s * 2) >= maxPx) s *= 2
        return s
    }

    // ---------- Backup: passphrase-encrypted .aivault (PBKDF2 + AES-256-GCM over a zip) ----------

    private val MAGIC = "AIVAULT1".toByteArray()

    private fun passKey(pass: CharArray, salt: ByteArray): SecretKey =
        SecretKeySpec(SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256").generateSecret(PBEKeySpec(pass, salt, 210_000, 256)).encoded, "AES")

    // ponytail: builds the backup in memory, fine up to a few hundred MB of scans; stream it if vaults get bigger.
    fun exportBackup(ctx: Context, data: VaultData, pass: CharArray, out: Uri) {
        val zip = ByteArrayOutputStream()
        ZipOutputStream(zip).use { z ->
            z.putNextEntry(ZipEntry("vault.json")); z.write(toJson(data).toString().toByteArray()); z.closeEntry()
            for (d in data.documents) for (p in 0 until d.pages) {
                val bytes = imageBytes(ctx, d.id, p) ?: continue
                z.putNextEntry(ZipEntry("img/${d.id}_$p.jpg")); z.write(bytes); z.closeEntry()
            }
        }
        val salt = ByteArray(16).also { SecureRandom().nextBytes(it) }
        val sealed = seal(zip.toByteArray(), passKey(pass, salt))
        ctx.contentResolver.openOutputStream(out)?.use { it.write(MAGIC + salt + sealed) } ?: error("Couldn't write the backup file")
    }

    /** Merges a backup into the current vault: adds documents and people it doesn't already have. Returns the merged vault. */
    fun importBackup(ctx: Context, current: VaultData, pass: CharArray, file: Uri): VaultData {
        val all = ctx.contentResolver.openInputStream(file)?.use { it.readBytes() } ?: error("Couldn't read the backup file")
        require(all.size > 40 && all.copyOfRange(0, 8).contentEquals(MAGIC)) { "That isn't an AI Form & Vault backup" }
        val zipBytes = runCatching { open(all.copyOfRange(24, all.size), passKey(pass, all.copyOfRange(8, 24))) }
            .getOrElse { throw IllegalArgumentException("Wrong passphrase") }
        var restored = VaultData()
        val images = mutableMapOf<String, ByteArray>()
        ZipInputStream(zipBytes.inputStream()).use { z ->
            generateSequence { z.nextEntry }.forEach { e ->
                val bytes = z.readBytes()
                if (e.name == "vault.json") restored = fromJson(JSONObject(String(bytes)))
                else images[e.name.removePrefix("img/").removeSuffix(".jpg")] = bytes
            }
        }
        val k = key()
        val newDocs = restored.documents.filter { r -> current.documents.none { it.id == r.id } }
        for (d in newDocs) for (p in 0 until d.pages) images["${d.id}_$p"]?.let { atomicWrite(imgFile(ctx, d.id, p), seal(it, k)) }
        // Keep one "Me": a restored self merges into the current one.
        val selfMap = if (current.self != null && restored.self != null) mapOf(restored.self!!.id to current.self!!.id) else emptyMap()
        val newPeople = restored.people.filter { r -> r.id !in selfMap && current.people.none { it.id == r.id } }
        return current.copy(
            documents = current.documents + newDocs.map { it.copy(ownerId = selfMap[it.ownerId] ?: it.ownerId) },
            people = current.people + newPeople,
            manual = current.manual + restored.manual.filter { r -> current.manual.none { it.key == r.key && it.value == r.value } },
            fieldsFilled = current.fieldsFilled + restored.fieldsFilled,
        )
    }

    // ---------- JSON ----------

    private fun toJson(d: VaultData) = JSONObject()
        .put("documents", JSONArray(d.documents.map { doc ->
            JSONObject().put("id", doc.id).put("type", doc.type.name).put("category", doc.category.name).put("title", doc.title)
                .put("owner", doc.ownerId).put("pages", doc.pages).put("note", doc.note).put("createdAt", doc.createdAt)
                .put("facts", JSONArray(doc.facts.map { JSONObject().put("k", it.key.name).put("v", it.value) }))
        }))
        .put("people", JSONArray(d.people.map {
            JSONObject().put("id", it.id).put("name", it.name).put("relation", it.relation.name).put("confirmed", it.confirmed).put("evidence", it.evidence)
        }))
        .put("manual", JSONArray(d.manual.map { JSONObject().put("k", it.key.name).put("v", it.value).put("t", it.savedAt) }))
        .put("fieldsFilled", d.fieldsFilled)

    private fun <T> JSONArray.map(f: (JSONObject) -> T) = List(length()) { f(getJSONObject(it)) }

    private fun fromJson(o: JSONObject) = VaultData(
        documents = o.getJSONArray("documents").map { j ->
            Document(
                id = j.getString("id"), type = DocType.valueOf(j.getString("type")), category = Category.valueOf(j.getString("category")),
                title = j.getString("title"), ownerId = j.getString("owner"),
                facts = j.getJSONArray("facts").map { Fact(FactKey.valueOf(it.getString("k")), it.getString("v")) },
                pages = j.getInt("pages"), note = j.optString("note"), createdAt = j.getLong("createdAt"),
            )
        },
        people = o.getJSONArray("people").map {
            Person(it.getString("id"), it.getString("name"), Relation.valueOf(it.getString("relation")), it.getBoolean("confirmed"), it.optString("evidence"))
        },
        manual = o.getJSONArray("manual").map { ManualFact(FactKey.valueOf(it.getString("k")), it.getString("v"), it.getLong("t")) },
        fieldsFilled = o.optInt("fieldsFilled"),
    )
}
