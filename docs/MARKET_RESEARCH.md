# Market Research — Is AI Form & Vault needed?

Researched 2026-10-11. Sources at the end. Anything marked **(hypothesis)**
is not yet backed by evidence and needs testing with real users.

## Verdict

**The problem is real, but half of the product is being given away free by
the government and Google.** Storing ID documents and filling digital ID
fields are now free and backed by UIDAI or Google. What nobody covers yet is
**understanding the documents that aren't government-issued** and **filling
the forms that aren't connected to DigiLocker**: paper forms and the long
tail of college, scholarship and state portals. Build for that gap, and
validate it before building the full PRD.

## 1. What changed since the PRD was written

| Development | Date | Effect on us |
|---|---|---|
| DigiLocker: ~43 crore users, ~940 crore documents issued | Dec 2024 | "Store my ID docs" is solved for free, with government trust |
| New UIDAI Aadhaar app (QR sharing instead of photocopies, face auth, 5 family profiles), ~3.1 crore downloads in 5 months | official launch 2026 | Digital Aadhaar sharing *and* family profiles are covered for free |
| Aadhaar inside Google Wallet, with selective disclosure | live Apr 2026 | Google owns "ID on your Android phone" |
| Chrome autofill for passport, driving licence and vehicle details | Nov 2025 (desktop) | Google is moving into ID-field autofill |
| DigiLocker consent-sharing built into portals such as Passport Seva | ongoing | Big official portals pull documents directly; no typing needed there |

The PRD's competitor table (§8) is out of date: it says DigiLocker has "no
autofill of any kind". DigiLocker, Google Wallet and the Aadhaar app now
cover a lot of the digital side between them.

## 2. Micro-niches, scored (1–10)

| Niche | Pain | Money | Reach | Growth | Total |
|---|---|---|---|---|---|
| **CSC / cyber-café operators** (≈5.97 lakh CSCs; they fill forms for others all day) | 8 | 6 | 7 | 6 | **27** |
| **Students** (scholarships, admissions, entrance exams, jobs) | 7 | 3 | 8 | 6 | **24** |
| Parents during school-admission season | 7 | 6 | 5 | 5 | 23 |
| Salaried professionals doing bank/fintech KYC | 4 | 7 | 5 | 3 | 19 |
| Families managing everyone's documents | 5 | 5 | 4 | 4 | 18 |

- **Professionals doing KYC dropped:** video KYC, Aadhaar eKYC and DigiLocker already handle most of it.
- **CSC operators score highest but don't fit the current product.** They work on desktop browsers, not Android, so Android Autofill does nothing for them. They would need the Phase 3 browser extension. Storing customers' Aadhaar data also makes us a data fiduciary under India's Digital Personal Data Protection (DPDP) Act. Treat them as a second product, not the MVP.
- **Selected for the MVP: students.** Highest pain among consumers, the easiest group to reach (colleges, Instagram, YouTube, Telegram groups), and the PRD already names them as the core user. Their weakness is low willingness to pay, so monetization has to be tested early, not assumed.

## 3. Customer pain (students)

### Surface pain
- The same 10–15 facts (name exactly as on the marksheet, DOB, parents'
  names, category, income, address, roll numbers, percentages) typed into
  every scholarship, admission and exam portal.
- Marksheets, caste and income certificates are scattered across phone
  galleries, WhatsApp and paper folders.

### Deeper pain (evidence: Careers360 Q&A threads)
- **Mismatches block applications.** A DOB that differs between Aadhaar and
  the marksheet stopped one student from submitting a scholarship form.
- **Mistakes become duplicates.** Students who resubmit after an error risk
  having both applications cancelled.

### Hidden pain (hypothesis)
- Fear of missing a deadline because one document can't be found.
- Anxiety about a single typo costing a scholarship.
- Paying a cyber café to fill a form they could do themselves, because it
  feels safer.

### Midnight thoughts (hypothesis, to test in interviews)
- "Did I type my roll number right on that form?"
- "Where is my 10th marksheet PDF?"
- "Is my name spelled the same everywhere?"

**Gap in the evidence:** searches found no Reddit or forum threads of
students complaining about re-typing details. That doesn't prove the pain
is weak (students may just not post about it), but it is the biggest
unknown. User interviews come first.

## 4. Demand signals

**For:**
- A paid human service already exists: cyber-café form filling (≈₹20–100
  per form, per MONETIZATION_STRATEGY.md) is listed by CSC centres across
  India. People pay strangers to do this job.
- Indian app spending is rising: a record $345M in Q2 2026 (+35% year on
  year), with non-gaming apps at 68% of revenue in H1 2026. Revenue per
  download has more than doubled in 3.5 years.

**Against:**
- The free substitutes in §1 are strong and trusted.
- No direct forum evidence of the student pain (see the gap above).
- Students have the lowest purchasing power of any segment.

**Buyers vs browsers:**
- *Buyers:* people already paying cyber cafés; parents during admission season.
- *Browsers:* students who'd install a free tool but not pay.

| Demand score | |
|---|---|
| Urgency | Medium-high, but seasonal (deadline-driven) |
| Willingness to pay | Low for students, medium for parents and operators |
| Competition | High on storage and digital ID; **low on paper forms and non-government docs** |

## 5. What this means for the build

1. **The wedge is the scan → profile → fill loop for forms DigiLocker
   doesn't reach:** paper forms (Snap-to-Fill) and college/scholarship
   portals (Android Autofill). Our differentiators are marksheets, income
   and caste certificates, and spelling consistency across documents.
2. **Don't compete on storing Aadhaar or PAN.** Read them for facts; don't
   sell "a safe place for your Aadhaar".
3. **Move Snap-to-Fill from "Prototype" to MVP.** It's the one feature no
   free alternative offers. The relationship graph can wait.
4. **Mismatch detection is a cheap, sharp feature.** "Your DOB differs
   between Aadhaar and your 10th marksheet" solves a real blocker the
   evidence shows.

## 6. Validation plan (2–3 weeks, before building features)

### Test 1: Interviews (week 1)
- **Plan:** 15 students and 5 cyber-café or CSC operators. Ask about the
  last form they filled: how long it took, what went wrong, whether they
  paid anyone. Don't pitch the app.
- **Pass:** at least 10 of 15 students describe re-typing or a mismatch
  problem without being prompted.

### Test 2: Fake door (weeks 1–2)
- **Plan:** a one-page site ("Photograph any form. We fill it from your
  documents.") with a waitlist button, shared in 5 college Telegram or
  WhatsApp groups during a scholarship window (e.g. NSP).
- **Pass:** at least 8% of visitors join the waitlist.

### Test 3: Content (weeks 1–3)
- **Plan:** 5 short Reels or Shorts showing a paper scholarship form
  being filled from a phone scan (screen-recorded mockup).
- **Pass:** saves and shares beat the account's average, and comments ask
  "which app?".

### Test 4: Pre-sell (week 3, only if Tests 1–2 pass)
- **Plan:** offer ₹99 for a "scholarship season pass" to waitlist signups.
- **Pass:** at least 20 paid signups.

**Decision rule:** if Tests 1 and 2 both fail, pivot to the CSC-operator
browser tool (a different product), or stop.

## Sources
- [Chrome autofill for passports and licences — TechCrunch](https://techcrunch.com/2025/11/03/chrome-can-now-autofill-your-passport-drivers-license-and-vehicle-registration-info)
- [Aadhaar on Google Wallet — Google India blog](https://blog.google/intl/en-in/company-news/technology/partnering-with-uidai-to-bring-a-secure-digital-first-identity-with-aadhaar-on-google-wallet/)
- [Google Wallet Aadhaar live — Business Today](https://www.businesstoday.in/technology/story/google-wallet-gets-aadhaar-digital-id-support-in-india-527799-2026-04-28)
- [New Aadhaar app features — ClearTax](https://cleartax.in/s/new-aadhaar-app-with-face-id-qr-code)
- [New Aadhaar app — Angel One](https://www.angelone.in/news/personal-finance/new-aadhaar-app-launched-check-7-big-features-every-user-should-know)
- [DigiLocker — Wikipedia](https://en.wikipedia.org/wiki/DigiLocker)
- [DigiLocker on Google Play](https://play.google.com/store/apps/details?id=com.digilocker.android&hl=en_IN)
- [Passport Seva: fetch documents from DigiLocker](https://portal2.passportindia.gov.in/AppOnlineProject/pdf/FetchDocumentsFromDigiLocker.pdf)
- [CSC count — Rajya Sabha answer, Mar 2025](https://rsdebate.nic.in/bitstream/123456789/759405/1/PQ_267_21032025_S237_p34_p35.pdf)
- [India is starting to pay for apps — TechCrunch](https://techcrunch.com/2026/07/31/india-is-starting-to-pay-for-apps-not-just-download-them/)
- [Scholarship DOB mismatch — Careers360](https://www.careers360.com/question-respected-sir-i-am-a-student-of-your-reputed-college-due-to-some-technical-problemvariance-in-dob-in-adhar-and-marksheet-i-am-unable-to-fill-scholarship-form-at-the-due-datekindly-assistmy-details-are-as-follows-name-alfiya-naaz-bsc-student-mob-7239030204-email-adorableatiqgmailco/amp)
- [Duplicate scholarship applications — Careers360](https://www.careers360.com/question-i-have-fill-up-the-inspire-scholarship-form-twice-with-two-different-mail-id-in-the-first-time-i-have-mistakenly-uploaded-the-10-th-admit-instead-of-10-th-certificate-or-result-in-the-second-time-i-have-done-all-right-and-i-have-update-my-profile-only-in-second-time-then-what-will-happen/amp)
