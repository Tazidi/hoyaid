"""Build the Firestore species seed from the verified Hoya workbook.

The script intentionally uses only Python's standard library. It reads the
``Data_Aplikasi`` worksheet in an XLSX file, updates the content fields in the
existing seed, and retains app-specific metadata such as reference images and
model labels already present in that seed.
"""

from __future__ import annotations

import argparse
import json
import posixpath
import re
import sys
import zipfile
from pathlib import Path
from typing import Any
from xml.etree import ElementTree as ET


MAIN_NS = "http://schemas.openxmlformats.org/spreadsheetml/2006/main"
REL_NS = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
PKG_REL_NS = "http://schemas.openxmlformats.org/package/2006/relationships"
NS = {"main": MAIN_NS, "rel": REL_NS, "pkgrel": PKG_REL_NS}

SCRIPT_DIR = Path(__file__).resolve().parent
MOBILE_DIR = SCRIPT_DIR.parent.parent
DEFAULT_SOURCE = MOBILE_DIR / "data_spesies_hoya_dengan_sumber_terverifikasi.xlsx"
DEFAULT_SEED = SCRIPT_DIR / "species_seed.json"
SHEET_NAME = "Data_Aplikasi"


def clean_text(value: Any) -> str:
    """Normalise whitespace and repair the replacement character in status text."""
    if value is None:
        return ""
    text = str(value).replace("\xa0", " ").replace("�", " — ")
    return re.sub(r"[ \t]+", " ", text).strip()


def column_index(cell_reference: str) -> int:
    """Return a zero-based column index from an Excel reference such as C12."""
    letters = re.match(r"[A-Z]+", cell_reference)
    if not letters:
        raise ValueError(f"Invalid Excel cell reference: {cell_reference!r}")
    value = 0
    for char in letters.group(0):
        value = value * 26 + ord(char) - ord("A") + 1
    return value - 1


def shared_strings(archive: zipfile.ZipFile) -> list[str]:
    try:
        root = ET.fromstring(archive.read("xl/sharedStrings.xml"))
    except KeyError:
        return []
    return ["".join(item.itertext()) for item in root.findall("main:si", NS)]


def worksheet_path(archive: zipfile.ZipFile, sheet_name: str) -> str:
    workbook = ET.fromstring(archive.read("xl/workbook.xml"))
    relationships = ET.fromstring(archive.read("xl/_rels/workbook.xml.rels"))
    targets = {
        relationship.attrib["Id"]: relationship.attrib["Target"]
        for relationship in relationships.findall("pkgrel:Relationship", NS)
    }

    for sheet in workbook.findall("main:sheets/main:sheet", NS):
        if sheet.attrib.get("name") != sheet_name:
            continue
        relationship_id = sheet.attrib.get(f"{{{REL_NS}}}id")
        if not relationship_id or relationship_id not in targets:
            break
        target = targets[relationship_id].lstrip("/")
        if target.startswith("xl/"):
            return posixpath.normpath(target)
        return posixpath.normpath(posixpath.join("xl", target))

    raise ValueError(f"Worksheet {sheet_name!r} was not found in the workbook.")


def cell_value(cell: ET.Element, strings: list[str]) -> str:
    cell_type = cell.attrib.get("t")
    if cell_type == "inlineStr":
        return "".join(cell.itertext())

    value = cell.findtext("main:v", default="", namespaces=NS)
    if cell_type == "s" and value:
        return strings[int(value)]
    if cell_type == "b":
        return "true" if value == "1" else "false"
    return value


def read_rows(source: Path) -> list[list[str]]:
    with zipfile.ZipFile(source) as archive:
        strings = shared_strings(archive)
        root = ET.fromstring(archive.read(worksheet_path(archive, SHEET_NAME)))

    rows: list[list[str]] = []
    for row in root.findall("main:sheetData/main:row", NS):
        values: dict[int, str] = {}
        for cell in row.findall("main:c", NS):
            reference = cell.attrib.get("r")
            if reference:
                values[column_index(reference)] = cell_value(cell, strings)
        if values:
            rows.append([values.get(index, "") for index in range(max(values) + 1)])
    return rows


def application_rows(source: Path) -> list[dict[str, str]]:
    rows = read_rows(source)
    header_index = next(
        (
            index
            for index, row in enumerate(rows)
            if "Label aplikasi" in row
        ),
        None,
    )
    if header_index is None:
        raise ValueError("Header 'Label aplikasi' tidak ditemukan pada Data_Aplikasi.")

    headers = [clean_text(value) for value in rows[header_index]]
    records: list[dict[str, str]] = []
    for row in rows[header_index + 1 :]:
        record = {
            header: clean_text(row[index]) if index < len(row) else ""
            for index, header in enumerate(headers)
            if header
        }
        if record.get("Label aplikasi"):
            records.append(record)
    return records


def split_urls(value: str) -> list[str]:
    return [url for url in re.split(r"\s+", value) if url.startswith(("https://", "http://"))]


def confirmed_medical_use(status: str) -> bool:
    """Only statuses explicitly marked 'Ya' become a medical-use claim in the UI."""
    return clean_text(status).lower().startswith("ya")


def build_medical_text(record: dict[str, str], has_medical_use: bool) -> str:
    if not has_medical_use:
        return "-"

    description = record.get("Deskripsi medis untuk aplikasi", "")
    warning = record.get("Peringatan keamanan", "")
    if warning:
        return f"{description}\n\nPeringatan keamanan: {warning}".strip()
    return description or "-"


def add_verified_fields(item: dict[str, Any], record: dict[str, str]) -> None:
    """Store all medical/source context, even when it is not a confirmed use."""
    mappings = {
        "taxonomicStatus": "Status taksonomi",
        "medicalStatus": "Status manfaat medis",
        "medicalTraditionalUse": "Cara penggunaan tradisional",
        "medicalScientificExplanation": "Penjelasan ilmiah / kandungan",
        "medicalEvidenceLevel": "Tingkat bukti",
        "medicalSafetyWarning": "Peringatan keamanan",
        "verifiedDistributionDetail": "Detail Indonesia / lokasi spesifik",
        "taxonomicDistributionSourceCodes": "Kode sumber taksonomi/persebaran",
        "medicalSourceCodes": "Kode sumber medis",
        "sourceTraceability": "Status keterlacakan sumber",
    }
    for field, column in mappings.items():
        item[field] = record.get(column, "") or None
    item["sourceUrls"] = split_urls(record.get("Sumber URL", ""))


def update_seed(source: Path, seed_path: Path) -> tuple[dict[str, Any], dict[str, int]]:
    if not source.is_file():
        raise FileNotFoundError(f"Workbook tidak ditemukan: {source}")
    if not seed_path.is_file():
        raise FileNotFoundError(
            f"Seed dasar tidak ditemukan: {seed_path}. Seed dasar diperlukan untuk menjaga metadata gambar."
        )

    with seed_path.open(encoding="utf-8") as file:
        seed = json.load(file)
    if not isinstance(seed.get("items"), list):
        raise ValueError("Field 'items' pada seed harus berupa array.")

    records = application_rows(source)
    by_species_id = {record["Label aplikasi"]: record for record in records}
    source_ids = set(by_species_id)
    seed_ids = {item.get("speciesId") for item in seed["items"]}

    if len(records) != len(source_ids):
        raise ValueError("Ditemukan Label aplikasi duplikat pada workbook.")
    if missing := seed_ids - source_ids:
        raise ValueError(f"Workbook tidak memiliki label seed: {', '.join(sorted(missing))}")
    if extra := source_ids - seed_ids:
        raise ValueError(f"Workbook memiliki label yang belum ada di seed: {', '.join(sorted(extra))}")

    confirmed = 0
    potential = 0
    for item in seed["items"]:
        record = by_species_id[item["speciesId"]]
        status = record.get("Status manfaat medis", "")
        has_medical_use = confirmed_medical_use(status)
        medical_text = build_medical_text(record, has_medical_use)

        item["description"] = record.get("Deskripsi umum non-medis untuk aplikasi", "") or "-"
        item["distribution"] = record.get("Persebaran alami terverifikasi", "") or "-"
        item["hasMedicalUse"] = has_medical_use
        item["medicalUse"] = medical_text
        item["medicalUseDescription"] = medical_text
        item["updatedBy"] = "verified_xlsx_seed"
        add_verified_fields(item, record)

        if has_medical_use:
            confirmed += 1
        elif status and not status.lower().startswith("belum"):
            potential += 1

    return seed, {"items": len(records), "confirmed": confirmed, "potential": potential}


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Perbarui species_seed.json dari worksheet Data_Aplikasi."
    )
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE)
    parser.add_argument("--seed", type=Path, default=DEFAULT_SEED)
    parser.add_argument(
        "--output",
        type=Path,
        help="Lokasi hasil. Default: timpa file pada --seed setelah seluruh validasi lolos.",
    )
    parser.add_argument("--dry-run", action="store_true", help="Validasi tanpa menulis file.")
    args = parser.parse_args()

    seed, summary = update_seed(args.source.resolve(), args.seed.resolve())
    target = (args.output or args.seed).resolve()
    if not args.dry_run:
        with target.open("w", encoding="utf-8", newline="\n") as file:
            json.dump(seed, file, ensure_ascii=False, indent=2)
            file.write("\n")

    action = "Tervalidasi" if args.dry_run else f"Ditulis ke {target}"
    print(f"{action}: {summary['items']} spesies.")
    print(f"- Pemanfaatan medis eksplisit: {summary['confirmed']}")
    print(f"- Catatan potensial/tidak langsung tersimpan: {summary['potential']}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (FileNotFoundError, ValueError, zipfile.BadZipFile, json.JSONDecodeError) as error:
        print(f"Gagal membuat seed: {error}", file=sys.stderr)
        raise SystemExit(1)
