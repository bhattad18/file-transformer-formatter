from __future__ import annotations

import csv
from pathlib import Path

from pii_sanitizer.core.detectors import HeaderDetector, RegexDetector
from pii_sanitizer.core.models import DetectionResult, FileScanSummary, SanitizedSpan
from pii_sanitizer.core.sanitizers import Sanitizer


class CSVProcessor:
    extensions = {".csv"}

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
        with input_path.open("r", encoding="utf-8-sig", newline="") as source:
            sample = source.read(4096)
            source.seek(0)
            dialect = csv.Sniffer().sniff(sample) if sample.strip() else csv.excel
            reader = csv.reader(source, dialect)
            rows = list(reader)

        if not rows:
            summary.status = "success"
            summary.warnings.append("CSV is empty.")
            _write_csv(output_path, rows)
            return summary

        headers = rows[0]
        output_rows = [headers]
        for row_index, row in enumerate(rows[1:], start=2):
            output_row: list[str] = []
            for col_index, value in enumerate(row):
                header = headers[col_index] if col_index < len(headers) else ""
                location = f"row:{row_index}:col:{col_index + 1}"
                detections = _detect_value(value, header, location, header_detector, regex_detector, min_confidence)
                sanitized, spans = sanitizer.sanitize_text(value, detections)
                _merge_spans(summary, spans)
                output_row.append(sanitized)
            output_rows.append(output_row)

        _write_csv(output_path, output_rows)
        summary.status = "success"
        return summary


def _detect_value(
    value: str,
    header: str,
    location: str,
    header_detector: HeaderDetector,
    regex_detector: RegexDetector,
    min_confidence: float,
) -> list[DetectionResult]:
    detections = regex_detector.detect(value, header=header, location=location)
    if value.strip():
        detections.extend(header_detector.detect(value, header=header, location=location))
    return [item for item in detections if item.confidence >= min_confidence]


def _merge_spans(summary: FileScanSummary, spans: list[SanitizedSpan]) -> None:
    summary.detected_spans.extend(spans)
    for span in spans:
        summary.detections_by_type[span.label] = summary.detections_by_type.get(span.label, 0) + 1
        summary.actions_by_strategy[span.strategy] = summary.actions_by_strategy.get(span.strategy, 0) + 1


def _write_csv(output_path: Path, rows: list[list[str]]) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", encoding="utf-8", newline="") as target:
        writer = csv.writer(target)
        writer.writerows(rows)
