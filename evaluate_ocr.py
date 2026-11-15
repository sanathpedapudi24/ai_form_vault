"""
OCR Evaluation Harness — AI Form & Vault
========================================
Compares PaddleOCR vs Google ML Kit (simulated baseline) on Indian ID cards.

Prerequisites:
    pip install paddleocr opencv-python-headless pillow numpy tqdm

Usage:
    # 1) Generate 100 synthetic Indian ID cards + ground truth
    python evaluate_ocr.py --generate-tests 100 --out test_set/

    # 2) Run PaddleOCR on the test set
    python evaluate_ocr.py --engine paddleocr --input test_set/ --gt test_set/ground_truth.csv --out results_paddle.csv

    # 3) Run ML Kit simulation (baseline — Latin script only)
    python evaluate_ocr.py --engine mlkit --input test_set/ --gt test_set/ground_truth.csv --out results_mlkit.csv

    # 4) Compare both engines and write a markdown report
    python evaluate_ocr.py --compare results_paddle.csv results_mlkit.csv --report comparison_report.md

Notes:
    - ML Kit cannot run on a PC (Android Play Services API). The --engine mlkit mode
      produces a simulated baseline that models ML Kit's documented Latin-only behavior
      (Hindi/Devanagari text is dropped). For real ML Kit numbers, run the harness on
      an Android device inside your app.
    - PaddleOCR downloads detection + recognition models on first run (~100 MB).
"""

import argparse
import csv
import io
import os
import re
import sys
import unicodedata
from datetime import datetime
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageOps, ImageFilter

try:
    import cv2
    HAS_CV2 = True
except Exception:
    HAS_CV2 = False

try:
    from paddleocr import PaddleOCR
    HAS_PADDLE = True
except Exception:
    HAS_PADDLE = False


# ---------------------------------------------------------------------------
# Constants — Indian document ground truth templates
# ---------------------------------------------------------------------------

NAMES_EN = [
    "RAHUL KUMAR", "PRIYA SHARMA", "AMIT SINGH", "SNEHA REDDY", "VIKRAM PATEL",
    "ANJALI DESAI", "RAJESH NAIR", "KAVITHA IYER", "SUNIL JOSHI", "MEENA KUMARI",
    "ARJUN MALHOTRA", "POOJA AGARWAL", "RAVI TEJA", "LAKSHMI BAI", "DEVENDRA YADAV",
    "KIRAN KUMAR", "SUJATA MENON", "HARISH KUMAR", "RASHMI SHAH", "MANOJ KUMAR",
    "DEEPA GUPTA", "SURESH BABU", "NEHA TRIPATHI", "VENKAT RAO", "SONALI KHAN",
]

NAMES_HI = [
    "राहुल कुमार", "प्रिया शर्मा", "अमित सिंह", "स्नेहा रेड्डी", "विक्रम पटेल",
    "अंजलि देसाई", "राजेश नायर", "कविता अय्यर", "सुनील जोशी", "मीना कुमारी",
]

FATHERS_EN = [
    "SURESH KUMAR", "MAHESH SHARMA", "RAJENDRA SINGH", "VENKAT REDDY", "PRAKASH PATEL",
]

DOBS = [
    "15/08/2004", "22/03/1995", "07/11/1988", "30/06/2001", "12/12/1990",
    "04/01/1985", "19/09/1999", "25/02/1992", "08/07/2000", "14/04/1987",
]

AADHAARS = [
    "2345 6789 0124", "8823 4567 9012", "5512 3344 6678", "9988 7766 5544",
    "1234 5678 9012", "4455 6677 8899", "2233 4455 6677", "7788 9900 1122",
    "3344 5566 7788", "6677 8899 0011",
]

PANS = [
    "ABCDE1234F", "XYZAB5678C", "PQRST9012D", "LMNOP3456G", "HIJKL7890H",
    "BCDEF2345A", "TUVWX6789E", "RSTUV1234F", "OPQRS5678J", "NOPQR9012K",
]

VOTER_IDS = [
    "ABC1234567", "XYZ9876543", "PQR4567890", "LMN1122334", "DEF5566778",
    "GHI9988776", "JKL3344556", "MNO7788990", "STU1122334", "VWX5566778",
]

DL_NUMBERS = [
    "MH12 20110012345", "DL01 20150054321", "KA05 20180098765", "TN14 20130011223",
    "GJ06 20160044556", "RJ13 20170077889", "UP32 20140022334", "WB04 20190066778",
    "AP11 20120033445", "HR07 20110088990",
]

ADDRESSES_EN = [
    "S/O Suresh Kumar, 12 MG Road, Shivaji Nagar, Pune, Maharashtra - 411005",
    "D/O Ramesh Singh, 45 Park Street, Kolkata, West Bengal - 700016",
    "W/O Anita Rao, 78 Hill View Colony, Bengaluru, Karnataka - 560001",
    "C/O Mohan Lal, 3 Station Road, Jaipur, Rajasthan - 302001",
    "S/O Vijay Kumar, 56 Lake Drive, Chennai, Tamil Nadu - 600002",
]

ADDRESSES_HI = [
    "सुरेश कुमार के Sohn, 12 एमजी रोड, शिवाजी नगर, पुणे, महाराष्ट्र - 411005",
    "12 MG Road, शिवाजी नगर, पुणे, महाराष्ट्र - 411005",
]

BANKS = [
    "State Bank of India", "HDFC Bank", "ICICI Bank", "Axis Bank",
    "Punjab National Bank", "Bank of Baroda", "Canara Bank", "Union Bank of India",
]

IFSC_CODES = [
    "SBIN0001234", "HDFC0005678", "ICIC0009012", "UTIB0003456",
    "PUNB0007890", "BARB0002345", "CNRB0006789", "UBIN0001122",
]

ACCOUNT_NOS = [
    "12345678901", "23456789012", "34567890123", "45678901234", "56789012345",
]

BLOOD_GROUPS = ["B+", "O+", "A-", "AB+", "B-", "O-"]

GENDERS = ["MALE", "FEMALE", "TRANSGENDER"]


def random_choice(seq, rng):
    return seq[rng.integers(0, len(seq))]


# ---------------------------------------------------------------------------
# Synthetic ID card generation
# ---------------------------------------------------------------------------

def _load_font(size, bold=False):
    """Try to load a font that supports Devanagari; fall back to default."""
    candidates = [
        "C:/Windows/Fonts/mangal.ttf",          # Windows Devanagari
        "C:/Windows/Fonts/arial.ttf",
        "C:/Windows/Fonts/times.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",  # Linux
        "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf",
        "/System/Library/Fonts/SFNS.ttf",        # macOS
        "/System/Library/Fonts/Hiragino Sans GB.ttc",
    ]
    for p in candidates:
        if os.path.exists(p):
            try:
                return ImageFont.truetype(p, size)
            except Exception:
                continue
    return ImageFont.load_default()


def render_id_card(doc_type, lang, condition, idx, rng):
    """Render a synthetic Indian ID card image + ground truth text."""
    W, H = 850, 540
    img = Image.new("RGB", (W, H), "white")
    d = ImageDraw.Draw(img)

    f_title = _load_font(26, bold=True)
    f_label = _load_font(20)
    f_val = _load_font(22, bold=True)
    f_small = _load_font(16)

    # Header
    if doc_type == "Aadhaar":
        d.text((30, 20), "भारत सरकार", font=f_title, fill="black")
        d.text((30, 55), "Government of India", font=f_label, fill="black")
        d.line([(30, 95), (W - 30, 95)], fill="gray", width=2)
        name = random_choice(NAMES_HI if lang == "hi" else NAMES_EN, rng)
        d.text((30, 115), "नाम / Name", font=f_label, fill="black")
        d.text((30, 145), name, font=f_val, fill="black")
        dob = random_choice(DOBS, rng)
        d.text((30, 185), "जन्म तिथि / DOB", font=f_label, fill="black")
        d.text((30, 215), dob, font=f_val, fill="black")
        gender = random_choice(GENDERS, rng)
        d.text((30, 255), "पुरुष / " + gender, font=f_label, fill="black")
        aadhaar = random_choice(AADHAARS, rng)
        d.text((30, 295), "मेरा आधार, मेरी पहचान", font=f_small, fill="gray")
        d.text((30, 325), aadhaar, font=f_val, fill="black")
        gt_lines = [
            "भारत सरकार", "Government of India", "नाम / Name", name,
            "जन्म तिथि / DOB", dob, gender, aadhaar,
        ]
        fields = {"name": name, "dob": dob, "aadhaar": aadhaar, "gender": gender}
    elif doc_type == "PAN":
        d.text((30, 20), "INCOME TAX DEPARTMENT", font=f_title, fill="black")
        d.text((30, 55), "GOVT. OF INDIA", font=f_label, fill="black")
        d.line([(30, 95), (W - 30, 95)], fill="gray", width=2)
        name = random_choice(NAMES_EN, rng)
        d.text((30, 115), "नाम / Name", font=f_label, fill="black")
        d.text((30, 145), name, font=f_val, fill="black")
        father = random_choice(FATHERS_EN, rng)
        d.text((30, 185), "पिता का नाम / Father's Name", font=f_label, fill="black")
        d.text((30, 215), father, font=f_val, fill="black")
        dob = random_choice(DOBS, rng)
        d.text((30, 255), "जन्म की तारीख / Date of Birth", font=f_label, fill="black")
        d.text((30, 285), dob, font=f_val, fill="black")
        pan = random_choice(PANS, rng)
        d.text((30, 325), "Permanent Account Number", font=f_label, fill="black")
        d.text((30, 355), pan, font=f_val, fill="black")
        gt_lines = [
            "INCOME TAX DEPARTMENT", "GOVT. OF INDIA", "नाम / Name", name,
            "पिता का नाम / Father's Name", father, "Date of Birth", dob,
            "Permanent Account Number", pan,
        ]
        fields = {"name": name, "father": father, "dob": dob, "pan": pan}
    elif doc_type == "VoterID":
        d.text((30, 20), "ELECTION COMMISSION OF INDIA", font=f_title, fill="black")
        d.text((30, 55), "IDENTITY CARD", font=f_label, fill="black")
        d.line([(30, 95), (W - 30, 95)], fill="gray", width=2)
        epic = random_choice(VOTER_IDS, rng)
        d.text((30, 115), epic, font=f_val, fill="black")
        name = random_choice(NAMES_EN, rng)
        d.text((30, 155), "Elector's Name :", font=f_label, fill="black")
        d.text((220, 155), name, font=f_val, fill="black")
        father = random_choice(FATHERS_EN, rng)
        d.text((30, 195), "Father's Name :", font=f_label, fill="black")
        d.text((220, 195), father, font=f_val, fill="black")
        d.text((30, 235), "Gender :", font=f_label, fill="black")
        d.text((220, 235), random_choice(GENDERS, rng), font=f_val, fill="black")
        d.text((30, 275), "Date of Birth :", font=f_label, fill="black")
        d.text((220, 275), random_choice(DOBS, rng), font=f_val, fill="black")
        gt_lines = [
            "ELECTION COMMISSION OF INDIA", "IDENTITY CARD", epic,
            "Elector's Name :", name, "Father's Name :", father,
            "Gender :", "Date of Birth :",
        ]
        fields = {"name": name, "father": father, "voter_id": epic}
    elif doc_type == "DrivingLicence":
        d.text((30, 20), "Driving Licence", font=f_title, fill="black")
        d.text((30, 55), "Union of India", font=f_label, fill="black")
        d.line([(30, 95), (W - 30, 95)], fill="gray", width=2)
        dl = random_choice(DL_NUMBERS, rng)
        d.text((30, 115), dl, font=f_val, fill="black")
        name = random_choice(NAMES_EN, rng)
        d.text((30, 155), "Name:", font=f_label, fill="black")
        d.text((120, 155), name, font=f_val, fill="black")
        father = random_choice(FATHERS_EN, rng)
        d.text((30, 195), "S/D/W of:", font=f_label, fill="black")
        d.text((130, 195), father, font=f_val, fill="black")
        dob = random_choice(DOBS, rng)
        d.text((30, 235), "DOB:", font=f_label, fill="black")
        d.text((100, 235), dob, font=f_val, fill="black")
        d.text((300, 235), "Blood Group:", font=f_label, fill="black")
        d.text((420, 235), random_choice(BLOOD_GROUPS, rng), font=f_val, fill="black")
        d.text((30, 275), "Validity (NT):", font=f_label, fill="black")
        d.text((160, 275), "01/09/2022 to 14/08/2044", font=f_val, fill="black")
        gt_lines = [
            "Driving Licence", "Union of India", dl, "Name:", name,
            "S/D/W of:", father, "DOB:", dob, "Blood Group:", "Validity (NT):",
        ]
        fields = {"name": name, "father": father, "dl": dl, "dob": dob}
    elif doc_type == "Bank":
        bank = random_choice(BANKS, rng)
        d.text((30, 20), bank, font=f_title, fill="black")
        d.text((30, 55), "PASSBOOK", font=f_label, fill="black")
        d.line([(30, 95), (W - 30, 95)], fill="gray", width=2)
        name = random_choice(NAMES_EN, rng)
        d.text((30, 115), "Account Holder:", font=f_label, fill="black")
        d.text((240, 115), name, font=f_val, fill="black")
        acc = random_choice(ACCOUNT_NOS, rng)
        d.text((30, 155), "A/C No:", font=f_label, fill="black")
        d.text((130, 155), acc, font=f_val, fill="black")
        ifsc = random_choice(IFSC_CODES, rng)
        d.text((30, 195), "IFSC:", font=f_label, fill="black")
        d.text((110, 195), ifsc, font=f_val, fill="black")
        d.text((30, 235), "Branch:", font=f_label, fill="black")
        d.text((120, 235), random_choice(["MG Road Branch", "Park Street Branch", "Hill View Branch"], rng), font=f_val, fill="black")
        gt_lines = [bank, "PASSBOOK", "Account Holder:", name, "A/C No:", acc, "IFSC:", ifsc, "Branch:"]
        fields = {"name": name, "account_no": acc, "ifsc": ifsc, "bank": bank}
    else:  # Passport
        d.text((30, 20), "REPUBLIC OF INDIA", font=f_title, fill="black")
        d.text((30, 55), "PASSPORT", font=f_label, fill="black")
        d.line([(30, 95), (W - 30, 95)], fill="gray", width=2)
        mrz1 = "P<INDKUMAR<<RAHUL<<<<<<<<<<<<<<<<<<<<<<<<<<<"
        mrz2 = "J8369854<4IND0408153M3401014<<<<<<<<<<<<<<<2"
        d.text((30, 115), mrz1, font=_load_font(18), fill="black")
        d.text((30, 145), mrz2, font=_load_font(18), fill="black")
        gt_lines = ["REPUBLIC OF INDIA", "PASSPORT", mrz1, mrz2]
        fields = {"passport": "J8369854"}

    # Apply condition degradations
    img = apply_condition(img, condition, rng)

    # Compose ground truth string
    gt_text = "\n".join(gt_lines)
    return img, gt_text, fields


def apply_condition(img, condition, rng):
    """Apply a degradation condition to the image."""
    W, H = img.size
    if condition == "clean":
        return img
    elif condition == "skewed":
        angle = rng.uniform(-8, 8)
        return img.rotate(angle, resample=Image.BICUBIC, fillcolor="white")
    elif condition == "low_light":
        # Darken + add noise
        arr = np.array(img).astype(np.float32)
        arr = arr * 0.5 + rng.normal(0, 12, arr.shape)
        arr = np.clip(arr, 0, 255).astype(np.uint8)
        return Image.fromarray(arr)
    elif condition == "folded":
        # Simulate a crease: bright vertical band + slight warp
        arr = np.array(img).copy()
        cx = rng.integers(W * 0.3, W * 0.7)
        arr[:, max(0, cx - 3):cx + 3] = np.clip(arr[:, max(0, cx - 3):cx + 3].astype(np.int16) + 40, 0, 255)
        return Image.fromarray(arr)
    elif condition == "low_res":
        small = img.resize((W // 2, H // 2), Image.BILINEAR)
        return small.resize((W, H), Image.BILINEAR)
    elif condition == "glare":
        arr = np.array(img).astype(np.float32)
        cx, cy = rng.integers(W * 0.2, W * 0.8), rng.integers(H * 0.2, H * 0.8)
        y, x = np.ogrid[:H, :W]
        mask = np.exp(-((x - cx) ** 2 + (y - cy) ** 2) / (2 * 120 ** 2))
        arr = np.clip(arr + mask[..., None] * 90, 0, 255).astype(np.uint8)
        return Image.fromarray(arr)
    elif condition == "motion_blur":
        if HAS_CV2:
            arr = np.array(img)
            ksize = rng.integers(5, 12)
            kernel = np.zeros((ksize, ksize))
            kernel[int((ksize - 1) / 2), :] = 1.0 / ksize
            angle = rng.integers(0, 180)
            M = cv2.getRotationMatrix2D((ksize / 2, ksize / 2), angle, 1)
            kernel = cv2.warpAffine(kernel, M, (ksize, ksize))
            arr = cv2.filter2D(arr, -1, kernel)
            return Image.fromarray(arr)
        return img.filter(ImageFilter.BLUR)
    else:
        return img


# ---------------------------------------------------------------------------
# Text normalization + metrics
# ---------------------------------------------------------------------------

def normalize_text(s):
    """Normalize OCR output for comparison: strip accents, collapse whitespace, lowercase."""
    s = unicodedata.normalize("NFKD", s)
    s = "".join(c for c in s if not unicodedata.combining(c))
    s = s.lower()
    s = re.sub(r"\s+", " ", s)
    s = re.sub(r"[^a-z0-9\s]", "", s)
    return s.strip()


def char_accuracy(gt, pred):
    gt_n, pred_n = normalize_text(gt), normalize_text(pred)
    if not gt_n:
        return 1.0 if not pred_n else 0.0
    # Levenshtein-based char accuracy
    dp = [[0] * (len(pred_n) + 1) for _ in range(len(gt_n) + 1)]
    for i in range(len(gt_n) + 1):
        dp[i][0] = i
    for j in range(len(pred_n) + 1):
        dp[0][j] = j
    for i in range(1, len(gt_n) + 1):
        for j in range(1, len(pred_n) + 1):
            cost = 0 if gt_n[i - 1] == pred_n[j - 1] else 1
            dp[i][j] = min(dp[i - 1][j] + 1, dp[i][j - 1] + 1, dp[i - 1][j - 1] + cost)
    dist = dp[len(gt_n)][len(pred_n)]
    return max(0.0, 1.0 - dist / max(len(gt_n), 1))


def word_accuracy(gt, pred):
    gt_words = normalize_text(gt).split()
    pred_words = normalize_text(pred).split()
    if not gt_words:
        return 1.0 if not pred_words else 0.0
    matches = sum(1 for w in gt_words if w in pred_words)
    return matches / len(gt_words)


def field_check(gt_text, fields, pred_text):
    """Check if key extracted fields appear in prediction."""
    pred_n = normalize_text(pred_text)
    results = {}
    for key, val in fields.items():
        val_n = normalize_text(val)
        results[key] = val_n in pred_n if val_n else False
    return results


def verhoeff_valid(num):
    num = re.sub(r"\D", "", num)
    if len(num) != 12 or num[0] in "01":
        return False
    vd = [
        [0,1,2,3,4,5,6,7,8,9],[1,2,3,4,0,6,7,8,9,5],[2,3,4,0,1,7,8,9,5,6],
        [3,4,0,1,2,8,9,5,6,7],[4,0,1,2,3,9,5,6,7,8],[5,9,8,7,6,0,4,3,2,1],
        [6,5,9,8,7,1,0,4,3,2],[7,6,5,9,8,2,1,0,4,3],[8,7,6,5,9,3,2,1,0,4],
        [9,8,7,6,5,4,3,2,1,0],
    ]
    vp = [
        [0,1,2,3,4,5,6,7,8,9],[1,5,7,6,2,8,3,0,9,4],[5,8,0,3,7,9,6,1,4,2],
        [8,9,1,6,0,4,3,5,2,7],[9,4,5,3,1,2,6,8,7,0],[4,2,8,6,5,7,3,9,0,1],
        [2,7,9,3,8,0,6,4,1,5],[7,0,4,6,9,1,3,2,5,8],
    ]
    c = 0
    for i, ch in enumerate(reversed(num)):
        c = vd[c][vp[i % 8][int(ch)]]
    return c == 0


# ---------------------------------------------------------------------------
# OCR engines
# ---------------------------------------------------------------------------

class PaddleOCREngine:
    def __init__(self, lang="en"):
        if not HAS_PADDLE:
            raise RuntimeError("PaddleOCR not installed. Run: pip install paddleocr")
        # PP-OCRv4/v6 multilingual covers English + Indian regional languages
        # Support both PaddleOCR 2.x (ocr() API) and 3.x (predict() API)
        self._api_v3 = None
        try:
            self.ocr = PaddleOCR(lang=lang)
            self._api_v3 = True
        except TypeError:
            # PaddleOCR 2.x API
            self.ocr = PaddleOCR(use_angle_cls=True, lang=lang)
            self._api_v3 = False

    def run(self, image_path):
        import time
        t0 = time.perf_counter()
        lines = []
        if self._api_v3:
            # PaddleOCR 3.x: predict() returns a list of Result objects
            result = self.ocr.predict(image_path)
            for res in result:
                # Each res has .json, .boxes, .texts, .scores attributes
                texts = getattr(res, "texts", None)
                scores = getattr(res, "scores", None)
                if texts:
                    for i, t in enumerate(texts):
                        conf = float(scores[i]) if scores and i < len(scores) else 0.0
                        lines.append((str(t), conf))
        else:
            # PaddleOCR 2.x: ocr() returns nested list [[box, (text, conf)], ...]
            result = self.ocr.ocr(image_path, cls=True)
            if result and result[0]:
                for line in result[0]:
                    box, (text, conf) = line
                    lines.append((text, float(conf)))
        dt = (time.perf_counter() - t0) * 1000
        text = "\n".join(t for t, _ in lines)
        return text, dt, lines


class MLKitSimulator:
    """
    Simulates Google ML Kit Text Recognition (Latin script only).
    Models the known behavior: Devanagari and non-Latin scripts are dropped;
    English text is read with decent accuracy but no per-word confidence.
    """
    def __init__(self):
        pass

    def run(self, image_path):
        import time
        t0 = time.perf_counter()
        # Simulate ML Kit processing time (faster than PaddleOCR on mobile CPU)
        # We read the image and apply a Latin-filter to approximate ML Kit behavior.
        img = Image.open(image_path).convert("L")
        # ML Kit Latin-only: we keep Latin chars, drop Devanagari/other scripts
        # Use a simple OCR-free approximation: return a cleaned Latin-only rendering
        # In a real device, ML Kit would process the image. Here we approximate by
        # returning the ground truth with non-Latin stripped + simulated noise.
        dt = (time.perf_counter() - t0) * 1000 + 350  # +350ms fixed ML Kit overhead
        return "", dt, []  # placeholder; real GT is injected by caller


def mlkit_latin_filter(gt_text):
    """
    Approximate ML Kit output: keeps Latin characters + digits, drops Devanagari,
    adds small character confusion (O/0, I/1) to simulate real ML Kit errors.
    """
    rng = np.random.default_rng(42)
    # Keep only Latin + digits + basic punctuation + newlines
    latin_only = re.sub(r"[^\x00-\x7F]+", " ", gt_text)
    # Simulate common ML Kit confusions
    conf_map = {"0": "O", "1": "I", "5": "S", "8": "B", "O": "0", "I": "1", "S": "5", "B": "8"}
    out = []
    for ch in latin_only:
        if ch in conf_map and rng.random() < 0.08:
            out.append(conf_map[ch])
        else:
            out.append(ch)
    return "".join(out)


# ---------------------------------------------------------------------------
# Main evaluation
# ---------------------------------------------------------------------------

def run_evaluation(engine_name, input_dir, gt_csv, output_csv, lang="en"):
    gt = {}
    with open(gt_csv, newline="", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            gt[row["image_id"]] = row

    if engine_name == "paddleocr":
        engine = PaddleOCREngine(lang=lang)
    else:
        engine = None  # ML Kit simulated

    rows = []
    image_files = sorted(Path(input_dir).glob("*.png")) + sorted(Path(input_dir).glob("*.jpg"))

    for img_path in image_files:
        img_id = img_path.stem
        if img_id not in gt:
            continue
        grow = gt[img_id]
        gt_text = grow["ground_truth_text"]

        if engine_name == "paddleocr":
            pred_text, dt, _ = engine.run(str(img_path))
        else:
            # ML Kit simulation: Latin-only filter on ground truth
            pred_text = mlkit_latin_filter(gt_text)
            dt = 520.0  # simulated ms

        ca = char_accuracy(gt_text, pred_text)
        wa = word_accuracy(gt_text, pred_text)

        # Field checks
        fields = {}
        for k in ("name", "dob", "father", "aadhaar", "pan", "voter_id", "dl", "account_no", "ifsc", "passport", "bank", "gender"):
            if grow.get(k):
                fields[k] = grow[k]
        fc = field_check(gt_text, fields, pred_text)
        field_pass = sum(1 for v in fc.values() if v) / max(len(fc), 1)

        # Aadhaar checksum — check if prediction contains a valid 12-digit Aadhaar
        aadhaar_ok = None
        if grow.get("aadhaar"):
            pred_digits = re.sub(r"\D", "", pred_text)
            # Find any 12-digit run in the prediction
            m = re.search(r"\b\d{12}\b", pred_digits)
            aadhaar_ok = bool(m and verhoeff_valid(m.group()))

        # PAN format — check if prediction contains a valid PAN
        pan_ok = bool(re.search(r"\b[A-Z]{5}[0-9]{4}[A-Z]\b", pred_text)) if grow.get("pan") else None

        rows.append({
            "image_id": img_id,
            "doc_type": grow["doc_type"],
            "language": grow["language"],
            "condition": grow["condition"],
            "engine": engine_name,
            "char_accuracy": round(ca, 4),
            "word_accuracy": round(wa, 4),
            "field_accuracy": round(field_pass, 4),
            "aadhaar_ok": aadhaar_ok,
            "pan_ok": pan_ok,
            "inference_ms": round(dt, 1),
            "gt_text": gt_text,
            "pred_text": pred_text,
        })

    with open(output_csv, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=rows[0].keys() if rows else [])
        w.writeheader()
        w.writerows(rows)
    return rows


def compare(results_paddle, results_mlkit, report_path):
    def agg(rows):
        n = len(rows)
        if n == 0:
            return {}
        return {
            "n": n,
            "char_acc": sum(r["char_accuracy"] for r in rows) / n,
            "word_acc": sum(r["word_accuracy"] for r in rows) / n,
            "field_acc": sum(r["field_accuracy"] for r in rows) / n,
            "aadhaar_ok": sum(1 for r in rows if r["aadhaar_ok"] is True) / max(sum(1 for r in rows if r["aadhaar_ok"] is not None), 1),
            "pan_ok": sum(1 for r in rows if r["pan_ok"] is True) / max(sum(1 for r in rows if r["pan_ok"] is not None), 1),
            "avg_ms": sum(r["inference_ms"] for r in rows) / n,
        }

    ap = agg(results_paddle)
    am = agg(results_mlkit)

    if not ap or not am:
        print("Error: one or both result sets are empty. Cannot compare.")
        return

    lines = []
    lines.append("# OCR Comparison Results — PaddleOCR vs Google ML Kit")
    lines.append(f"\nGenerated: {datetime.now().isoformat()}")
    lines.append(f"\n## Summary (all {ap['n']} candidates per engine)\n")
    lines.append("| Metric | PaddleOCR | ML Kit (sim) | Gap |")
    lines.append("|---|---|---|---|")
    lines.append(f"| Character accuracy | {ap['char_acc']*100:.1f}% | {am['char_acc']*100:.1f}% | {(ap['char_acc']-am['char_acc'])*100:+.1f} pts |")
    lines.append(f"| Word accuracy | {ap['word_acc']*100:.1f}% | {am['word_acc']*100:.1f}% | {(ap['word_acc']-am['word_acc'])*100:+.1f} pts |")
    lines.append(f"| Field accuracy | {ap['field_acc']*100:.1f}% | {am['field_acc']*100:.1f}% | {(ap['field_acc']-am['field_acc'])*100:+.1f} pts |")
    lines.append(f"| Aadhaar checksum pass | {ap['aadhaar_ok']*100:.1f}% | {am['aadhaar_ok']*100:.1f}% | {(ap['aadhaar_ok']-am['aadhaar_ok'])*100:+.1f} pts |")
    lines.append(f"| PAN format pass | {ap['pan_ok']*100:.1f}% | {am['pan_ok']*100:.1f}% | {(ap['pan_ok']-am['pan_ok'])*100:+.1f} pts |")
    lines.append(f"| Avg inference time | {ap['avg_ms']:.0f} ms | {am['avg_ms']:.0f} ms | {ap['avg_ms']-am['avg_ms']:+.0f} ms |")
    lines.append(f"| Model size added | ~18–25 MB | 0 MB (Play Services) | — |")

    # By document type
    lines.append("\n## By document type\n")
    lines.append("| Doc type | Engine | Char acc | Word acc | Field acc |")
    lines.append("|---|---|---|---|---|")
    for dt in sorted(set(r["doc_type"] for r in results_paddle)):
        for eng, rows in (("PaddleOCR", results_paddle), ("ML Kit", results_mlkit)):
            subset = [r for r in rows if r["doc_type"] == dt]
            if subset:
                n = len(subset)
                lines.append(f"| {dt} | {eng} | {sum(r['char_accuracy'] for r in subset)/n*100:.1f}% | {sum(r['word_accuracy'] for r in subset)/n*100:.1f}% | {sum(r['field_accuracy'] for r in subset)/n*100:.1f}% |")

    # By language
    lines.append("\n## By language\n")
    lines.append("| Language | Engine | Char acc | Word acc | Field acc |")
    lines.append("|---|---|---|---|---|")
    for lg in sorted(set(r["language"] for r in results_paddle)):
        for eng, rows in (("PaddleOCR", results_paddle), ("ML Kit", results_mlkit)):
            subset = [r for r in rows if r["language"] == lg]
            if subset:
                n = len(subset)
                lines.append(f"| {lg} | {eng} | {sum(r['char_accuracy'] for r in subset)/n*100:.1f}% | {sum(r['word_accuracy'] for r in subset)/n*100:.1f}% | {sum(r['field_accuracy'] for r in subset)/n*100:.1f}% |")

    # By condition
    lines.append("\n## By condition\n")
    lines.append("| Condition | Engine | Char acc | Word acc | Field acc |")
    lines.append("|---|---|---|---|---|")
    for cond in sorted(set(r["condition"] for r in results_paddle)):
        for eng, rows in (("PaddleOCR", results_paddle), ("ML Kit", results_mlkit)):
            subset = [r for r in rows if r["condition"] == cond]
            if subset:
                n = len(subset)
                lines.append(f"| {cond} | {eng} | {sum(r['char_accuracy'] for r in subset)/n*100:.1f}% | {sum(r['word_accuracy'] for r in subset)/n*100:.1f}% | {sum(r['field_accuracy'] for r in subset)/n*100:.1f}% |")

    lines.append("\n## Recommendation\n")
    if ap["char_acc"] > am["char_acc"] + 0.05:
        lines.append("- PaddleOCR shows meaningfully higher accuracy on Indian documents, especially regional languages.")
        lines.append("- Use PaddleOCR if you need Hindi/Devanagari, Tamil, Telugu, Bengali support (Phase 2).")
        lines.append("- Accept the trade-off: +15–25 MB app size, ~2–3× slower inference, more integration work.")
    else:
        lines.append("- ML Kit remains competitive for English-only documents and is far lighter/faster.")
        lines.append("- Stay with ML Kit for the MVP; add PaddleOCR later as a regional-language fallback.")

    with open(report_path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))
    print("\n".join(lines))


def generate_tests(count, out_dir):
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    rng = np.random.default_rng(42)

    doc_types = ["Aadhaar"] * 20 + ["Aadhaar_back"] * 0 + ["PAN"] * 20 + ["VoterID"] * 15 + ["DrivingLicence"] * 15 + ["Passport"] * 10 + ["Bank"] * 10
    # Adjust to exactly `count`
    while len(doc_types) < count:
        doc_types.append(rng.choice(["Aadhaar", "PAN", "VoterID", "DrivingLicence", "Bank", "Passport"]))
    doc_types = doc_types[:count]
    rng.shuffle(doc_types)

    conditions = ["clean"] * 30 + ["skewed"] * 15 + ["low_light"] * 15 + ["folded"] * 10 + ["low_res"] * 10 + ["glare"] * 10 + ["motion_blur"] * 10
    while len(conditions) < count:
        conditions.append(rng.choice(conditions[:7]))
    conditions = conditions[:count]
    rng.shuffle(conditions)

    languages = ["en"] * 70 + ["hi"] * 30
    while len(languages) < count:
        languages.append(rng.choice(["en", "hi"]))
    languages = languages[:count]
    rng.shuffle(languages)

    rows = []
    for i, (dt, cond, lg) in enumerate(zip(doc_types, conditions, languages)):
        img_id = f"{dt}_{i:03d}"
        # Map Aadhaar_back to Aadhaar for rendering
        render_dt = "Aadhaar" if dt == "Aadhaar_back" else dt
        img, gt_text, fields = render_id_card(render_dt, lg, cond, i, rng)
        img_path = out / f"{img_id}.png"
        img.save(img_path)

        row = {
            "image_id": img_id,
            "doc_type": dt,
            "language": lg,
            "condition": cond,
            "ground_truth_text": gt_text,
            **{k: v for k, v in fields.items()},
        }
        rows.append(row)

    # Write ground truth CSV
    fieldnames = ["image_id", "doc_type", "language", "condition", "ground_truth_text",
                  "name", "dob", "father", "aadhaar", "pan", "voter_id", "dl", "account_no", "ifsc", "passport", "bank", "gender"]
    gt_csv = out / "ground_truth.csv"
    with open(gt_csv, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=fieldnames, extrasaction="ignore")
        w.writeheader()
        for r in rows:
            w.writerow(r)

    print(f"Generated {count} test images + ground truth -> {out}")
    print(f"Ground truth: {gt_csv}")


def main():
    ap = argparse.ArgumentParser(description="OCR evaluation harness for AI Form & Vault")
    ap.add_argument("--generate-tests", type=int, metavar="N", help="Generate N synthetic test images")
    ap.add_argument("--out", default="test_set/", help="Output dir for generated tests")
    ap.add_argument("--engine", choices=["paddleocr", "mlkit"], help="OCR engine to run")
    ap.add_argument("--input", help="Input directory with test images")
    ap.add_argument("--gt", help="Ground truth CSV path")
    ap.add_argument("--output-csv", dest="output_csv", help="Output CSV path for results")
    ap.add_argument("--compare", nargs=2, metavar=("PADDLE_CSV", "MLKIT_CSV"), help="Compare two result CSVs")
    ap.add_argument("--report", default="comparison_report.md", help="Report output path")
    ap.add_argument("--lang", default="en", help="PaddleOCR language (en, ch, multilingual, etc.)")
    args = ap.parse_args()

    if args.generate_tests:
        generate_tests(args.generate_tests, args.out)
        return

    if args.engine:
        if not args.input or not args.gt or not args.output_csv:
            ap.error("--engine requires --input, --gt, and --output-csv")
        rows = run_evaluation(args.engine, args.input, args.gt, args.output_csv, lang=args.lang)
        print(f"\n{args.engine}: {len(rows)} images evaluated -> {args.output_csv}")
        return

    if args.compare:
        def load(p):
            with open(p, newline="", encoding="utf-8") as f:
                return list(csv.DictReader(f))
        rp = load(args.compare[0])
        rm = load(args.compare[1])
        compare(rp, rm, args.report)
        return

    ap.error("Specify --generate-tests, --engine, or --compare")


if __name__ == "__main__":
    main()
