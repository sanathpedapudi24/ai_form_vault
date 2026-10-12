package com.aiformvault

import java.time.LocalDate
import java.time.temporal.ChronoUnit
import java.util.UUID

// ---------- Form labels → fact keys (Snap-to-Fill and system autofill share this) ----------

// Order matters: "father's name" must be tried before "name".
private val labelSynonyms: List<Pair<FactKey, List<String>>> = listOf(
    FactKey.FATHER to listOf("father", "s/o", "d/o", "son of", "daughter of"),
    FactKey.MOTHER to listOf("mother"),
    FactKey.SPOUSE to listOf("spouse", "husband", "wife", "w/o"),
    FactKey.DOB to listOf("date of birth", "dob", "d.o.b", "birth date", "birthdate", "birthday"),
    FactKey.GENDER to listOf("gender", "sex"),
    FactKey.EMAIL to listOf("email", "e-mail", "mail id"),
    FactKey.PHONE to listOf("mobile", "phone", "contact no", "contact number", "tel", "cell"),
    FactKey.PIN_CODE to listOf("pin code", "pincode", "pin", "postal code", "zip"),
    FactKey.IFSC to listOf("ifsc", "ifs code"),
    FactKey.ACCOUNT_NO to listOf("account no", "account number", "a/c no", "a/c number", "ac no", "bank account"),
    FactKey.BANK_NAME to listOf("bank name", "name of bank", "name of the bank", "bank"),
    FactKey.BRANCH to listOf("branch"),
    FactKey.ADDRESS to listOf("address", "residence"),
    FactKey.AADHAAR to listOf("aadhaar", "aadhar", "adhaar", "adhar", "uid"),
    FactKey.PAN to listOf("pan"),
    FactKey.PASSPORT to listOf("passport"),
    FactKey.VOTER_ID to listOf("voter", "epic"),
    FactKey.DL_NUMBER to listOf("driving licence", "driving license", "dl no"),
    FactKey.NATIONALITY to listOf("nationality", "citizenship"),
    FactKey.BLOOD_GROUP to listOf("blood group", "blood"),
    FactKey.ROLL to listOf("roll no", "roll number"),
    FactKey.NAME to listOf("full name", "applicant name", "applicant's name", "candidate name", "student name", "your name",
        "name of applicant", "name of the applicant", "name of candidate", "name of the candidate", "name"),
)

// Labels asking about someone or something else: never fill these from the user's profile.
private val notMine = Regex("""(?<![a-z])(nominee|witness|guarantor|reference|referee|introducer|signature|office use|employer|company|school|college|institute)(?![a-z])""")

/** Which fact a form label asks for, or null. Works on printed labels and on view ids like "first_name"/"dob". */
fun matchLabel(raw: String): FactKey? {
    val s = raw.replace(Regex("""([a-z])([A-Z])"""), "$1 $2").lowercase().replace(Regex("""[_\-]+"""), " ")
    if (s.isBlank() || s.length > 60 || notMine.containsMatchIn(s)) return null
    return labelSynonyms.firstOrNull { (_, words) -> words.any { Regex("""(?<![a-z])${Regex.escape(it)}(?![a-z])""").containsMatchIn(s) } }?.first
}

/** Android autofill hints (View.AUTOFILL_HINT_* and androidx HintConstants strings) → fact keys. */
fun matchHint(hint: String): FactKey? = when (hint.lowercase()) {
    "name", "personname", "person_name", "personfullname" -> FactKey.NAME
    "emailaddress", "email" -> FactKey.EMAIL
    "phone", "phonenumber", "phonenational", "telephonenumber" -> FactKey.PHONE
    "postaladdress", "streetaddress", "postaladdressstreetaddress" -> FactKey.ADDRESS
    "postalcode", "postaladdresspostalcode" -> FactKey.PIN_CODE
    "birthdatefull" -> FactKey.DOB
    "gender" -> FactKey.GENDER
    else -> matchLabel(hint)
}

// ---------- People ----------

private fun tokens(name: String) = normalize(FactKey.NAME, name).split(" ").filter { it.length > 1 }.toSet()

/** Fuzzy: handles reordered names, a missing middle name, and one-letter OCR slips. */
fun sameName(a: String, b: String): Boolean {
    val ta = tokens(a); val tb = tokens(b)
    if (ta.isEmpty() || tb.isEmpty()) return false
    val (small, big) = if (ta.size <= tb.size) ta to tb else tb to ta
    return small.all { s -> big.any { it == s || (s.length > 3 && editDistance(it, s) <= 1) } }
}

private fun editDistance(a: String, b: String): Int {
    val dp = IntArray(b.length + 1) { it }
    for (i in 1..a.length) {
        var prev = dp[0]; dp[0] = i
        for (j in 1..b.length) {
            val tmp = dp[j]
            dp[j] = minOf(dp[j] + 1, dp[j - 1] + 1, prev + if (a[i - 1] == b[j - 1]) 0 else 1)
            prev = tmp
        }
    }
    return dp[b.length]
}

/**
 * Relationship suggestions from the owner's own documents ("Printed as father's name on PAN card").
 * Unconfirmed until the user says yes; skips anyone already known.
 */
fun suggestRelations(data: VaultData, doc: Document): List<Person> {
    if (doc.ownerId != data.self?.id) return emptyList()
    val rel = mapOf(FactKey.FATHER to Relation.FATHER, FactKey.MOTHER to Relation.MOTHER, FactKey.SPOUSE to Relation.SPOUSE)
    return doc.facts.mapNotNull { f ->
        val r = rel[f.key] ?: return@mapNotNull null
        if (data.people.any { sameName(it.name, f.value) }) return@mapNotNull null
        Person(UUID.randomUUID().toString(), titleCase(f.value), r, confirmed = false,
            evidence = "Printed as ${f.key.label.lowercase()} on your ${doc.type.label}")
    }
}

// ---------- Search ----------

private val fillerRx = Regex("""\b(find|show|search|where|is|are|my|me|the|a|an|for|of|all|get|open|please|which|what|when|does|do|did|docs?|documents?|card)\b""")
private val synonyms = mapOf(
    "id" to Category.IDENTITY, "ids" to Category.IDENTITY, "identity" to Category.IDENTITY, "kyc" to Category.IDENTITY,
    "education" to Category.EDUCATION, "marks" to Category.EDUCATION, "certificate" to Category.EDUCATION, "school" to Category.EDUCATION,
    "travel" to Category.TRAVEL, "vehicle" to Category.VEHICLE, "car" to Category.VEHICLE, "bike" to Category.VEHICLE,
    "finance" to Category.FINANCE, "bank" to Category.FINANCE, "medical" to Category.MEDICAL, "health" to Category.MEDICAL,
)
private val relationWords = mapOf(
    "father" to Relation.FATHER, "dad" to Relation.FATHER, "papa" to Relation.FATHER, "mother" to Relation.MOTHER,
    "mom" to Relation.MOTHER, "mummy" to Relation.MOTHER, "wife" to Relation.SPOUSE, "husband" to Relation.SPOUSE,
    "spouse" to Relation.SPOUSE, "son" to Relation.CHILD, "daughter" to Relation.CHILD, "child" to Relation.CHILD,
    "kid" to Relation.CHILD, "sister" to Relation.SIBLING, "brother" to Relation.SIBLING, "sibling" to Relation.SIBLING,
)

/**
 * On-device search: keywords over titles, types, owners, fields and notes, plus light natural language —
 * "sister's aadhaar", "ID documents", "passport expiring next year", "what expires soon".
 */
fun search(query: String, data: VaultData, today: LocalDate = LocalDate.now()): List<Document> {
    var q = query.lowercase().replace("'s", "").replace("’s", "").trim()
    if (q.isBlank()) return emptyList()

    val expiryWindow: Long? = when {
        Regex("""\b(expir\w*|valid\w*|renew\w*|lapse\w*)\b""").containsMatchIn(q) -> when {
            "next year" in q || "this year" in q -> ChronoUnit.DAYS.between(today, today.withDayOfYear(1).plusYears(if ("next" in q) 2 else 1))
            "month" in q -> 31L
            else -> 180L
        }
        else -> null
    }
    q = q.replace(Regex("""\b(expir\w*|valid\w*|renew\w*|lapse\w*|soon|next|this|year|month)\b"""), " ")

    val relation = relationWords.entries.firstOrNull { Regex("""\b${it.key}\b""").containsMatchIn(q) }?.also {
        q = q.replace(Regex("""\b${it.key}\b"""), " ")
    }?.value
    val category = synonyms.entries.firstOrNull { Regex("""\b${it.key}\b""").containsMatchIn(q) }?.also {
        q = q.replace(Regex("""\b${it.key}\b"""), " ")
    }?.value
    val words = q.replace(fillerRx, " ").split(Regex("""\s+""")).filter { it.length > 1 }

    return data.documents.mapNotNull { d ->
        val owner = data.person(d.ownerId)
        if (relation != null && owner?.relation != relation) return@mapNotNull null
        if (category != null && d.category != category) return@mapNotNull null
        if (expiryWindow != null) {
            val left = d.expiry()?.let { ChronoUnit.DAYS.between(today, it) } ?: return@mapNotNull null
            if (left > expiryWindow) return@mapNotNull null
        }
        val hay = buildString {
            append(d.title).append(' ').append(d.type.label).append(' ').append(d.category.label).append(' ')
            append(owner?.name.orEmpty()).append(' ').append(d.note).append(' ')
            d.facts.forEach { append(it.key.label).append(' ').append(it.value).append(' ') }
        }.lowercase()
        val hits = words.count { it in hay }
        if (words.isNotEmpty() && hits == 0) null else d to hits
    }.sortedWith(compareByDescending<Pair<Document, Int>> { it.second }.thenByDescending { it.first.createdAt }).map { it.first }
}
