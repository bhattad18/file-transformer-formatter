#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import json
import shutil
import sys
import xml.etree.ElementTree as ET
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from pii_sanitizer.core.pipeline import SanitizationPipeline


SYNTHETIC_VALUES = {
    "name": "Ali Al Saud",
    "email": "ali.saud@example.com",
    "saudi_id": "1234567890",
    "iqama": "2345678901",
    "gcc_phone": "+966 55 123 4567",
    "iban": "SA0380000000608010167519",
    "passport": "A1234567",
    "manager": "Noura Al Saud",
    "mgr": "Ahmed Al Fahad",
    "director": "Mariam Al Sultan",
    "supervisor": "Khalid Al Saud",
    "url": "https://survey.example.com/respondent/abc123",
    "dob": "1988-04-23",
    "address": "Villa 22 King Fahd Road",
    "account_number": "123456789012",
    "secret": "api_key=abc123456789SECRET",
}


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate synthetic files and verify offline PII sanitization.")
    parser.add_argument("--work-dir", type=Path, default=ROOT / "verification_artifacts", help="Directory for generated fixtures and reports.")
    args = parser.parse_args()

    work_dir = args.work_dir
    input_dir = work_dir / "inputs"
    output_dir = work_dir / "Sanitized_Output"
    log_dir = work_dir / "logs"
    report_path = work_dir / "Verification_Report.md"

    if work_dir.exists():
        shutil.rmtree(work_dir)
    input_dir.mkdir(parents=True)
    output_dir.mkdir()
    log_dir.mkdir()

    fixtures = [
        create_csv(input_dir / "synthetic_customers.csv"),
        create_xlsx(input_dir / "synthetic_customers.xlsx"),
        create_pptx(input_dir / "synthetic_customers.pptx"),
    ]

    pipeline = SanitizationPipeline()
    report, log_path = pipeline.sanitize_paths(
        fixtures,
        output_dir,
        log_dir,
        preserve_names=True,
        progress=lambda index, total, path: print(f"[{index}/{total}] Verifying {path.name}", file=sys.stderr),
    )

    verification = build_verification(fixtures, output_dir, report.to_json_dict(), log_path)
    report_path.write_text(verification, encoding="utf-8")

    print(f"Verification report: {report_path}")
    print(f"Audit log: {log_path}")
    return 0 if not report.errors else 1


def create_csv(path: Path) -> Path:
    rows = [
        ["customer", "email", "رقم_الهوية", "رقم_الإقامة", "رقم_الجوال", "iban", "passport", "manager_name", "mgr_name", "director", "supervisor", "survey_url", "dob", "address", "account_number", "api_key", "notes"],
        [
            SYNTHETIC_VALUES["name"],
            SYNTHETIC_VALUES["email"],
            SYNTHETIC_VALUES["saudi_id"],
            SYNTHETIC_VALUES["iqama"],
            SYNTHETIC_VALUES["gcc_phone"],
            SYNTHETIC_VALUES["iban"],
            SYNTHETIC_VALUES["passport"],
            SYNTHETIC_VALUES["manager"],
            SYNTHETIC_VALUES["mgr"],
            SYNTHETIC_VALUES["director"],
            SYNTHETIC_VALUES["supervisor"],
            SYNTHETIC_VALUES["url"],
            SYNTHETIC_VALUES["dob"],
            SYNTHETIC_VALUES["address"],
            SYNTHETIC_VALUES["account_number"],
            SYNTHETIC_VALUES["secret"],
            "Benign project code ALPHA-42 should remain readable.",
        ],
    ]
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle)
        writer.writerows(rows)
    return path


def create_xlsx(path: Path) -> Path:
    values = [
        "customer",
        "email",
        "رقم_الهوية",
        "رقم_الإقامة",
        "رقم_الجوال",
        "iban",
        "passport",
        "manager_name",
        "mgr_name",
        "director",
        "supervisor",
        "survey_url",
        "dob",
        "address",
        "account_number",
        "api_key",
        "notes",
        SYNTHETIC_VALUES["name"],
        SYNTHETIC_VALUES["email"],
        SYNTHETIC_VALUES["saudi_id"],
        SYNTHETIC_VALUES["iqama"],
        SYNTHETIC_VALUES["gcc_phone"],
        SYNTHETIC_VALUES["iban"],
        SYNTHETIC_VALUES["passport"],
        SYNTHETIC_VALUES["manager"],
        SYNTHETIC_VALUES["mgr"],
        SYNTHETIC_VALUES["director"],
        SYNTHETIC_VALUES["supervisor"],
        SYNTHETIC_VALUES["url"],
        SYNTHETIC_VALUES["dob"],
        SYNTHETIC_VALUES["address"],
        SYNTHETIC_VALUES["account_number"],
        SYNTHETIC_VALUES["secret"],
        "Benign invoice total 1500 SAR.",
    ]
    shared_strings = "\n".join(
        f'<si><t>{escape_xml(value)}</t></si>' for value in values
    )
    cells = []
    for index in range(17):
        cells.append(f'<c r="{chr(65 + index)}1" t="s"><v>{index}</v></c>')
    for index in range(17, 34):
        cells.append(f'<c r="{chr(65 + index - 17)}2" t="s"><v>{index}</v></c>')

    with ZipFile(path, "w", ZIP_DEFLATED) as archive:
        archive.writestr("[Content_Types].xml", CONTENT_TYPES_XLSX)
        archive.writestr("_rels/.rels", RELS_XLSX)
        archive.writestr("xl/workbook.xml", WORKBOOK_XML)
        archive.writestr("xl/_rels/workbook.xml.rels", WORKBOOK_RELS_XML)
        archive.writestr("xl/sharedStrings.xml", f'<?xml version="1.0" encoding="UTF-8"?><sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" count="{len(values)}" uniqueCount="{len(values)}">{shared_strings}</sst>')
        archive.writestr("xl/worksheets/sheet1.xml", f'<?xml version="1.0" encoding="UTF-8"?><worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData><row r="1">{"".join(cells[:17])}</row><row r="2">{"".join(cells[17:])}</row></sheetData></worksheet>')
    return path


def create_pptx(path: Path) -> Path:
    text_runs = [
        "Saudi/GCC Synthetic PII Test",
        SYNTHETIC_VALUES["name"],
        SYNTHETIC_VALUES["email"],
        SYNTHETIC_VALUES["saudi_id"],
        SYNTHETIC_VALUES["iqama"],
        SYNTHETIC_VALUES["gcc_phone"],
        SYNTHETIC_VALUES["iban"],
        SYNTHETIC_VALUES["passport"],
        SYNTHETIC_VALUES["manager"],
        SYNTHETIC_VALUES["mgr"],
        SYNTHETIC_VALUES["director"],
        SYNTHETIC_VALUES["supervisor"],
        SYNTHETIC_VALUES["url"],
        SYNTHETIC_VALUES["dob"],
        SYNTHETIC_VALUES["address"],
        SYNTHETIC_VALUES["account_number"],
        SYNTHETIC_VALUES["secret"],
        "Benign slide text should remain.",
    ]
    runs_xml = "".join(f"<a:p><a:r><a:t>{escape_xml(value)}</a:t></a:r></a:p>" for value in text_runs)
    slide_xml = f"""<?xml version="1.0" encoding="UTF-8"?>
<p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
  <p:cSld><p:spTree><p:sp><p:txBody>{runs_xml}</p:txBody></p:sp></p:spTree></p:cSld>
</p:sld>"""

    with ZipFile(path, "w", ZIP_DEFLATED) as archive:
        archive.writestr("[Content_Types].xml", CONTENT_TYPES_PPTX)
        archive.writestr("_rels/.rels", RELS_PPTX)
        archive.writestr("ppt/presentation.xml", PRESENTATION_XML)
        archive.writestr("ppt/_rels/presentation.xml.rels", PRESENTATION_RELS_XML)
        archive.writestr("ppt/slides/slide1.xml", slide_xml)
    return path


def build_verification(fixtures: list[Path], output_dir: Path, audit: dict[str, object], log_path: Path) -> str:
    lines = [
        "# Verification Report",
        "",
        f"Audit log: `{log_path}`",
        "",
        "## Sanitization Summary",
        "",
        "```json",
        json.dumps(audit["summary"], indent=2, sort_keys=True),
        "```",
        "",
        "## Synthetic PII Checks",
        "",
        "| File | Synthetic value | Present before | Present after | Result |",
        "| --- | --- | --- | --- | --- |",
    ]

    for fixture in fixtures:
        before_text = extract_text(fixture)
        after_text = extract_text(output_dir / fixture.name)
        for label, value in SYNTHETIC_VALUES.items():
            present_before = value in before_text
            present_after = value in after_text
            result = "PASS" if present_before and not present_after else "FAIL"
            lines.append(f"| {fixture.name} | {label} | {present_before} | {present_after} | {result} |")

    lines.extend(
        [
            "",
            "## Files",
            "",
        ]
    )
    for item in audit.get("files", []):
        lines.append(f"- `{item['input_path']}` -> `{item.get('output_path')}`: {item['status']}")
    lines.append("")
    return "\n".join(lines)


def extract_text(path: Path) -> str:
    if path.suffix.lower() == ".csv":
        return path.read_text(encoding="utf-8")
    if path.suffix.lower() in {".xlsx", ".pptx"}:
        chunks: list[str] = []
        with ZipFile(path, "r") as archive:
            for name in archive.namelist():
                if not name.endswith(".xml"):
                    continue
                try:
                    root = ET.fromstring(archive.read(name))
                except ET.ParseError:
                    continue
                chunks.extend(element.text or "" for element in root.iter() if element.text)
        return "\n".join(chunks)
    return ""


def escape_xml(value: str) -> str:
    return value.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


CONTENT_TYPES_XLSX = """<?xml version="1.0" encoding="UTF-8"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
  <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
  <Override PartName="/xl/sharedStrings.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml"/>
</Types>"""

RELS_XLSX = """<?xml version="1.0" encoding="UTF-8"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
</Relationships>"""

WORKBOOK_XML = """<?xml version="1.0" encoding="UTF-8"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <sheets><sheet name="Customers" sheetId="1" r:id="rId1"/></sheets>
</workbook>"""

WORKBOOK_RELS_XML = """<?xml version="1.0" encoding="UTF-8"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/sharedStrings" Target="sharedStrings.xml"/>
</Relationships>"""

CONTENT_TYPES_PPTX = """<?xml version="1.0" encoding="UTF-8"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>
  <Override PartName="/ppt/slides/slide1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>
</Types>"""

RELS_PPTX = """<?xml version="1.0" encoding="UTF-8"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/>
</Relationships>"""

PRESENTATION_XML = """<?xml version="1.0" encoding="UTF-8"?>
<p:presentation xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <p:sldIdLst><p:sldId id="256" r:id="rId1"/></p:sldIdLst>
</p:presentation>"""

PRESENTATION_RELS_XML = """<?xml version="1.0" encoding="UTF-8"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide1.xml"/>
</Relationships>"""


if __name__ == "__main__":
    raise SystemExit(main())
