package com.aiformvault

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate

class MatchingTest {
    private val today = LocalDate.of(2026, 10, 11)
    private val me = Person("me", "Rahul Kumar", Relation.SELF, true)
    private val sis = Person("sis", "Priya Kumar", Relation.SIBLING, true)

    private fun doc(id: String, type: DocType, owner: String, vararg facts: Pair<FactKey, String>, note: String = "") =
        Document(id, type, type.category, "${type.label} — x", owner, facts.map { Fact(it.first, it.second) }, 1, note, createdAt = id.hashCode().toLong())

    private val data = VaultData(
        documents = listOf(
            doc("1", DocType.AADHAAR, "me", FactKey.DOB to "15/08/2004"),
            doc("2", DocType.AADHAAR, "sis"),
            doc("3", DocType.PASSPORT, "me", FactKey.EXPIRY to "01/03/2027"),
            doc("4", DocType.MARKSHEET, "me", FactKey.DOB to "16/08/2004", note = "used for NSP scholarship"),
            doc("5", DocType.DRIVING_LICENSE, "me", FactKey.EXPIRY to "14/08/2044"),
        ),
        people = listOf(me, sis),
    )

    @Test fun formLabels() {
        assertEquals(FactKey.NAME, matchLabel("Name of Applicant"))
        assertEquals(FactKey.FATHER, matchLabel("Father's Name"))
        assertEquals(FactKey.DOB, matchLabel("Date of Birth (DD/MM/YYYY)"))
        assertEquals(FactKey.PHONE, matchLabel("Mobile No."))
        assertEquals(FactKey.PIN_CODE, matchLabel("PIN Code"))
        assertEquals(FactKey.NAME, matchLabel("firstName"))
        assertEquals(FactKey.EMAIL, matchLabel("user_email"))
        assertNull(matchLabel("Signature of candidate's guardian with date and place and seal of office"))
        assertNull(matchLabel("Hotel"))
    }

    @Test fun fuzzyNames() {
        assertTrue(sameName("RAHUL KUMAR", "Kumar Rahul"))
        assertTrue(sameName("Rahul Kumar Sharma", "Rahul Sharma"))
        assertTrue(sameName("Suresh Kumar", "Sures Kumar")) // one-letter OCR slip
        assertFalse(sameName("Rahul Kumar", "Priya Kumar"))
    }

    @Test fun relationSuggestionsOnlyFromOwnDocsAndNewPeople() {
        val pan = doc("9", DocType.PAN, "me", FactKey.FATHER to "SURESH KUMAR", FactKey.MOTHER to "PRIYA KUMAR")
        val s = suggestRelations(data, pan)
        assertEquals(listOf("Suresh Kumar"), s.map { it.name }) // Priya is already known
        assertEquals(Relation.FATHER, s[0].relation)
        assertFalse(s[0].confirmed)
        assertTrue(suggestRelations(data, pan.copy(ownerId = "sis")).isEmpty())
    }

    @Test fun searchByRelation() = assertEquals(listOf("2"), search("sister's aadhaar", data, today).map { it.id })

    @Test fun searchByExpiry() = assertEquals(listOf("3"), search("what expires next year", data, today).map { it.id })

    @Test fun searchByCategory() = assertEquals(setOf("1", "2", "5"), search("ID documents", data, today).map { it.id }.toSet())

    @Test fun searchNotes() = assertEquals(listOf("4"), search("scholarship", data, today).map { it.id })

    @Test fun profileMismatchAndManualOverride() {
        val m = mismatches(profile(data))
        assertEquals(listOf(FactKey.DOB), m.map { it.key })
        val fixed = data.copy(manual = listOf(ManualFact(FactKey.DOB, "15/08/2004", 0)))
        assertTrue(mismatches(profile(fixed)).isEmpty())
        assertEquals("15/08/2004", bestFacts(fixed)[FactKey.DOB])
    }

    @Test fun otherPeoplesDocsStayOutOfProfile() {
        val d = data.copy(documents = listOf(doc("2", DocType.AADHAAR, "sis", FactKey.NAME to "Priya Kumar")))
        assertTrue(profile(d).isEmpty())
    }

    @Test fun masking() = assertEquals("•••• •••• 0124", mask(FactKey.AADHAAR, "2345 6789 0124"))
}
