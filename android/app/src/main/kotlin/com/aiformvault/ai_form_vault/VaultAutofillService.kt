package com.aiformvault.ai_form_vault

import android.app.assist.AssistStructure
import android.os.CancellationSignal
import android.service.autofill.AutofillService
import android.service.autofill.Dataset
import android.service.autofill.FillCallback
import android.service.autofill.FillRequest
import android.service.autofill.FillResponse
import android.service.autofill.SaveCallback
import android.service.autofill.SaveInfo
import android.service.autofill.SaveRequest
import android.view.View
import android.view.autofill.AutofillId
import android.view.autofill.AutofillValue
import android.widget.RemoteViews

/**
 * System-wide autofill provider backed by the vault's identity facts.
 *
 * Matching strategy, in priority order:
 *  1. A per-app override the user taught us (see [AutofillOverrideStore]).
 *  2. Explicit `android:autofillHints` on the target view.
 *  3. Keyword heuristics over the view's hint text, idEntry and
 *     contentDescription (covers the many apps that never set hints).
 *
 * Robustness rules:
 *  - Fields whose context names a *different* person or entity (employer,
 *    spouse, nominee, guardian, office…) are suppressed, so a form's
 *    "Employer Address" never gets the user's home address.
 *  - When several fields map to the same fact, only the best-matching one is
 *    filled, unless the others are plainly additional user fields.
 *
 * Only fields Flutter explicitly shared (see AutofillBridge on the Dart
 * side) are available here — sensitive IDs like full Aadhaar numbers are
 * never exposed to other apps.
 */
class VaultAutofillService : AutofillService() {

    /** A candidate fillable field, with how strongly it matched. */
    private data class FieldMatch(
        val id: AutofillId,
        val factKey: String,
        val value: String,
        val score: Int,
        val signature: String,
    )

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

        val packageName = structure.activityComponent?.packageName ?: ""
        val allTextIds = mutableListOf<AutofillId>()
        val matches = mutableListOf<FieldMatch>()
        collectMatches(structure, facts, packageName, allTextIds, matches)

        if (matches.isEmpty()) {
            callback.onSuccess(null)
            return
        }

        // When multiple fields claim the same fact, keep only the strongest —
        // avoids splattering the same value across unrelated inputs.
        val bestPerKey = matches
            .groupBy { it.factKey }
            .mapValues { (_, group) -> group.maxByOrNull { it.score }!! }
        val filledIds = HashSet<AutofillId>()

        val datasetBuilder = Dataset.Builder()
        var count = 0
        for (match in bestPerKey.values) {
            if (!filledIds.add(match.id)) continue
            // RemoteViews must reference OUR package — that's where the layout
            // resource lives, not the requesting app's package.
            val presentation = RemoteViews(applicationContext.packageName, R.layout.autofill_item).apply {
                setTextViewText(R.id.autofill_text, match.value)
            }
            datasetBuilder.setValue(
                match.id,
                AutofillValue.forText(match.value),
                presentation
            )
            count++
        }

        if (count == 0) {
            callback.onSuccess(null)
            return
        }

        val responseBuilder = FillResponse.Builder().addDataset(datasetBuilder.build())

        // Declare a save request over every text field so onSaveRequest fires
        // and we can learn per-app corrections from what the user submits.
        if (allTextIds.isNotEmpty()) {
            responseBuilder.setSaveInfo(
                SaveInfo.Builder(
                    SaveInfo.SAVE_DATA_TYPE_GENERIC,
                    allTextIds.toTypedArray()
                ).setFlags(SaveInfo.FLAG_SAVE_ON_ALL_VIEWS_INVISIBLE).build()
            )
        }

        callback.onSuccess(responseBuilder.build())
    }

    override fun onSaveRequest(request: SaveRequest, callback: SaveCallback) {
        val facts = AutofillDataStore.getFacts(applicationContext)
        val structure = request.fillContexts.lastOrNull()?.structure
        if (facts.isNotEmpty() && structure != null) {
            val packageName = structure.activityComponent?.packageName ?: ""
            if (packageName.isNotBlank()) {
                learnFromSave(structure, facts, packageName)
            }
        }
        callback.onSuccess()
    }

    // --- Fill-side collection -------------------------------------------------

    private fun collectMatches(
        structure: AssistStructure,
        facts: Map<String, String>,
        packageName: String,
        allTextIds: MutableList<AutofillId>,
        out: MutableList<FieldMatch>
    ) {
        for (i in 0 until structure.windowNodeCount) {
            walkFill(structure.getWindowNodeAt(i).rootViewNode, facts, packageName, allTextIds, out)
        }
    }

    private fun walkFill(
        node: AssistStructure.ViewNode,
        facts: Map<String, String>,
        packageName: String,
        allTextIds: MutableList<AutofillId>,
        out: MutableList<FieldMatch>
    ) {
        val autofillId = node.autofillId
        if (autofillId != null && node.autofillType == View.AUTOFILL_TYPE_TEXT) {
            allTextIds.add(autofillId)
            val signature = fieldSignature(node)

            // 1. A correction the user taught us for this exact app+field wins.
            val learned = AutofillOverrideStore.getOverride(applicationContext, packageName, signature)
            val (factKey, score) = if (learned != null && facts.containsKey(learned)) {
                learned to 100
            } else {
                scoreFactKey(node)
            }

            val value = factKey?.let { facts[it] }
            if (factKey != null && value != null && value.isNotEmpty()) {
                out.add(FieldMatch(autofillId, factKey, value, score, signature))
            }
        }
        for (i in 0 until node.childCount) {
            walkFill(node.getChildAt(i), facts, packageName, allTextIds, out)
        }
    }

    // --- Save-side learning ---------------------------------------------------

    private fun learnFromSave(
        structure: AssistStructure,
        facts: Map<String, String>,
        packageName: String
    ) {
        // Reverse index: normalized fact value → fact key.
        val byValue = HashMap<String, String>()
        for ((key, value) in facts) {
            val norm = normalizeValue(value)
            if (norm.isNotEmpty()) byValue[norm] = key
        }
        for (i in 0 until structure.windowNodeCount) {
            walkSave(structure.getWindowNodeAt(i).rootViewNode, byValue, packageName)
        }
    }

    private fun walkSave(
        node: AssistStructure.ViewNode,
        byValue: Map<String, String>,
        packageName: String
    ) {
        if (node.autofillType == View.AUTOFILL_TYPE_TEXT) {
            val entered = node.autofillValue?.let { if (it.isText) it.textValue?.toString() else null }
                ?: node.text?.toString()
            val norm = entered?.let { normalizeValue(it) }
            if (norm != null && norm.isNotEmpty()) {
                val factKey = byValue[norm]
                if (factKey != null) {
                    val signature = fieldSignature(node)
                    // Only record when it disagrees with (or wasn't covered by)
                    // our heuristics — no point storing what we'd guess anyway.
                    val guessed = scoreFactKey(node).first
                    if (guessed != factKey) {
                        AutofillOverrideStore.putOverride(
                            applicationContext, packageName, signature, factKey
                        )
                    }
                }
            }
        }
        for (i in 0 until node.childCount) {
            walkSave(node.getChildAt(i), byValue, packageName)
        }
    }

    // --- Matching -------------------------------------------------------------

    /** A stable-ish identifier for a field within an app (id first, else hint). */
    private fun fieldSignature(node: AssistStructure.ViewNode): String {
        val raw = node.idEntry
            ?: node.hint
            ?: node.autofillHints?.firstOrNull()
            ?: node.contentDescription?.toString()
            ?: ""
        return raw.trim().lowercase()
    }

    /**
     * Maps a view to a canonical fact key with a confidence score, or null.
     * Higher score = stronger evidence. Returns null when the field names a
     * different person/entity than the vault owner.
     */
    private fun scoreFactKey(node: AssistStructure.ViewNode): Pair<String?, Int> {
        // 1. Explicit autofill hints — the strongest declared signal.
        node.autofillHints?.forEach { hint ->
            when (hint.lowercase()) {
                View.AUTOFILL_HINT_NAME.lowercase(), "personname", "name" -> return "full_name" to 90
                View.AUTOFILL_HINT_PHONE.lowercase(), "phonenumber" -> return "phone" to 90
                View.AUTOFILL_HINT_EMAIL_ADDRESS.lowercase(), "email" -> return "email" to 90
                View.AUTOFILL_HINT_POSTAL_ADDRESS.lowercase(), "streetaddress" -> return "address" to 90
                View.AUTOFILL_HINT_POSTAL_CODE.lowercase(), "postalcode", "zip" -> return "pin_code" to 90
                "birthdatefull", "birthdate", "birthday" -> return "dob" to 90
                "gender", "sex" -> return "gender" to 90
            }
        }

        // 2. Heuristics over visible hint / view id / description.
        val haystack = listOfNotNull(
            node.hint,
            node.idEntry,
            node.contentDescription?.toString(),
            node.text?.toString()?.takeIf { it.length <= 40 }
        ).joinToString(" ").lowercase()

        if (haystack.isBlank()) return null to 0

        // Suppress fields that clearly belong to someone/something else. The
        // vault holds the owner's identity, not their employer's or nominee's.
        if (haystack.containsAny(
                "employer", "company", "office", "organisation", "organization",
                "nominee", "spouse", "guardian", "reference", "witness",
                "emergency contact", "next of kin"
            ) && !haystack.containsAny("your", "applicant", "self")
        ) {
            // Father/mother are legitimately in the vault; don't suppress those.
            if (!haystack.containsAny("father", "mother", "parent")) {
                return null to 0
            }
        }

        return when {
            haystack.containsAny("father") -> "father_name" to 70
            haystack.containsAny("mother") -> "mother_name" to 70
            haystack.containsAny("email", "e-mail") -> "email" to 70
            haystack.containsAny("phone", "mobile", "contact number") -> "phone" to 70
            haystack.containsAny("pincode", "pin code", "postal", "zip") -> "pin_code" to 70
            haystack.containsAny("address") -> "address" to 60
            haystack.containsAny("date of birth", "dob", "birth") -> "dob" to 70
            haystack.containsAny("gender", "sex") -> "gender" to 70
            haystack.containsAny("pan") -> "pan_number" to 70
            haystack.containsAny("blood") -> "blood_group" to 70
            haystack.containsAny("nationality") -> "nationality" to 70
            // "name" is deliberately last — it appears inside other labels.
            haystack.containsAny("full name", "your name", "applicant name") -> "full_name" to 65
            haystack.containsAny("name") &&
                !haystack.containsAny("user", "nick", "file", "company") -> "full_name" to 40
            else -> null to 0
        }
    }

    private fun normalizeValue(s: String): String =
        s.trim().lowercase().replace(Regex("[^a-z0-9]"), "")

    private fun String.containsAny(vararg needles: String): Boolean =
        needles.any { this.contains(it) }
}
