package com.aiformvault.ai_form_vault

import android.app.assist.AssistStructure
import android.os.CancellationSignal
import android.service.autofill.AutofillService
import android.service.autofill.Dataset
import android.service.autofill.FillCallback
import android.service.autofill.FillRequest
import android.service.autofill.FillResponse
import android.service.autofill.SaveCallback
import android.service.autofill.SaveRequest
import android.view.View
import android.view.autofill.AutofillId
import android.view.autofill.AutofillValue
import android.widget.RemoteViews

/**
 * System-wide autofill provider backed by the vault's identity facts.
 *
 * Matching strategy, in priority order:
 *  1. Explicit `android:autofillHints` on the target view.
 *  2. Keyword heuristics over the view's hint text, idEntry and
 *     contentDescription (covers the many apps that never set hints).
 *
 * Only fields Flutter explicitly shared (see AutofillBridge on the Dart
 * side) are available here — sensitive IDs like full Aadhaar numbers are
 * never exposed to other apps.
 */
class VaultAutofillService : AutofillService() {

    override fun onFillRequest(
        request: FillRequest,
        cancellationSignal: CancellationSignal,
        callback: FillCallback
    ) {
        val facts = AutofillDataStore.getFacts(applicationContext)
        if (facts.isEmpty()) {
            callback.onSuccess(null)
            return
        }

        val structure = request.fillContexts.lastOrNull()?.structure
        if (structure == null) {
            callback.onSuccess(null)
            return
        }

        val fillable = mutableListOf<Pair<AutofillId, String>>() // id → value
        collectFillableFields(structure, facts, fillable)

        if (fillable.isEmpty()) {
            callback.onSuccess(null)
            return
        }

        val dataset = Dataset.Builder().apply {
            for ((id, value) in fillable) {
                val presentation = RemoteViews(packageName, R.layout.autofill_item).apply {
                    setTextViewText(R.id.autofill_text, value)
                }
                setValue(id, AutofillValue.forText(value), presentation)
            }
        }.build()

        callback.onSuccess(FillResponse.Builder().addDataset(dataset).build())
    }

    override fun onSaveRequest(request: SaveRequest, callback: SaveCallback) {
        // The vault learns from scanned documents, not from other apps' forms.
        callback.onSuccess()
    }

    private fun collectFillableFields(
        structure: AssistStructure,
        facts: Map<String, String>,
        out: MutableList<Pair<AutofillId, String>>
    ) {
        for (i in 0 until structure.windowNodeCount) {
            walk(structure.getWindowNodeAt(i).rootViewNode, facts, out)
        }
    }

    private fun walk(
        node: AssistStructure.ViewNode,
        facts: Map<String, String>,
        out: MutableList<Pair<AutofillId, String>>
    ) {
        val autofillId = node.autofillId
        if (autofillId != null && node.autofillType == View.AUTOFILL_TYPE_TEXT) {
            val factKey = matchFactKey(node)
            val value = factKey?.let { facts[it] }
            if (value != null && value.isNotEmpty()) {
                out.add(autofillId to value)
            }
        }
        for (i in 0 until node.childCount) {
            walk(node.getChildAt(i), facts, out)
        }
    }

    /** Maps a view to one of the vault's canonical fact keys, or null. */
    private fun matchFactKey(node: AssistStructure.ViewNode): String? {
        // 1. Explicit autofill hints.
        node.autofillHints?.forEach { hint ->
            when (hint.lowercase()) {
                View.AUTOFILL_HINT_NAME.lowercase(), "personname", "name" -> return "full_name"
                View.AUTOFILL_HINT_PHONE.lowercase(), "phonenumber" -> return "phone"
                View.AUTOFILL_HINT_EMAIL_ADDRESS.lowercase(), "email" -> return "email"
                View.AUTOFILL_HINT_POSTAL_ADDRESS.lowercase(), "streetaddress" -> return "address"
                View.AUTOFILL_HINT_POSTAL_CODE.lowercase(), "postalcode", "zip" -> return "pin_code"
                "birthdatefull", "birthdate", "birthday" -> return "dob"
                "gender", "sex" -> return "gender"
            }
        }

        // 2. Heuristics over visible hint / view id / description.
        val haystack = listOfNotNull(
            node.hint,
            node.idEntry,
            node.contentDescription?.toString(),
            node.text?.toString()?.takeIf { it.length <= 40 }
        ).joinToString(" ").lowercase()

        if (haystack.isBlank()) return null

        return when {
            haystack.containsAny("father") -> "father_name"
            haystack.containsAny("mother") -> "mother_name"
            haystack.containsAny("email", "e-mail") -> "email"
            haystack.containsAny("phone", "mobile", "contact number") -> "phone"
            haystack.containsAny("pincode", "pin code", "postal", "zip") -> "pin_code"
            haystack.containsAny("address") -> "address"
            haystack.containsAny("date of birth", "dob", "birth") -> "dob"
            haystack.containsAny("gender", "sex") -> "gender"
            haystack.containsAny("pan") -> "pan_number"
            haystack.containsAny("blood") -> "blood_group"
            haystack.containsAny("nationality") -> "nationality"
            // "name" is deliberately last — it appears inside other labels.
            haystack.containsAny("full name", "your name", "applicant name") -> "full_name"
            haystack.containsAny("name") &&
                !haystack.containsAny("user", "nick", "file", "company") -> "full_name"
            else -> null
        }
    }

    private fun String.containsAny(vararg needles: String): Boolean =
        needles.any { this.contains(it) }
}
