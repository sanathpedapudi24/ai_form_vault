# Diagrams (Eraser.io diagram-as-code, v4.1)

Paste each block into an Eraser canvas: Diagram → "Flow chart", then the code
editor.

## 1. Architecture

```
title AI Form & Vault v4.1 (everything on the phone)

Input [color: teal] {
  Document scanner [icon: camera]
  PDF import [icon: file-text]
  Form photo [icon: image]
}
Reading [color: green] {
  OCR plain [icon: eye, label: "ML Kit OCR"]
  OCR boosted [icon: sun, label: "OCR, high contrast"]
}
Understanding [color: green] {
  Extractor [icon: cpu, label: "Rules per document type"]
  Matcher [icon: link, label: "Label → detail matcher"]
}
Storage [color: blue] {
  Vault [icon: lock, label: "vault.bin (AES-256-GCM, Keystore)"]
  Images [icon: image, label: "Encrypted page images"]
}
Output [color: orange] {
  Profile [icon: user]
  Snap-to-Fill [icon: edit]
  Autofill [icon: smartphone, label: "Android autofill"]
  Reminders [icon: bell, label: "Expiry reminders"]
}

Document scanner > OCR plain
PDF import > OCR plain
OCR plain > OCR boosted: same page
OCR boosted > Extractor: whichever read more
Extractor > Vault: after you review and save
Document scanner > Images
Vault > Profile: your documents + your edits
Profile > Snap-to-Fill
Profile > Autofill: shareable details only
Form photo > Matcher
Matcher > Snap-to-Fill
Vault > Reminders
```

## 2. Scanning a document

```
title Scan → review → save

Scan [shape: oval, icon: camera, color: teal]
OCR [icon: eye, label: "Read text (plain + high contrast)"]
Type [shape: diamond, icon: help-circle, label: "Which document?"]
Passport [icon: globe, label: "Passport: MRZ, or back page labels"]
Bank [icon: dollar-sign, label: "Passbook: IFSC, A/c no, bank, branch"]
PAN [icon: credit-card, label: "PAN: fix O/0, I/1 misreads"]
Aadhaar [icon: credit-card, label: "Aadhaar: checksum-valid number"]
Others [icon: file, label: "Voter ID, DL, RC, marksheet"]
Labels [icon: list, label: "Labels → values (grouped label runs)"]
Review [icon: check-square, label: "Review: edit, see what's missing"]
Report [icon: send, label: "Send scanned text (misread report)"]
Save [shape: oval, icon: lock, color: green, label: "Encrypted save"]
Family [icon: users, label: "Suggest father / mother / spouse"]

Scan > OCR > Type
Type > Passport, Bank, PAN, Aadhaar, Others
Passport, Bank, PAN, Aadhaar, Others > Labels
Labels > Review
Review > Report: optional
Review > Save
Save > Family: your own documents only
```

## 3. Snap-to-Fill

```
title Snap-to-Fill: paper form → filled image

Photo [shape: oval, icon: camera, color: teal, label: "Photograph blank form"]
Lines [icon: eye, label: "OCR lines + word positions"]
Choice [shape: diamond, label: "Male / Female on one line?"]
Tick [icon: check-square, label: "Tick box field: pick the option"]
Label [shape: diamond, label: "Known label?"]
Skip [icon: x, label: "Nominee / witness / school: never filled"]
Text [icon: type, label: "Text field: value from profile"]
Hint [icon: info, label: "Empty: 'Found on: PAN card…'"]
Check [icon: edit, label: "You check every field"]
Render [icon: pen-tool, label: "Draw text, ticks and circles"]
Learn [icon: save, label: "Corrections saved to profile"]
Share [shape: oval, icon: share-2, color: green, label: "Share / print"]

Photo > Lines > Choice
Choice > Tick: yes
Choice > Label: no
Label > Skip: about someone else
Label > Text: yes
Text > Hint: no value yet
Tick, Text, Hint > Check
Check > Render > Share
Check > Learn
```
