package com.aiformvault.ai_form_vault

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.view.autofill.AutofillManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity (not FlutterActivity) is required by local_auth —
// the biometric prompt is a DialogFragment that needs a FragmentActivity host.
class MainActivity : FlutterFragmentActivity() {

    private val channelName = "com.aiformvault/autofill"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "setAutofillData" -> {
                    val json = call.arguments as? String
                    if (json != null) {
                        AutofillDataStore.setFacts(applicationContext, json)
                        result.success(true)
                    } else {
                        result.error("BAD_ARGS", "Expected JSON string", null)
                    }
                }
                "clearAutofillData" -> {
                    AutofillDataStore.clear(applicationContext)
                    result.success(true)
                }
                "isAutofillServiceEnabled" -> {
                    result.success(isOurAutofillServiceEnabled())
                }
                "openAutofillSettings" -> {
                    openAutofillSettings()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun isOurAutofillServiceEnabled(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        val manager = getSystemService(AutofillManager::class.java) ?: return false
        return manager.hasEnabledAutofillServices()
    }

    private fun openAutofillSettings() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        try {
            val intent = Intent(Settings.ACTION_REQUEST_SET_AUTOFILL_SERVICE).apply {
                data = Uri.parse("package:$packageName")
            }
            startActivityForResult(intent, REQUEST_AUTOFILL)
        } catch (e: Exception) {
            // Some OEM builds don't expose this screen; fall back to app settings.
            val fallback = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.parse("package:$packageName")
            }
            startActivity(fallback)
        }
    }

    companion object {
        private const val REQUEST_AUTOFILL = 4311
    }
}
