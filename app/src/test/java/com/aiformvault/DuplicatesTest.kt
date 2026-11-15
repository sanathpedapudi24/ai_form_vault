package com.aiformvault

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class DuplicatesTest {
    private fun doc(
        id: String = "d1",
        type: DocType = DocType.AADHAAR,
        owner: String = "me",
        title: String = "Aadhaar card — Rahul Kumar",
        facts: List<Fact> = listOf(Fact(FactKey.AADHAAR, "2345 6789 0124")),
    ) = Document(id, type, type.category, title, owner, facts, pages = 1, createdAt = 0)

    @Test fun sameNumberDifferentSpacingIsADuplicate() {
        val existing = listOf(doc(facts = listOf(Fact(FactKey.AADHAAR, "2345 6789 0124"))))
        listOf("2345-6789-0124", "234567890124", "2345 6789-0124").forEach { spelled ->
            val draft = doc(id = "draft", facts = listOf(Fact(FactKey.AADHAAR, spelled)))
            assertTrue("$spelled should match", findDuplicates(draft, existing).size == 1)
        }
    }

    @Test fun sameNumberDifferentTypeIsNotAStrongDuplicate() {
        val existing = listOf(doc(type = DocType.PAN, facts = listOf(Fact(FactKey.PAN, "ABCDE1234F"))))
        val draft = doc(id = "draft", type = DocType.AADHAAR, title = "Aadhaar card — Rahul Kumar",
            facts = listOf(Fact(FactKey.AADHAAR, "ABCDE1234F")))
        assertTrue(findDuplicates(draft, existing).isEmpty())
        assertTrue(duplicatesOf(draft, existing).none { it.strong })
    }

    @Test fun oneDigitDifferenceIsNotADuplicate() {
        val existing = listOf(doc(facts = listOf(Fact(FactKey.AADHAAR, "2345 6789 0124"))))
        val draft = doc(id = "draft", facts = listOf(Fact(FactKey.AADHAAR, "2345 6789 0125")))
        assertTrue(findDuplicates(draft, existing).isEmpty())
    }

    @Test fun blankOrTinyValueNeverMatches() {
        val existing = listOf(
            doc(id = "d1", title = "Old Aadhaar", facts = listOf(Fact(FactKey.AADHAAR, ""))),
            doc(id = "d2", title = "Some card", facts = listOf(Fact(FactKey.PAN, "A"))),
        )
        val draft = doc(id = "draft", title = "New scan", facts = listOf(Fact(FactKey.AADHAAR, ""), Fact(FactKey.PAN, "A")))
        assertTrue(findDuplicates(draft, existing).isEmpty())
        assertTrue(duplicatesOf(draft, existing).isEmpty())
    }

    @Test fun importingIntoAnEmptyVaultFindsNothing() {
        assertTrue(duplicatesOf(doc(id = "draft"), emptyList()).isEmpty())
    }

    @Test fun sameTypeOwnerAndTitleIsAWeakSignalOnly() {
        val existing = listOf(doc(type = DocType.MARKSHEET, title = "Marksheet — Rahul Kumar", facts = emptyList()))
        val draft = doc(id = "draft", type = DocType.MARKSHEET, title = "marksheet —  rahul kumar", facts = emptyList())
        val hits = duplicatesOf(draft, existing)
        assertEquals(1, hits.size)
        assertFalse(hits.single().strong)
        assertTrue(findDuplicates(draft, existing).isEmpty())
    }

    @Test fun theDraftItselfIsNeverItsOwnDuplicate() {
        val existing = listOf(doc(id = "same"))
        assertTrue(duplicatesOf(doc(id = "same"), existing).isEmpty())
    }

    @Test fun differentOwnerBreaksTheWeakSignal() {
        val existing = listOf(doc(owner = "me", facts = emptyList()))
        val draft = doc(id = "draft", owner = "someone-else", facts = emptyList())
        assertTrue(duplicatesOf(draft, existing).isEmpty())
    }
}
