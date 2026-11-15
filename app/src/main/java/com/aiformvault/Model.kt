package com.aiformvault

import java.time.LocalDate
import java.time.format.DateTimeFormatter

enum class Category(val label: String) {
    IDENTITY("ID proof"), EDUCATION("Education"), VEHICLE("Vehicle"), TRAVEL("Travel"),
    FINANCE("Finance"), MEDICAL("Medical"), OTHER("Other")
}

enum class DocType(val label: String, val category: Category) {
    AADHAAR("Aadhaar card", Category.IDENTITY), PAN("PAN card", Category.IDENTITY),
    VOTER_ID("Voter ID", Category.IDENTITY), DRIVING_LICENSE("Driving licence", Category.IDENTITY),
    PASSPORT("Passport", Category.TRAVEL), VEHICLE_RC("Vehicle RC", Category.VEHICLE),
    MARKSHEET("Marksheet", Category.EDUCATION), BANK("Bank passbook", Category.FINANCE), OTHER("Document", Category.OTHER)
}

/** What each document type normally prints, so review can say what wasn't found. */
val expectedFacts: Map<DocType, List<FactKey>> = mapOf(
    DocType.AADHAAR to listOf(FactKey.NAME, FactKey.DOB, FactKey.GENDER, FactKey.AADHAAR),
    DocType.PAN to listOf(FactKey.NAME, FactKey.FATHER, FactKey.DOB, FactKey.PAN),
    DocType.VOTER_ID to listOf(FactKey.NAME, FactKey.FATHER, FactKey.GENDER, FactKey.VOTER_ID),
    DocType.DRIVING_LICENSE to listOf(FactKey.NAME, FactKey.DOB, FactKey.DL_NUMBER, FactKey.EXPIRY),
    DocType.PASSPORT to listOf(FactKey.NAME, FactKey.DOB, FactKey.GENDER, FactKey.PASSPORT, FactKey.EXPIRY),
    DocType.BANK to listOf(FactKey.NAME, FactKey.ACCOUNT_NO, FactKey.IFSC, FactKey.BANK_NAME),
    DocType.MARKSHEET to listOf(FactKey.NAME, FactKey.ROLL),
)

/** Which document usually carries a detail: shown when a form field is empty. */
val whereToFind: Map<FactKey, String> = mapOf(
    FactKey.NAME to "Aadhaar or PAN", FactKey.DOB to "Aadhaar or PAN", FactKey.GENDER to "Aadhaar",
    FactKey.FATHER to "PAN, voter ID, marksheet or Aadhaar's C/O line",
    FactKey.MOTHER to "passport back page or marksheet", FactKey.SPOUSE to "passport back page",
    FactKey.ADDRESS to "Aadhaar back side", FactKey.PIN_CODE to "Aadhaar back side",
    FactKey.PHONE to "no ID card prints it: type it once", FactKey.EMAIL to "no ID card prints it: type it once",
    FactKey.ACCOUNT_NO to "bank passbook", FactKey.IFSC to "bank passbook", FactKey.BANK_NAME to "bank passbook",
    FactKey.BRANCH to "bank passbook", FactKey.PAN to "PAN card", FactKey.NATIONALITY to "passport",
)

/** `shareable`: may be offered to other apps through system autofill. ID numbers never are, except PAN. */
enum class FactKey(val label: String, val sensitive: Boolean = false, val shareable: Boolean = true) {
    NAME("Name"), DOB("Date of birth"), GENDER("Gender"), FATHER("Father's name"),
    MOTHER("Mother's name"), SPOUSE("Spouse's name"), PHONE("Mobile number"), EMAIL("Email"),
    ADDRESS("Address"), PIN_CODE("PIN code"), NATIONALITY("Nationality"), BLOOD_GROUP("Blood group"),
    BANK_NAME("Bank"), BRANCH("Branch"), IFSC("IFSC code"),
    PAN("PAN", sensitive = true),
    ACCOUNT_NO("Account number", sensitive = true, shareable = false),
    AADHAAR("Aadhaar number", sensitive = true, shareable = false),
    PASSPORT("Passport number", sensitive = true, shareable = false),
    VOTER_ID("Voter ID number", sensitive = true, shareable = false),
    DL_NUMBER("Driving licence number", sensitive = true, shareable = false),
    VEHICLE_REG("Vehicle number", sensitive = true, shareable = false),
    ROLL("Roll number", shareable = false),
    EXPIRY("Valid until", shareable = false),
}

data class Fact(val key: FactKey, val value: String)

enum class Relation(val label: String) {
    SELF("Me"), FATHER("Father"), MOTHER("Mother"), SPOUSE("Spouse"), CHILD("Child"),
    SIBLING("Sibling"), OTHER("Family member")
}

/** `confirmed=false` is a suggestion: never treated as real until the user says yes (FR-ID-02/03). */
data class Person(val id: String, val name: String, val relation: Relation, val confirmed: Boolean, val evidence: String = "")

data class Document(
    val id: String,
    val type: DocType,
    val category: Category,
    val title: String,
    val ownerId: String,
    val facts: List<Fact>,
    val pages: Int,
    val note: String = "",
    val createdAt: Long,
)

/** A detail typed or corrected by the user (profile edit, Snap-to-Fill correction). Beats extracted values. */
data class ManualFact(val key: FactKey, val value: String, val savedAt: Long)

data class VaultData(
    val documents: List<Document> = emptyList(),
    val people: List<Person> = emptyList(),
    val manual: List<ManualFact> = emptyList(),
    val fieldsFilled: Int = 0,
) {
    val self get() = people.firstOrNull { it.relation == Relation.SELF }
    fun person(id: String) = people.firstOrNull { it.id == id }
    fun docsOf(personId: String) = documents.filter { it.ownerId == personId }
}

/** Where a profile value came from: a document title, or "Added by you". */
data class Entry(val key: FactKey, val value: String, val source: String, val manual: Boolean)

data class Mismatch(val key: FactKey, val values: Map<String, List<String>>)

/** The owner's profile: facts from their own documents plus manual ones. Other people's documents never leak in (FR-OCR-08). */
fun profile(data: VaultData): List<Entry> {
    val selfId = data.self?.id ?: return data.manual.map { Entry(it.key, it.value, "Added by you", true) }
    return data.docsOf(selfId).flatMap { d -> d.facts.filter { it.key != FactKey.EXPIRY }.map { Entry(it.key, it.value, d.title, false) } } +
        data.manual.map { Entry(it.key, it.value, "Added by you", true) }
}

/** Best value per fact: the user's own entry wins, then the latest document. */
fun bestFacts(data: VaultData): Map<FactKey, String> =
    profile(data).groupBy { it.key }.mapValues { (_, es) -> (es.lastOrNull { it.manual } ?: es.last()).value }

fun mismatches(entries: List<Entry>): List<Mismatch> =
    entries.groupBy { it.key }.mapNotNull { (key, es) ->
        // A manual entry is the user's verdict: it settles any disagreement.
        if (es.any { it.manual }) return@mapNotNull null
        val byValue = es.groupBy { normalize(key, it.value) }
        if (byValue.size < 2) null
        else Mismatch(key, byValue.values.associate { g -> g.first().value to g.map { it.source }.distinct() })
    }

fun normalize(key: FactKey, v: String) = when (key) {
    FactKey.DOB, FactKey.AADHAAR, FactKey.ROLL, FactKey.PHONE, FactKey.PIN_CODE, FactKey.EXPIRY, FactKey.ACCOUNT_NO -> v.filter(Char::isDigit)
    else -> v.uppercase().replace(Regex("""[^A-Z0-9]+"""), " ").trim()
}

fun mask(key: FactKey, v: String) = if (key.sensitive) v.mapIndexed { i, c -> if (i < v.length - 4 && c.isLetterOrDigit()) '•' else c }.joinToString("") else v

private val ddmmyyyy = DateTimeFormatter.ofPattern("dd/MM/yyyy")
fun parseDate(s: String): LocalDate? = runCatching { LocalDate.parse(s.trim(), ddmmyyyy) }.getOrNull()

fun Document.expiry(): LocalDate? = facts.firstOrNull { it.key == FactKey.EXPIRY }?.let { parseDate(it.value) }
