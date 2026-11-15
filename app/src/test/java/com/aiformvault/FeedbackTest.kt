package com.aiformvault

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import java.time.LocalDate

/** Cases from the v4.0 tester feedback: passport back page, PAN misreads, bank passbook, form labels. */
class FeedbackTest {
    private val today = LocalDate.of(2026, 10, 12)
    private fun facts(text: String) = extract(text.trimIndent(), today).let { (t, f) -> t to f.associate { it.key to it.value } }

    @Test fun passportBackGroupedLabels() {
        val (type, f) = facts(
            """
            Name of Father / Legal Guardian
            Name of Mother
            Name of Spouse
            RAMESH KUMAR
            SITA DEVI
            Address
            H NO 12-3, GANDHI NAGAR
            HYDERABAD, TELANGANA 500032
            File No.
            HYD123456789012
            """
        )
        assertEquals(DocType.PASSPORT, type)
        assertEquals("RAMESH KUMAR", f[FactKey.FATHER])
        assertEquals("SITA DEVI", f[FactKey.MOTHER])
        assertNull(f[FactKey.SPOUSE])
        assertEquals("500032", f[FactKey.PIN_CODE])
    }

    @Test fun passportBackInterleaved() {
        val (_, f) = facts(
            """
            Name of Father / Legal Guardian
            RAMESH KUMAR
            Name of Mother
            SITA DEVI
            Name of Spouse
            Address
            H NO 12-3, GANDHI NAGAR, HYDERABAD 500032
            """
        )
        assertEquals("RAMESH KUMAR", f[FactKey.FATHER])
        assertEquals("SITA DEVI", f[FactKey.MOTHER])
        assertNull(f[FactKey.SPOUSE])
    }

    @Test fun panNewLayout() {
        val (type, f) = facts(
            """
            आयकर विभाग INCOME TAX DEPARTMENT
            भारत सरकार GOVT. OF INDIA
            Permanent Account Number Card
            ABCPK1234F
            नाम / Name
            RAHUL KUMAR
            पिता का नाम / Father's Name
            SURESH KUMAR
            जन्म की तारीख / Date of Birth
            15/08/2004
            """
        )
        assertEquals(DocType.PAN, type)
        assertEquals("RAHUL KUMAR", f[FactKey.NAME])
        assertEquals("SURESH KUMAR", f[FactKey.FATHER])
        assertEquals("15/08/2004", f[FactKey.DOB])
        assertEquals("ABCPK1234F", f[FactKey.PAN])
    }

    @Test fun panOldLayoutWithMisreadsAndHindiNoise() {
        val (type, f) = facts(
            """
            INCOME TAX DEPARTMENT
            GOVT. OF INDIA
            aTa ferT
            RAHUL KUMAR
            SURESH KUMAR
            15/08/2004
            Permanent Account Number
            A8CPKI234F
            Signature
            """
        )
        assertEquals(DocType.PAN, type)
        assertEquals("ABCPK1234F", f[FactKey.PAN])
        assertEquals("RAHUL KUMAR", f[FactKey.NAME])
        assertEquals("SURESH KUMAR", f[FactKey.FATHER])
    }

    @Test fun phoneNumberIsNotAPan() = assertNull(findPan("CALL 9876543210 NOW"))

    @Test fun bankPassbook() {
        val (type, f) = facts(
            """
            STATE BANK OF INDIA
            Branch : GACHIBOWLI
            IFSC Code : SBIN0012345
            Name : Mr. RAMESH KUMAR
            A/c No. : 3012 3456 7890
            CIF No : 81234567890
            Address : H No 1-2-3, Gachibowli
            Hyderabad 500032
            """
        )
        assertEquals(DocType.BANK, type)
        assertEquals("RAMESH KUMAR", f[FactKey.NAME])
        assertEquals("301234567890", f[FactKey.ACCOUNT_NO])
        assertEquals("SBIN0012345", f[FactKey.IFSC])
        assertEquals("State Bank Of India", f[FactKey.BANK_NAME])
        assertEquals("Gachibowli", f[FactKey.BRANCH])
        assertEquals("500032", f[FactKey.PIN_CODE])
        assertNull(f[FactKey.AADHAAR])
    }

    @Test fun bankNameFromIfscWhenLogoOnly() {
        val (_, f) = facts(
            """
            SAVINGS BANK PASSBOOK
            IFSC: HDFCO001234
            A/c No: 50100123456789
            """
        )
        assertEquals("HDFC0001234", f[FactKey.IFSC])
        assertEquals("HDFC Bank", f[FactKey.BANK_NAME])
        assertEquals("50100123456789", f[FactKey.ACCOUNT_NO])
    }

    // Real e-Aadhaar layout (details changed): issue date above the name, OCR split the DOB year, Telugu read as noise.
    @Test fun aadhaarReprintIssueDateIsNotDob() {
        val (type, f) = facts(
            """
            Aadhaar no. issued: 24/03/2013
            Government of India
            Ravi Teja Kumar
            Ds SA/DOB: 14/08/2 006
            oáya/ MALE
            So QR sE / os5 XML ws,
            Aadhaar is proof of identity, not of citizenship
            or date of birth. It should be used with verification (online
            authentication, or scanning of QR code /offline XMLJ.
            2345 6789 0124
            Details as on: 24/06/2026
            Unique ldentification Authority of India
            Koose: dyá 85 Krós s, 12, PTO
            e9o- 500001
            8 Address:
            c/O: Kumar Venkata Rao, 12, Main road,
            Near water tank, Gandhi colony,
            PO: Ramnagar, DIST: Guntur,
            Andhra Pradesh - 522001
            2345 6789 0124
            VID:9100 2000 3000 4000
            """
        )
        assertEquals(DocType.AADHAAR, type)
        assertEquals("14/08/2006", f[FactKey.DOB])
        assertEquals("Ravi Teja Kumar", f[FactKey.NAME])
        assertEquals("Male", f[FactKey.GENDER])
        assertEquals("2345 6789 0124", f[FactKey.AADHAAR])
        assertEquals("Kumar Venkata Rao", f[FactKey.FATHER])
        assertEquals("12, Main road, Near water tank, Gandhi colony, PO: Ramnagar, DIST: Guntur, Andhra Pradesh - 522001", f[FactKey.ADDRESS])
        assertEquals("522001", f[FactKey.PIN_CODE])
    }

    @Test fun formLabels() {
        assertEquals(FactKey.BRANCH, matchLabel("Branch Name"))
        assertEquals(FactKey.IFSC, matchLabel("IFSC Code"))
        assertEquals(FactKey.ACCOUNT_NO, matchLabel("Bank A/c No"))
        assertEquals(FactKey.NAME, matchLabel("Name of the Applicant"))
        assertEquals(FactKey.AADHAAR, matchLabel("Adhar No"))
        assertNull(matchLabel("Nominee Name"))
        assertNull(matchLabel("Name of the School"))
    }
}
