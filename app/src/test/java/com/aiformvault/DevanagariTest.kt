package com.aiformvault

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class DevanagariTest {
    private fun hindi(text: String) = extractDevanagari(text.trimIndent()).associate { it.key to it.value }

    @Test fun nameFromAHindiLabel() {
        val f = hindi(
            """
            भारत सरकार
            नाम : राहुल कुमार
            जन्म तिथि : 15/08/2004
            """
        )
        assertEquals("राहुल कुमार", f[FactKey.NAME])
    }

    @Test fun fatherLabelWinsOverTheNameLabelInsideIt() {
        val f = hindi(
            """
            नाम: राहुल कुमार
            पिता का नाम: सुरेश कुमार
            """
        )
        assertEquals("राहुल कुमार", f[FactKey.NAME])
        assertEquals("सुरेश कुमार", f[FactKey.FATHER])
    }

    @Test fun aLabelAloneOnItsLineTakesTheLineBelow() {
        val f = hindi(
            """
            नाम
            सुनीता देवी
            माता का नाम
            कमला देवी
            """
        )
        assertEquals("सुनीता देवी", f[FactKey.NAME])
        assertEquals("कमला देवी", f[FactKey.MOTHER])
    }

    @Test fun headerWordsAreNeverNames() {
        val f = hindi(
            """
            भारत सरकार
            विशिष्ट पहचान संख्या
            आधार
            """
        )
        assertTrue(f.isEmpty())
    }

    @Test fun honorificsAreDropped() {
        assertEquals("रमेश चंद्र", hindi("पिता का नाम: श्री रमेश चंद्र")[FactKey.FATHER])
    }

    @Test fun latinTextProducesNothing() {
        assertTrue(extractDevanagari("Rahul Kumar\nDOB 15/08/2004").isEmpty())
    }

    @Test fun mergeOnlyFillsNamesThatAreMissing() {
        val latin = listOf(Fact(FactKey.NAME, "Rahul Kumar"), Fact(FactKey.DOB, "15/08/2004"))
        val added = mergeDevanagari(latin, listOf(Fact(FactKey.NAME, "राहुल कुमार"), Fact(FactKey.FATHER, "सुरेश कुमार")))
        assertEquals("Rahul Kumar", added.first { it.key == FactKey.NAME }.value)
        assertEquals("सुरेश कुमार", added.first { it.key == FactKey.FATHER }.value)
        assertEquals(3, added.size)
    }

    @Test fun mergeNeverAddsNonNameFacts() {
        val latin = listOf(Fact(FactKey.DOB, "15/08/2004"))
        val added = mergeDevanagari(latin, listOf(Fact(FactKey.ADDRESS, "किसी गली, दिल्ली")))
        assertEquals(1, added.size)
    }

    @Test fun normalizeKeepsDevanagariAndCollapsesSpacing() {
        assertEquals(normalize(FactKey.NAME, "राहुल   कुमार "), normalize(FactKey.NAME, "राहुल कुमार"))
        assertTrue(normalize(FactKey.NAME, "राहुल कुमार").isNotBlank())
    }

    @Test fun aHindiNameLineIsAReReadCandidate() {
        val found = fieldCandidates(FactKey.NAME, listOf("भारत सरकार\nराहुल कुमार\nपिता का नाम: सुरेश कुमार"))
        assertTrue(found.map { it.value }.contains("राहुल कुमार"))
    }
}
