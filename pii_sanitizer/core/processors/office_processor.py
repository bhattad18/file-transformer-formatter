from __future__ import annotations

import shutil
import tempfile
import xml.etree.ElementTree as ET
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile

from pii_sanitizer.core.detectors import HeaderDetector, RegexDetector
from pii_sanitizer.core.models import DetectionResult, FileScanSummary, SanitizedSpan
from pii_sanitizer.core.sanitizers import Sanitizer


NAMESPACES = {
    "a": "http://schemas.openxmlformats.org/drawingml/2006/main",
    "m": "http://schemas.openxmlformats.org/officeDocument/2006/math",
    "s": "http://schemas.openxmlformats.org/spreadsheetml/2006/main",
}


class ExcelProcessor:
    extensions = {".xlsx"}

    def sanitize(
        self,
        input_path: Path,
        output_path: Path,
        header_detector: HeaderDetector,
        regex_detector: RegexDetector,
        sanitizer: Sanitizer,
        min_confidence: float,
    ) -> FileScanSummary:
        summary = FileScanSummary(input_path=str(input_path), output_path=str(output_path))
        shared_string_headers = _excel_shared_string_header_hints(input_path)
        _sanitize_zip_xml(
            input_path,
            output_path,
            summary,
            lambda name: name == "xl/sharedStrings.xml" or (name.startswith("xl/worksheets/") and name.endswith(".xml")),
            header_detector,
            regex_detector,
            sanitizer,
            min_confidence,
            shared_string_headers=shared_string_headers,
        )
        summary.status = "success"
        return summary


class PowerPointProcessor:
    extensions = {".pptx"}

    def sanitize(
        self,
        input_path: Path,
        output_path: Path,
        header_detector: HeaderDetector,
        regex_detector: RegexDetector,
        sanitizer: Sanitizer,
        min_confidence: float,
    ) -> FileScanSummary:
        summary = FileScanSummary(input_path=str(input_path), output_path=str(output_path))
        _sanitize_zip_xml(
            input_path,
            output_path,
            summary,
            lambda name: name.startswith("ppt/") and name.endswith(".xml"),
            header_detector,
            regex_detector,
            sanitizer,
            min_confidence,
        )
        summary.status = "success"
        return summary


def _sanitize_zip_xml(
    input_path: Path,
    output_path: Path,
    summary: FileScanSummary,
    should_sanitize: object,
    header_detector: HeaderDetector,
    regex_detector: RegexDetector,
    sanitizer: Sanitizer,
    min_confidence: float,
    shared_string_headers: dict[int, str] | None = None,
) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        temp_output = Path(tmp) / output_path.name
        with ZipFile(input_path, "r") as source, ZipFile(temp_output, "w", ZIP_DEFLATED) as target:
            for item in source.infolist():
                data = source.read(item.filename)
                if callable(should_sanitize) and should_sanitize(item.filename):
                    data = _sanitize_xml_bytes(
                        data,
                        item.filename,
                        summary,
                        header_detector,
                        regex_detector,
                        sanitizer,
                        min_confidence,
                        shared_string_headers or {},
                    )
                target.writestr(item, data)
        shutil.move(str(temp_output), output_path)


def _sanitize_xml_bytes(
    data: bytes,
    location_prefix: str,
    summary: FileScanSummary,
    header_detector: HeaderDetector,
    regex_detector: RegexDetector,
    sanitizer: Sanitizer,
    min_confidence: float,
    shared_string_headers: dict[int, str],
) -> bytes:
    try:
        root = ET.fromstring(data)
    except ET.ParseError:
        summary.warnings.append(f"Skipped unparsable XML part: {location_prefix}")
        return data

    changed = False
    text_index = 0
    for element in root.iter():
        if element.text and element.text.strip():
            text_index += 1
            location = f"{location_prefix}:text:{text_index}"
            header = shared_string_headers.get(text_index - 1) if location_prefix == "xl/sharedStrings.xml" else _nearby_header(element)
            detections = regex_detector.detect(element.text, header=header, location=location)
            detections.extend(header_detector.detect(element.text, header=header, location=location))
            detections = [item for item in detections if item.confidence >= min_confidence]
            sanitized, spans = sanitizer.sanitize_text(element.text, detections)
            if sanitized != element.text:
                element.text = sanitized
                changed = True
            _merge_spans(summary, spans)

    if not changed:
        return data
    ET.register_namespace("a", NAMESPACES["a"])
    ET.register_namespace("m", NAMESPACES["m"])
    ET.register_namespace("", NAMESPACES["s"])
    return ET.tostring(root, encoding="utf-8", xml_declaration=True)


def _nearby_header(element: ET.Element) -> str | None:
    return element.attrib.get("r")


def _excel_shared_string_header_hints(input_path: Path) -> dict[int, str]:
    try:
        with ZipFile(input_path, "r") as archive:
            shared_strings = _read_shared_strings(archive)
            hints: dict[int, str] = {}
            for name in archive.namelist():
                if name.startswith("xl/worksheets/") and name.endswith(".xml"):
                    hints.update(_worksheet_shared_string_hints(archive.read(name), shared_strings))
            return hints
    except Exception:
        return {}


def _read_shared_strings(archive: ZipFile) -> list[str]:
    try:
        root = ET.fromstring(archive.read("xl/sharedStrings.xml"))
    except Exception:
        return []
    values: list[str] = []
    for shared_item in root:
        chunks = [element.text or "" for element in shared_item.iter() if _local_name(element.tag) == "t"]
        values.append("".join(chunks))
    return values


def _worksheet_shared_string_hints(data: bytes, shared_strings: list[str]) -> dict[int, str]:
    try:
        root = ET.fromstring(data)
    except ET.ParseError:
        return {}

    rows = [element for element in root.iter() if _local_name(element.tag) == "row"]
    if not rows:
        return {}

    header_by_column: dict[str, str] = {}
    hints: dict[int, str] = {}
    for row_index, row in enumerate(rows):
        cells = [element for element in row if _local_name(element.tag) == "c"]
        if row_index == 0:
            for cell in cells:
                column = _cell_column(cell.attrib.get("r", ""))
                shared_index = _shared_string_index(cell)
                if column and shared_index is not None and shared_index < len(shared_strings):
                    header_by_column[column] = shared_strings[shared_index]
            continue

        for cell in cells:
            column = _cell_column(cell.attrib.get("r", ""))
            shared_index = _shared_string_index(cell)
            if column and shared_index is not None and column in header_by_column:
                hints[shared_index] = header_by_column[column]
    return hints


def _shared_string_index(cell: ET.Element) -> int | None:
    if cell.attrib.get("t") != "s":
        return None
    value = next((element.text for element in cell if _local_name(element.tag) == "v"), None)
    if value is None:
        return None
    try:
        return int(value)
    except ValueError:
        return None


def _cell_column(reference: str) -> str:
    return "".join(char for char in reference if char.isalpha())


def _local_name(tag: str) -> str:
    return tag.rsplit("}", 1)[-1]


def _merge_spans(summary: FileScanSummary, spans: list[SanitizedSpan]) -> None:
    summary.detected_spans.extend(spans)
    for span in spans:
        summary.detections_by_type[span.label] = summary.detections_by_type.get(span.label, 0) + 1
        summary.actions_by_strategy[span.strategy] = summary.actions_by_strategy.get(span.strategy, 0) + 1
