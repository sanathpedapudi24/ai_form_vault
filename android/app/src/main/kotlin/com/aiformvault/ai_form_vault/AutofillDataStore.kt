package com.aiformvault.ai_form_vault

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import org.json.JSONObject

/**
 * Encrypted storage for the vault facts exposed to system autofill.
 * Written by Flutter (via the MethodChannel in MainActivity), read by
 * [VaultAutofillService]. Backed by EncryptedSharedPreferences so the
 * values are AES-encrypted at rest with a Keystore master key.
 */
object AutofillDataStore {
    private const val PREFS_NAME = "vault_autofill_store"
    private const val KEY_FACTS = "facts_json"

    private fun prefs(context: Context): SharedPreferences {
        val masterKey = MasterKey.Builder(context)
            .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
            .build()
        return EncryptedSharedPreferences.create(
            context,
            PREFS_NAME,
            masterKey,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
        )
    }

    fun setFacts(context: Context, json: String) {
        prefs(context).edit().putString(KEY_FACTS, json).apply()
    }

    fun clear(context: Context) {
        prefs(context).edit().remove(KEY_FACTS).apply()
    }

    /** Returns fact key → value, or an empty map when nothing is shared. */
    fun getFacts(context: Context): Map<String, String> {
        val raw = try {
            prefs(context).getString(KEY_FACTS, null)
        } catch (e: Exception) {
            null
        } ?: return emptyMap()
        return try {
            val json = JSONObject(raw)
            val result = mutableMapOf<String, String>()
            for (key in json.keys()) {
                result[key] = json.getString(key)
            }
            result
        } catch (e: Exception) {
            emptyMap()
        }
    }
}
