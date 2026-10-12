package com.aiformvault

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate

class ExtractorTest {
    private val today = LocalDate.of(2026, 10, 11)
    private fun facts(text: String) = extract(text.trimIndent(), today).let { (t, f) -> t to f.associate { it.key to it.value } }

    @Test fun aadhaarFront() {
        val (type, f) = facts(
            """
            भारत सरकार
            Government of India
            राहुल कुमार
            Rahul Kumar
            जन्म तिथि/DOB: 15/08/2004
            पुरुष/ MALE
            2345 6789 0124
            मेरा आधार, मेरी पहचान
            """
        )
        assertEquals(DocType.AADHAAR, type)
        assertEquals("Rahul Kumar", f[FactKey.NAME])
        assertEquals("15/08/2004", f[FactKey.DOB])
        assertEquals("Male", f[FactKey.GENDER])
        assertEquals("2345 6789 0124", f[FactKey.AADHAAR])
    }

    @Test fun aadhaarBackAddress() {
        val f = facts(
            """
            Unique Identification Authority of India
            Address: S/O Suresh Kumar, 12 MG Road,
            Shivaji Nagar, Pune,
            Maharashtra - 411005
            2345 6789 0124
            """
        ).second
        assertEquals("S/O Suresh Kumar, 12 MG Road, Shivaji Nagar, Pune, Maharashtra - 411005", f[FactKey.ADDRESS])
        assertEquals("411005", f[FactKey.PIN_CODE])
        assertEquals("Suresh Kumar", f[FactKey.FATHER])
    }

    @Test fun invalidAadhaarChecksumIsIgnored() {
        assertTrue(verhoeffValid("234567890124"))
        assertFalse(verhoeffValid("234567890123"))
        assertNull(facts("Aadhaar\n2345 6789 0123").second[FactKey.AADHAAR])
    }

    @Test fun oldPan() {
        val (type, f) = facts(
            """
            INCOME TAX DEPARTMENT
            GOVT. OF INDIA
            RAHUL KUMAR
            SURESH KUMAR
            15/08/2004
            Permanent Account Number
            ABCDE1234F
            """
        )
        assertEquals(DocType.PAN, type)
        assertEquals("RAHUL KUMAR", f[FactKey.NAME])
        assertEquals("SURESH KUMAR", f[FactKey.FATHER])
        assertEquals("ABCDE1234F", f[FactKey.PAN])
        assertEquals("15/08/2004", f[FactKey.DOB])
    }

    @Test fun newPanWithLabels() {
        val f = facts(
            """
            आयकर विभाग INCOME TAX DEPARTMENT
            नाम / Name
            RAHUL KUMAR
            पिता का नाम / Father's Name
            SURESH KUMAR
            जन्म की तारीख / Date of Birth
            15/08/2004
            ABCDE1234F
            """
        ).second
        assertEquals("RAHUL KUMAR", f[FactKey.NAME])
        assertEquals("SURESH KUMAR", f[FactKey.FATHER])
        assertEquals("15/08/2004", f[FactKey.DOB])
    }

    @Test fun marksheet() {
        val (type, f) = facts(
            """
            CENTRAL BOARD OF SECONDARY EDUCATION
            SECONDARY SCHOOL EXAMINATION 2020
            Roll No. 12345678
            Name of Candidate: RAHUL KUMAR
            Mother's Name: SUNITA DEVI
            Father's Name: SURESH KUMAR
            Date of Birth: 16/08/2004
            School: KENDRIYA VIDYALAYA
            """
        )
        assertEquals(DocType.MARKSHEET, type)
        assertEquals("RAHUL KUMAR", f[FactKey.NAME])
        assertEquals("SUNITA DEVI", f[FactKey.MOTHER])
        assertEquals("SURESH KUMAR", f[FactKey.FATHER])
        assertEquals("12345678", f[FactKey.ROLL])
        assertEquals("16/08/2004", f[FactKey.DOB])
    }

    @Test fun passportMrz() {
        val (type, f) = facts(
            """
            REPUBLIC OF INDIA
            P<INDKUMAR<<RAHUL<<<<<<<<<<<<<<<<<<<<<<<<<<<
            J8369854<4IND0408153M3401014<<<<<<<<<<<<<<<2
            """
        )
        assertEquals(DocType.PASSPORT, type)
        assertEquals("J8369854", f[FactKey.PASSPORT])
        assertEquals("Rahul Kumar", f[FactKey.NAME])
        assertEquals("15/08/2004", f[FactKey.DOB])
        assertEquals("01/01/2034", f[FactKey.EXPIRY])
        assertEquals("Male", f[FactKey.GENDER])
        assertEquals("Indian", f[FactKey.NATIONALITY])
    }

    @Test fun drivingLicence() {
        val (type, f) = facts(
            """
            Union of India
            Driving Licence
            MH12 20110012345
            Name: RAHUL KUMAR
            S/D/W of: SURESH KUMAR
            DOB: 15/08/2004  Blood Group: B+
            Issue Date: 01/09/2022
            Validity (NT): 01/09/2022 to 14/08/2044
            """
        )
        assertEquals(DocType.DRIVING_LICENSE, type)
        assertEquals("MH12 20110012345", f[FactKey.DL_NUMBER])
        assertEquals("RAHUL KUMAR", f[FactKey.NAME])
        assertEquals("SURESH KUMAR", f[FactKey.FATHER])
        assertEquals("15/08/2004", f[FactKey.DOB])
        assertEquals("14/08/2044", f[FactKey.EXPIRY])
        assertEquals("B+", f[FactKey.BLOOD_GROUP])
    }

    @Test fun voterId() {
        val (type, f) = facts(
            """
            ELECTION COMMISSION OF INDIA
            IDENTITY CARD
            ABC1234567
            Elector's Name : Rahul Kumar
            Father's Name : Suresh Kumar
            Gender : Male
            Date of Birth : 15/08/2004
            """
        )
        assertEquals(DocType.VOTER_ID, type)
        assertEquals("ABC1234567", f[FactKey.VOTER_ID])
        assertEquals("Rahul Kumar", f[FactKey.NAME])
        assertEquals("Suresh Kumar", f[FactKey.FATHER])
    }

    @Test fun phoneAndEmail() {
        val f = facts("Name: Rahul Kumar\nMobile: +91 9876543210\nEmail: rahul.k@example.com").second
        assertEquals("9876543210", f[FactKey.PHONE])
        assertEquals("rahul.k@example.com", f[FactKey.EMAIL])
    }

    @Test fun suggestedTitle() {
        assertEquals("PAN card — Rahul Kumar", suggestTitle(DocType.PAN, listOf(Fact(FactKey.NAME, "RAHUL KUMAR"))))
        assertEquals("Marksheet", suggestTitle(DocType.MARKSHEET, emptyList()))
    }
}
