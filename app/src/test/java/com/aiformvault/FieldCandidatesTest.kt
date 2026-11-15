package com.aiformvault

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate

class FieldCandidatesTest {
    private val today = LocalDate.of(2026, 10, 11)

    private fun candidates(key: FactKey, vararg pages: String) = fieldCandidates(key, pages.toList(), today)

    @Test fun everyPanAcrossPagesIsListedWithItsPage() {
        val found = candidates(
            FactKey.PAN,
            "INCOME TAX DEPARTMENT\nPermanent Account Number\nABCDE1234F",
            "PAN card\nABCPS1234F",
        )
        assertEquals(listOf("ABCDE1234F", "ABCPS1234F"), found.map { it.value })
        assertEquals(listOf(1, 2), found.map { it.page })
    }

    @Test fun theSameValueOnTwoPagesIsOneCandidate() {
        val found = candidates(FactKey.PAN, "PAN ABCDE1234F", "PAN ABCDE1234F")
        assertEquals(1, found.size)
        assertEquals(1, found.single().page)
    }

    @Test fun namesComeFromLabelledLines() {
        val found = candidates(
            FactKey.NAME,
            "Name: Rahul Kumar\nFather's Name: Suresh Kumar",
            "Name of Candidate: Rahul Kumaar",
        )
        assertTrue(found.map { it.value }.containsAll(listOf("Rahul Kumar", "Rahul Kumaar")))
        assertEquals(2, found.first { it.value == "Rahul Kumaar" }.page)
    }

    @Test fun nothingPlausibleGivesAnEmptyList() {
        assertTrue(candidates(FactKey.AADHAAR, "no numbers here", "").isEmpty())
    }

    @Test fun aLabelIsNeverAValue() {
        val found = candidates(FactKey.NAME, "Name of Mother\nName of Father")
        assertTrue(found.none { it.value.lowercase().startsWith("name") })
    }
}
