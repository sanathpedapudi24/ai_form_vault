package com.aiformvault

import java.time.LocalDate

private val dateRx = Regex("""\b(\d{2})[/\-.](\d{2})[/\-.](\d{4})\b""")
private val aadhaarRx = Regex("""(?<!\d\s?)\b(\d{4})\s?(\d{4})\s?(\d{4})\b(?!\s?\d)""")
private val panRx = Regex("""\b[A-Z]{5}[0-9]{4}[A-Z]\b""")
private val epicRx = Regex("""\b[A-Z]{3}[0-9]{7}\b""")
private val dlRx = Regex("""\b[A-Z]{2}[- ]?\d{2}[- ]?(?:19|20)\d{2}[- ]?\d{7}\b|\b[A-Z]{2}\d{13}\b""")
private val vehicleRx = Regex("""\b[A-Z]{2}[ -]?\d{1,2}[ -]?[A-Z]{1,3}[ -]?\d{4}\b""")
private val passportNoRx = Regex("""\b[A-Z][0-9]{7}\b""")
private val phoneRx = Regex("""(?<!\d)(?:\+91[ -]?)?([6-9]\d{9})(?!\d)""")
private val emailRx = Regex("""[\w.+-]+@[\w-]+\.[\w.]+""")
private val pinRx = Regex("""\b[1-9]\d{5}\b""")
private val genderRx = Regex("""\b(MALE|FEMALE|TRANSGENDER)\b""", RegexOption.IGNORE_CASE)
private val bloodRx = Regex("""\b(AB|A|B|O)\s?([+-]|POSITIVE|NEGATIVE|POS|NEG)""", RegexOption.IGNORE_CASE)
private val ifscRx = Regex("""\b([A-Z]{4})[0O]([A-Z0-9]{6})\b""")
private val accountRx = Regex("""\d[\d -]{7,22}\d""")
private val honorificRx = Regex("""^(mr|mrs|ms|miss|shri|sri|smt|kumari|kum|dr)\.?\s+""", RegexOption.IGNORE_CASE)
private val nameLineRx = Regex("""^[A-Za-z][A-Za-z .']{2,}$""")
private val headerWords = listOf("government", "india", "income tax", "govt", "department", "aadhaar", "unique",
    "permanent account", "election", "commission", "licence", "license", "republic", "union", "transport", "certificate",
    "signature", "account", "number", "card")
// A line that is itself a field label ("Name of Mother", "Date of Birth"), so it can't be a value.
private val labelishRx = Regex("""^(name|surname|given|date|place|sex|gender|address|file|old passport|nationality|father|mother|spouse|husband|wife|dob|s/o|d/o|w/o)\b|\bname\s*:?$|:$""")
private fun isLabelish(s: String) = labelishRx.containsMatchIn(s.replace(Regex("""[^\x00-\x7F]"""), "").lowercase().trim(' ', '/', '|'))

// IFSC prefix → bank, for passbooks where the bank name is a logo, not text.
private val ifscBanks = mapOf(
    "SBIN" to "State Bank of India", "HDFC" to "HDFC Bank", "ICIC" to "ICICI Bank", "UTIB" to "Axis Bank",
    "PUNB" to "Punjab National Bank", "BARB" to "Bank of Baroda", "CNRB" to "Canara Bank", "UBIN" to "Union Bank of India",
    "KKBK" to "Kotak Mahindra Bank", "IDIB" to "Indian Bank", "BKID" to "Bank of India", "IOBA" to "Indian Overseas Bank",
    "CBIN" to "Central Bank of India", "YESB" to "Yes Bank", "IDFB" to "IDFC First Bank", "INDB" to "IndusInd Bank",
    "MAHB" to "Bank of Maharashtra", "UCBA" to "UCO Bank", "PSIB" to "Punjab & Sind Bank", "FDRL" to "Federal Bank",
    "KARB" to "Karnataka Bank", "KVBL" to "Karur Vysya Bank", "TMBL" to "Tamilnad Mercantile Bank", "APGV" to "Andhra Pradesh Grameena Vikas Bank",
)

// OCR swaps look-alike characters; a PAN's letter and digit positions tell us which one was meant.
private val toLetter = mapOf('0' to 'O', '1' to 'I', '5' to 'S', '8' to 'B', '2' to 'Z', '6' to 'G')
private val toDigit = mapOf('O' to '0', 'D' to '0', 'Q' to '0', 'I' to '1', 'L' to '1', 'S' to '5', 'B' to '8', 'Z' to '2', 'G' to '6')

fun findPan(upper: String): String? = panRx.find(upper)?.value ?: Regex("""\b[A-Z0-9]{10}\b""").findAll(upper).map { it.value }
    .filter { t -> t.count(Char::isLetter) >= 3 }
    .map { t -> t.mapIndexed { i, c -> if (i in 5..8) toDigit[c] ?: c else toLetter[c] ?: c }.joinToString("") }
    // 4th letter is the holder type: P person, C company, H HUF, F firm, A AOP, T trust, B BOI, L local body, J juridical, G govt.
    .firstOrNull { panRx.matches(it) && it[3] in "PCHFATBLJG" }

private val expiryLabels = arrayOf("valid till", "valid upto", "valid up to", "validity", "date of expiry", "expiry", "reg upto", "regn upto", "regn. upto")

/** Rule-based, on-device. OCR text is untrusted: everything returned is a suggestion the user confirms (FR-OCR-03/10). */
fun extract(text: String, today: LocalDate = LocalDate.now()): Pair<DocType, List<Fact>> {
    val lines = text.lines().map { it.trim() }.filter { it.isNotEmpty() }
    val upper = text.uppercase()
    val mrz = parseMrz(lines, today)
    val aadhaar = aadhaarRx.findAll(text).map { it.groupValues.drop(1).joinToString("") }.firstOrNull(::verhoeffValid)
    val pan = findPan(upper)
    val ifsc = ifscRx.find(upper)?.let { "${it.groupValues[1]}0${it.groupValues[2]}" }

    val type = when {
        mrz != null || ("PASSPORT" in upper && "REPUBLIC OF INDIA" in upper) -> DocType.PASSPORT
        // Passport back page: no MRZ and no "Republic of India", but these labels only appear there.
        "LEGAL GUARDIAN" in upper || ("FILE NO" in upper && "PASSPORT" in upper) -> DocType.PASSPORT
        "DRIVING LICEN" in upper -> DocType.DRIVING_LICENSE
        "ELECTION COMMISSION" in upper || "ELECTOR" in upper -> DocType.VOTER_ID
        "REGISTRATION CERTIFICATE" in upper || ("OWNER" in upper && "CHASSIS" in upper) -> DocType.VEHICLE_RC
        ifsc != null || "PASSBOOK" in upper || "SAVINGS BANK" in upper ||
            ("BANK" in upper && listOf("A/C", "ACCOUNT NO", "CIF").any { it in upper }) -> DocType.BANK
        "INCOME TAX" in upper || pan != null -> DocType.PAN
        aadhaar != null || "AADHAAR" in upper -> DocType.AADHAAR
        listOf("MARKS", "EXAMINATION", "BOARD", "ROLL NO").any { it in upper } -> DocType.MARKSHEET
        else -> DocType.OTHER
    }

    val facts = linkedMapOf<FactKey, String>()
    fun add(key: FactKey, v: String?) { if (!v.isNullOrBlank() && key !in facts) facts[key] = v.trim() }

    mrz?.forEach { (k, v) -> add(k, v) }

    // Name: labelled, else document-specific layout rules.
    var name = labelled(lines, "candidate's name", "name of candidate", "candidate name", "elector's name", "owner name", "owner's name",
        "account holder", "a/c holder", "customer name", "name",
        exclude = listOf("father", "mother", "husband", "wife", "spouse", "school", "institution", "guardian", "branch", "bank", "nominee", "company"))
    when (type) {
        // Aadhaar front has no "Name" label: the name is the closest plain-text line above the DOB.
        DocType.AADHAAR -> if (name == null) {
            val dobLine = lines.indexOfFirst { dateRx.containsMatchIn(it) || "year of birth" in it.lowercase() }
            if (dobLine > 0) name = (dobLine - 1 downTo 0).map { lines[it] }.firstOrNull(::isNameLine)
        }
        // Old PAN layout: name, then father's name, on the lines after the "GOVT. OF INDIA" header.
        DocType.PAN -> if (name == null) {
            val start = lines.indexOfFirst { "GOVT" in it.uppercase() }
            // PAN prints names in capitals; this also skips Hindi lines the Latin reader turns into short gibberish.
            val names = lines.drop(start + 1).filter { isNameLine(it) && it == it.uppercase() && it.split(' ').any { w -> w.length >= 3 } }.take(2)
            name = names.getOrNull(0)
            add(FactKey.FATHER, labelled(lines, "father") ?: names.getOrNull(1))
        }
        else -> Unit
    }
    add(FactKey.NAME, name?.replace(honorificRx, ""))

    add(FactKey.DOB, dateNear(lines, "date of birth", "dob", "birth")
        ?: if (type in listOf(DocType.AADHAAR, DocType.PAN, DocType.MARKSHEET, DocType.VOTER_ID)) dateRx.find(text)?.let(::fmt) else null)
    add(FactKey.EXPIRY, dateNear(lines, *expiryLabels, last = true))
    add(FactKey.GENDER, genderRx.find(text)?.value?.lowercase()?.replaceFirstChar { it.uppercase() })
    add(FactKey.FATHER, labelled(lines, "father", "s/d/w of", "s/o", "d/o", "son of", "daughter of")?.let(::cleanName))
    add(FactKey.MOTHER, labelled(lines, "mother")?.let(::cleanName))
    add(FactKey.SPOUSE, labelled(lines, "husband", "wife", "spouse", "w/o")?.let(::cleanName))
    add(FactKey.ROLL, labelled(lines, "roll no", "roll number")?.let { Regex("""\d+""").find(it)?.value })

    address(lines)?.let { (addr, pin) -> add(FactKey.ADDRESS, addr); add(FactKey.PIN_CODE, pin) }
    add(FactKey.PHONE, phoneRx.find(text)?.groupValues?.get(1))
    add(FactKey.EMAIL, emailRx.find(text)?.value)
    add(FactKey.BLOOD_GROUP, lines.firstOrNull { "blood" in it.lowercase() }?.let { l ->
        bloodRx.find(l.substringAfter(":", l))?.let { m ->
            m.groupValues[1].uppercase() + if (m.groupValues[2].startsWith("+") || m.groupValues[2].uppercase().startsWith("POS")) "+" else "-"
        }
    })

    if (type != DocType.BANK) add(FactKey.AADHAAR, aadhaar?.chunked(4)?.joinToString(" ")) // account numbers can pass the checksum
    add(FactKey.PAN, pan)
    if (type == DocType.VOTER_ID) add(FactKey.VOTER_ID, epicRx.find(upper)?.value)
    if (type == DocType.DRIVING_LICENSE) add(FactKey.DL_NUMBER, dlRx.find(upper)?.value)
    if (type == DocType.VEHICLE_RC) add(FactKey.VEHICLE_REG, vehicleRx.find(upper)?.value)
    if (type == DocType.PASSPORT) add(FactKey.PASSPORT, passportNoRx.find(upper)?.value)
    if (type == DocType.BANK) {
        add(FactKey.ACCOUNT_NO, labelled(lines, "a/c no", "a/c number", "account no", "account number", "ac no", "sb a/c", "a/c")
            ?.let { v -> accountRx.findAll(v).map { it.value.filter(Char::isDigit) }.firstOrNull { it.length in 9..18 } })
        add(FactKey.IFSC, ifsc)
        add(FactKey.BANK_NAME, lines.firstOrNull { l -> Regex("""\bbank\b""", RegexOption.IGNORE_CASE).containsMatchIn(l) &&
            l.none(Char::isDigit) && ':' !in l && l.length < 50 && "passbook" !in l.lowercase() }?.let(::titleCase)
            ?: ifsc?.let { ifscBanks[it.take(4)] })
        add(FactKey.BRANCH, labelled(lines, "branch")?.takeIf { v -> v.none(Char::isDigit) }?.let(::titleCase))
    }

    return type to facts.map { (k, v) -> Fact(k, v) }
}

fun suggestTitle(type: DocType, facts: List<Fact>): String =
    facts.firstOrNull { it.key == FactKey.NAME }?.let { "${type.label} — ${titleCase(it.value)}" } ?: type.label

fun titleCase(s: String) = s.lowercase().split(" ").filter { it.isNotBlank() }.joinToString(" ") { it.replaceFirstChar(Char::uppercase) }

private fun fmt(m: MatchResult) = "${m.groupValues[1]}/${m.groupValues[2]}/${m.groupValues[3]}"

private fun cleanName(s: String) = s.substringBefore(",").replace(Regex("""[^A-Za-z .']"""), " ").replace(Regex("""\s+"""), " ").trim().takeIf { it.length > 2 }

/** A date on the labelled line, else on the next line. `last` picks the final date ("valid from X to Y"). */
private fun dateNear(lines: List<String>, vararg labels: String, last: Boolean = false): String? {
    for ((i, line) in lines.withIndex()) {
        val lower = line.lowercase()
        if (labels.none { Regex("""\b${Regex.escape(it)}""").containsMatchIn(lower) }) continue
        for (l in listOfNotNull(line, lines.getOrNull(i + 1))) {
            val ms = dateRx.findAll(l).toList()
            if (ms.isNotEmpty()) return fmt(if (last) ms.last() else ms.first())
        }
    }
    return null
}

/** "Address:" then following lines until one ends with a 6-digit PIN code. */
private fun address(lines: List<String>): Pair<String, String>? {
    val i = lines.indexOfFirst { Regex("""\baddress\b""", RegexOption.IGNORE_CASE).containsMatchIn(it) }
    if (i < 0) return null
    val parts = mutableListOf(lines[i].substringAfter(':', lines[i].replace(Regex("""(?i).*address"""), "")).trim())
    var pin: String? = pinRx.find(parts[0])?.value
    var j = i + 1
    while (pin == null && j < lines.size && j <= i + 5) {
        parts += lines[j]
        pin = pinRx.find(lines[j])?.value
        j++
    }
    val addr = parts.map { it.trim(' ', ',') }.filter { it.isNotBlank() }.joinToString(", ").replace(Regex("""[^\x00-\x7F]"""), "").replace(Regex("""\s+"""), " ").trim(' ', ',')
    return if (pin == null || addr.length < 8) null else addr to pin
}

/** Value after a label on the same line ("Name: X"), or on the next line if the label stands alone. */
private fun labelled(lines: List<String>, vararg labels: String, exclude: List<String> = emptyList()): String? {
    for ((i, line) in lines.withIndex()) {
        val lower = line.lowercase()
        if (exclude.any { it in lower }) continue
        val m = labels.firstNotNullOfOrNull { Regex("""(?<![a-z])${Regex.escape(it)}(?![a-z])""").find(lower) } ?: continue
        // Drop bilingual label text ("नाम") and the label's tail ("'s Name :") to get the value.
        val after = line.substring(m.range.last + 1).replace(Regex("""[^\x00-\x7F]"""), "")
            .replace(Regex("""^['’]?s?\s*(name)?[\s:/\-.]*""", RegexOption.IGNORE_CASE), "")
            .replace(Regex("""^(legal\s+)?guardian('s)?(\s+name)?[\s:/\-.]*""", RegexOption.IGNORE_CASE), "").trim()
        val value = after.takeIf { it.any(Char::isLetterOrDigit) } ?: valueBelow(lines, i)
        if (value != null && labels.none { value.lowercase().startsWith(it) } && !isLabelish(value)) return value
    }
    return null
}

/**
 * The value for a label that stands alone on its line. Usually the next line, but OCR often groups labels
 * ("Name of Father", "Name of Mother", "Name of Spouse", then the values): the Nth label in a run gets the Nth value after it.
 */
private fun valueBelow(lines: List<String>, i: Int): String? {
    fun runLabel(s: String) = isLabelish(s) && "address" !in s.lowercase()
    var start = i
    while (start > 0 && runLabel(lines[start - 1])) start--
    var end = i
    while (end + 1 < lines.size && runLabel(lines[end + 1])) end++
    return lines.getOrNull(end + 1 + (i - start))
}

private fun isNameLine(s: String) = nameLineRx.matches(s) && headerWords.none { it in s.lowercase() } && !genderRx.matches(s)

/**
 * Passport machine-readable zone: line 1 "P<INDSURNAME<<GIVEN<NAMES", line 2 number, nationality, DOB, sex, expiry.
 * More reliable than the printed text, so its values win.
 */
private fun parseMrz(lines: List<String>, today: LocalDate): Map<FactKey, String>? {
    val clean = lines.map { it.replace(" ", "").replace('«', '<').uppercase() }
    val l2Rx = Regex("""([A-Z0-9<]{9})[0-9<]([A-Z<]{3})(\d{6})[0-9<]([MF<])(\d{6})""")
    val i2 = clean.indexOfFirst { it.length >= 28 && l2Rx.containsMatchIn(it) }
    if (i2 < 0) return null
    val m = l2Rx.find(clean[i2])!!
    fun date(yymmdd: String, birth: Boolean): String {
        val yy = yymmdd.take(2).toInt()
        val century = if (birth && yy > today.year % 100) 1900 else 2000
        return "${yymmdd.substring(4, 6)}/${yymmdd.substring(2, 4)}/${century + yy}"
    }
    val out = linkedMapOf(
        FactKey.PASSPORT to m.groupValues[1].replace("<", ""),
        FactKey.DOB to date(m.groupValues[3], birth = true),
        FactKey.EXPIRY to date(m.groupValues[5], birth = false),
    )
    if (m.groupValues[2] == "IND") out[FactKey.NATIONALITY] = "Indian"
    when (m.groupValues[4]) { "M" -> out[FactKey.GENDER] = "Male"; "F" -> out[FactKey.GENDER] = "Female" }
    clean.getOrNull(i2 - 1)?.takeIf { it.startsWith("P") && it.length > 5 }?.let { l1 ->
        val parts = l1.substring(5).split("<<").map { it.replace('<', ' ').trim() }.filter { it.isNotEmpty() }
        val name = listOfNotNull(parts.getOrNull(1), parts.getOrNull(0)).joinToString(" ")
        if (name.isNotBlank()) out[FactKey.NAME] = titleCase(name)
    }
    return out
}

// Verhoeff checksum: every real Aadhaar number passes it, so random 12-digit runs get rejected.
private val vd = arrayOf(
    intArrayOf(0, 1, 2, 3, 4, 5, 6, 7, 8, 9), intArrayOf(1, 2, 3, 4, 0, 6, 7, 8, 9, 5),
    intArrayOf(2, 3, 4, 0, 1, 7, 8, 9, 5, 6), intArrayOf(3, 4, 0, 1, 2, 8, 9, 5, 6, 7),
    intArrayOf(4, 0, 1, 2, 3, 9, 5, 6, 7, 8), intArrayOf(5, 9, 8, 7, 6, 0, 4, 3, 2, 1),
    intArrayOf(6, 5, 9, 8, 7, 1, 0, 4, 3, 2), intArrayOf(7, 6, 5, 9, 8, 2, 1, 0, 4, 3),
    intArrayOf(8, 7, 6, 5, 9, 3, 2, 1, 0, 4), intArrayOf(9, 8, 7, 6, 5, 4, 3, 2, 1, 0),
)
private val vp = arrayOf(
    intArrayOf(0, 1, 2, 3, 4, 5, 6, 7, 8, 9), intArrayOf(1, 5, 7, 6, 2, 8, 3, 0, 9, 4),
    intArrayOf(5, 8, 0, 3, 7, 9, 6, 1, 4, 2), intArrayOf(8, 9, 1, 6, 0, 4, 3, 5, 2, 7),
    intArrayOf(9, 4, 5, 3, 1, 2, 6, 8, 7, 0), intArrayOf(4, 2, 8, 6, 5, 7, 3, 9, 0, 1),
    intArrayOf(2, 7, 9, 3, 8, 0, 6, 4, 1, 5), intArrayOf(7, 0, 4, 6, 9, 1, 3, 2, 5, 8),
)

fun verhoeffValid(num: String): Boolean {
    if (num.length != 12 || num[0] in "01") return false
    var c = 0
    num.reversed().forEachIndexed { i, ch -> c = vd[c][vp[i % 8][ch - '0']] }
    return c == 0
}
