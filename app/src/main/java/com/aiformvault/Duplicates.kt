package com.aiformvault

/**
 * Duplicate detection for documents. Pure Kotlin: no Android types, so it is unit tested on the JVM
 * next to [Extractor] and [Matching].
 *
 * Two different questions, kept apart on purpose:
 *   - **Strong**: the same identity number, normalised. `1234 5678 9012`, `1234-5678-9012` and
 *     `123456789012` are one number. Exact equality only — a fuzzy match on a document number
 *     produces false positives, and a false "this is a duplicate" is worse than a missed one.
 *   - **Weak**: same type, same owner, same title. Shown as a hint, never used to block anything.
 *
 * Duplicate detection is advisory. There are legitimate reasons to hold two copies (a reissued card
 * with a new address), so nothing here may prevent the user from saving.
 */

/** Values that identify a document, as opposed to a person. */
val identityKeys: Set<FactKey> = setOf(
    FactKey.AADHAAR, FactKey.PAN, FactKey.VOTER_ID, FactKey.PASSPORT,
    FactKey.DL_NUMBER, FactKey.ACCOUNT_NO, FactKey.VEHICLE_REG, FactKey.ROLL,
)

/**
 * Uppercase letters and digits only: strips the spaces, dashes and slashes OCR adds or drops at
 * random. Values shorter than [MIN_IDENTITY_LENGTH] normalised characters are never compared — an
 * empty or one-character read must not collide with anything.
 */
fun identityValue(key: FactKey, value: String): String =
    if (key in identityKeys) value.uppercase().replace(Regex("""[^A-Z0-9]+"""), "")
    else normalize(key, value)

private const val MIN_IDENTITY_LENGTH = 4

data class DuplicateHit(
    /** The document already in the vault that the draft looks like. */
    val doc: Document,
    /** True when an identity number matches exactly; false for the same-type/title hint. */
    val strong: Boolean,
)

/**
 * Documents in [existing] that [draft] appears to duplicate, strongest first.
 * A strong match wins over the weak hint, and a document is only reported once.
 */
fun duplicatesOf(draft: Document, existing: List<Document>): List<DuplicateHit> {
    val draftFacts = draft.facts
        .filter { it.key in identityKeys }
        .map { it.key to identityValue(it.key, it.value) }
        .filter { (_, v) -> v.length >= MIN_IDENTITY_LENGTH }
    val title = normalize(FactKey.NAME, draft.title)

    return existing.mapNotNull { doc ->
        if (doc.id == draft.id) return@mapNotNull null
        val strong = draft.type == doc.type && draftFacts.isNotEmpty() && doc.facts.any { f ->
            f.key in identityKeys && identityValue(f.key, f.value).length >= MIN_IDENTITY_LENGTH &&
                draftFacts.any { (k, v) -> k == f.key && v == identityValue(f.key, f.value) }
        }
        // An identity number only means the same document within one document type: a numeric value
        // repeated across an Aadhaar and a marksheet is a formatting coincidence, not one document.
        val weak = doc.type == draft.type && doc.ownerId == draft.ownerId && title.isNotBlank() &&
            title == normalize(FactKey.NAME, doc.title)
        when {
            strong -> DuplicateHit(doc, strong = true)
            weak -> DuplicateHit(doc, strong = false)
            else -> null
        }
    }.sortedByDescending { it.strong }
}

/** Convenience for callers that only care about the hard, identity-number matches. */
fun findDuplicates(draft: Document, existing: List<Document>): List<Document> =
    duplicatesOf(draft, existing).filter { it.strong }.map { it.doc }
