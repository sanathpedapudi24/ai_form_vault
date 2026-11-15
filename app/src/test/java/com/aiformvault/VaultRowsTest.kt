package com.aiformvault

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class VaultRowsTest {
    private val data = VaultData(
        documents = listOf(
            Document(
                id = "d1", type = DocType.AADHAAR, category = Category.IDENTITY, title = "Aadhaar card — Rahul",
                ownerId = "me", facts = listOf(Fact(FactKey.NAME, "Rahul Kumar"), Fact(FactKey.AADHAAR, "2345 6789 0124")),
                pages = 1, note = "", createdAt = 100L,
            ),
            Document(
                id = "d2", type = DocType.PAN, category = Category.IDENTITY, title = "PAN card",
                ownerId = "me", facts = listOf(Fact(FactKey.NAME, "Ramesh"), Fact(FactKey.PAN, "ABCDE1234F")),
                pages = 2, createdAt = 200L,
            ),
        ),
        people = listOf(Person("me", "Rahul Kumar", Relation.SELF, true)),
        manual = listOf(ManualFact(FactKey.NAME, "राहुल कुमार", 300L)),
        fieldsFilled = 2,
    )

    @Test fun roundTripPreservesEverything() {
        val back = data.toRows().toVault()
        assertEquals(data.documents.size, back.documents.size)
        assertEquals(data.documents[0], back.documents[0])
        assertEquals(data.documents[1], back.documents[1])
        assertEquals(data.people, back.people)
        assertEquals(data.manual, back.manual)
        assertEquals(data.fieldsFilled, back.fieldsFilled)
        assertEquals(4, back.documents.sumOf { it.facts.size })
    }

    @Test fun anEmptyVaultMapsToEmptyRows() {
        val rows = VaultData().toRows()
        assertTrue(rows.documents.isEmpty())
        assertTrue(rows.facts.isEmpty())
        assertTrue(rows.people.isEmpty())
        assertEquals(0, rows.fieldsFilled)
    }
}
