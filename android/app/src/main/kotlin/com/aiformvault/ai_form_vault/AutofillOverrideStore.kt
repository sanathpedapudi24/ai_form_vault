package com.aiformvault.ai_form_vault

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey

/**
 * Per-app autofill corrections learned from what the user actually saved.
 *
 * When the user fills a form and Android fires a save request, we match the
 * values they entered back to known vault facts and remember, for that app,
 * "the field with this signature holds this fact key". Next time that app
 * asks for autofill, [VaultAutofillService] consults these overrides first —
 * so a one-time mismatch (e.g. a field our heuristics read as the full name
 * but the user used for their father's name) is corrected permanently for
 * that app.
 *
 * Stored in its own EncryptedSharedPreferences file, AES-encrypted at rest.
 */
object AutofillOverrideStore {
    private const val PREFS_NAME = "vault_autofill_overrides"

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

    /** Stable-ish key for one field within one app. */
    private fun compositeKey(packageName: String, signature: String): String =
        "$packageName::$signature"

    /** Returns the learned fact key for this app's field, or null. */
    fun getOverride(context: Context, packageName: String, signature: String): String? {
        if (packageName.isBlank() || signature.isBlank()) return null
        return try {
            prefs(context).getString(compositeKey(packageName, signature), null)
        } catch (e: Exception) {
            null
        }
    }

    fun putOverride(
        context: Context,
        packageName: String,
        signature: String,
        factKey: String
    ) {
        if (packageName.isBlank() || signature.isBlank() || factKey.isBlank()) return
        try {
            prefs(context).edit()
                .putString(compositeKey(packageName, signature), factKey)
                .apply()
        } catch (e: Exception) {
            // Non-fatal — learning is best-effort.
        }
    }

    fun clear(context: Context) {
        try {
            prefs(context).edit().clear().apply()
        } catch (e: Exception) {
            // ignore
        }
    }
}
