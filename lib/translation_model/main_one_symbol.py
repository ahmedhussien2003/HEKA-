from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pathlib import Path
import zipfile
import xml.etree.ElementTree as ET
from io import BytesIO
from time import perf_counter

from PIL import Image

import model_classification

# Classification model is lazy-loaded by model_classification.predict()


app = FastAPI()

# Allow browser / Flutter Web access
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # tighten in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# =============================
# Hieroglyphic lookup (XLSX, no external deps)
# =============================
_XLSX_PATH = Path(__file__).with_name("Hieroglyphic.xlsx")
_XLSX_NS = {"s": "http://schemas.openxmlformats.org/spreadsheetml/2006/main"}

def _col_to_index(col_letters: str) -> int:
    idx = 0
    for ch in col_letters:
        idx = idx * 26 + (ord(ch.upper()) - 64)
    return idx - 1

def _read_shared_strings(zip_file: zipfile.ZipFile) -> list[str]:
    if "xl/sharedStrings.xml" not in zip_file.namelist():
        return []
    root = ET.fromstring(zip_file.read("xl/sharedStrings.xml"))
    shared = []
    for si in root.findall("s:si", _XLSX_NS):
        texts = [t.text or "" for t in si.findall(".//s:t", _XLSX_NS)]
        shared.append("".join(texts))
    return shared

def _read_sheet_rows(zip_file: zipfile.ZipFile, shared: list[str]) -> list[list[str | None]]:
    root = ET.fromstring(zip_file.read("xl/worksheets/sheet1.xml"))
    rows: list[list[str | None]] = []
    for row in root.findall("s:sheetData/s:row", _XLSX_NS):
        row_map: dict[int, str | None] = {}
        max_col = -1
        for c in row.findall("s:c", _XLSX_NS):
            ref = c.get("r") or ""
            col_letters = "".join(ch for ch in ref if ch.isalpha())
            col_index = _col_to_index(col_letters) if col_letters else None
            v = c.find("s:v", _XLSX_NS)
            if v is None or col_index is None:
                continue
            value: str | None = v.text
            if c.get("t") == "s":
                try:
                    value = shared[int(value)]
                except Exception:
                    pass
            row_map[col_index] = value
            if col_index > max_col:
                max_col = col_index
        if max_col >= 0:
            rows.append([row_map.get(i) for i in range(max_col + 1)])
    return rows

def _normalize_key(value: str) -> str:
    return "".join(str(value).split()).lower()

def _load_hieroglyphs(xlsx_path: Path) -> dict[str, dict[str, str | None]]:
    if not xlsx_path.exists():
        return {}
    with zipfile.ZipFile(xlsx_path) as zf:
        shared = _read_shared_strings(zf)
        rows = _read_sheet_rows(zf, shared)
    if not rows:
        return {}
    header = rows[0]
    try:
        idx_gardiner = header.index("Gardiner")
        idx_mean_en = header.index("Meaning (English)")
        idx_mean_ar = header.index("Meaning (Arabic)")
    except ValueError:
        return {}
    data: dict[str, dict[str, str | None]] = {}
    for row in rows[1:]:
        if idx_gardiner >= len(row):
            continue
        gardiner = row[idx_gardiner]
        if not gardiner:
            continue
        key = _normalize_key(gardiner)
        data[key] = {
            "gardiner": str(gardiner).strip(),
            "meaning_english": row[idx_mean_en] if idx_mean_en < len(row) else None,
            "meaning_arabic": row[idx_mean_ar] if idx_mean_ar < len(row) else None,
        }
    return data

_HIEROGLYPHS = _load_hieroglyphs(_XLSX_PATH)

# =============================
# API Endpoint
# =============================
def _read_upload_as_pil(file_bytes: bytes) -> Image.Image:
    if not file_bytes:
        raise HTTPException(status_code=400, detail="Empty image file")
    try:
        return Image.open(BytesIO(file_bytes))
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid image file")


from deep_translator import GoogleTranslator

@app.post("/predict")
def predict_image(file: UploadFile = File(...), target_lang: str = "en"):
    request_started = perf_counter()
    try:
        contents = file.file.read()
        pil_image = _read_upload_as_pil(contents)

        # Model prediction (handled by model_classification.py)
        result = model_classification.predict(pil_image)
        class_str = result["gardiner_code"]
        class_id = result["idx"]
        confidence = result["confidence"]

        # Lookup Excel info
        lookup_key = _normalize_key(class_str)
        info = _HIEROGLYPHS.get(lookup_key, {})

        meaning_en = info.get("meaning_english") or ""
        meaning_ar = info.get("meaning_arabic") or ""

        # Translate to target_lang if it's not English or Arabic
        target_lang_result = ""
        if target_lang not in ["en", "ar"] and meaning_en:
            try:
                target_lang_result = GoogleTranslator(source="en", target=target_lang).translate(meaning_en)
            except Exception as translate_err:
                print(f"{target_lang} translation failed: {translate_err}")
                target_lang_result = ""

        # Translate to all other supported languages
        SUPPORTED_LANGS = {
            "italian": "it",
            "german": "de",
            "spanish": "es",
            "russian": "ru",
            "polish": "pl"
        }
        translations = {}
        if meaning_en:
            from concurrent.futures import ThreadPoolExecutor
            def translate_lang(lang_name, lang_code):
                try:
                    translated = GoogleTranslator(source="en", target=lang_code).translate(meaning_en)
                    return lang_name, translated
                except Exception as translate_err:
                    print(f"{lang_name} translation failed: {translate_err}")
                    return lang_name, ""
            
            with ThreadPoolExecutor() as executor:
                results = executor.map(lambda item: translate_lang(item[0], item[1]), list(SUPPORTED_LANGS.items()))
                for lang_name, val in results:
                    translations[lang_name] = val
        else:
            for lang_name in SUPPORTED_LANGS:
                translations[lang_name] = ""

        return {
            "class_id": class_id,
            "class_name": class_str,
            "confidence": f"{confidence*100:.2f}%",
            "gardiner": info.get("gardiner") or class_str,
            "meaning_english": meaning_en,
            "meaning_arabic": meaning_ar,
            "meaning_italian": translations.get("italian", ""),
            "meaning_german": translations.get("german", ""),
            "meaning_spanish": translations.get("spanish", ""),
            "meaning_russian": translations.get("russian", ""),
            "meaning_polish": translations.get("polish", ""),
            "Target_Language_Result": target_lang_result,
            "server_execution_time_ms": round((perf_counter() - request_started) * 1000, 2),
        }

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
