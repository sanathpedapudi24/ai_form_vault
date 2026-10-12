package com.aiformvault

import android.content.Context
import android.content.SharedPreferences
import android.util.Base64
import java.security.MessageDigest
import java.security.SecureRandom
import javax.crypto.SecretKeyFactory
import javax.crypto.spec.PBEKeySpec

/**
 * 4-digit PIN, salted PBKDF2 hash. After 5 wrong tries an escalating cooldown (30s, doubling, max 5 min)
 * makes the 10,000-PIN space impractical to brute-force.
 */
class Lock(ctx: Context) {
    private val p: SharedPreferences = ctx.getSharedPreferences("lock", Context.MODE_PRIVATE)

    val hasPin get() = p.contains("hash")
    var biometric: Boolean
        get() = p.getBoolean("bio", false)
        set(v) = p.edit().putBoolean("bio", v).apply()
    var onboarded: Boolean
        get() = p.getBoolean("onboarded", false)
        set(v) = p.edit().putBoolean("onboarded", v).apply()
    var pinSkipped: Boolean
        get() = p.getBoolean("pinSkipped", false)
        set(v) = p.edit().putBoolean("pinSkipped", v).apply()
    var reminders: Boolean
        get() = p.getBoolean("reminders", true)
        set(v) = p.edit().putBoolean("reminders", v).apply()
    /** Whether the system autofill service may serve facts at all. */
    var autofill: Boolean
        get() = p.getBoolean("autofill", true)
        set(v) = p.edit().putBoolean("autofill", v).apply()

    private fun hash(pin: String, salt: ByteArray) =
        SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256").generateSecret(PBEKeySpec(pin.toCharArray(), salt, 120_000, 256)).encoded

    fun setPin(pin: String) {
        val salt = ByteArray(16).also { SecureRandom().nextBytes(it) }
        p.edit().putString("salt", b64(salt)).putString("hash", b64(hash(pin, salt))).putInt("fails", 0).putLong("until", 0).apply()
    }

    fun removePin() = p.edit().remove("hash").remove("salt").putBoolean("bio", false).apply()

    /** Milliseconds left in the cooldown, 0 when a guess is allowed. */
    fun cooldownMs(now: Long = System.currentTimeMillis()) = maxOf(0, p.getLong("until", 0) - now)

    /** Returns true on success. A wrong PIN counts toward the cooldown; guesses during a cooldown are refused. */
    fun check(pin: String, now: Long = System.currentTimeMillis()): Boolean {
        if (cooldownMs(now) > 0) return false
        val salt = Base64.decode(p.getString("salt", "") ?: "", Base64.NO_WRAP)
        val ok = MessageDigest.isEqual(hash(pin, salt), Base64.decode(p.getString("hash", "") ?: "", Base64.NO_WRAP))
        if (ok) { p.edit().putInt("fails", 0).putLong("until", 0).apply(); return true }
        val fails = p.getInt("fails", 0) + 1
        val e = p.edit().putInt("fails", fails)
        if (fails >= 5) e.putLong("until", now + minOf(300_000L, 30_000L shl (fails - 5).coerceAtMost(4)))
        e.apply()
        return false
    }

    fun clearAll() = p.edit().clear().apply()

    private fun b64(b: ByteArray) = Base64.encodeToString(b, Base64.NO_WRAP)
}
