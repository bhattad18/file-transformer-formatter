from __future__ import annotations

import json
from pathlib import Path
from uuid import uuid4

from collections.abc import Callable

from pii_sanitizer.core.models import FileScanSummary, ProcessingReport, sanitized_output_path
from pii_sanitizer.core.processors import CSVProcessor, ExcelProcessor, PowerPointProcessor
from pii_sanitizer.core.registry import DEFAULT_RULES, build_detectors
from pii_sanitizer.core.sanitizers import Sanitizer


class SanitizationPipeline:
    def __init__(
        self,
        *,
        rules: list[dict[str, object]] | None = None,
        salt: str | None = None,
        min_confidence: float = 0.70,
        output_mode: str = "typed",
    ) -> None:
        self.rules = rules or DEFAULT_RULES
        self.header_detector, self.regex_detector = build_detectors(self.rules)
        self.sanitizer = Sanitizer(salt or str(uuid4()))
        self.min_confidence = min_confidence
        self.output_mode = output_mode
        self.processors = [CSVProcessor(), ExcelProcessor(), PowerPointProcessor()]

    def sanitize_paths(
        self,
        inputs: list[Path],
        output_dir: Path | None,
        log_dir: Path,
        *,
        preserve_names: bool = False,
        progress: Callable[[int, int, Path], None] | None = None,
    ) -> tuple[ProcessingReport, Path]:
        report = ProcessingReport(input_files=[str(item) for item in inputs])
        log_dir.mkdir(parents=True, exist_ok=True)
        if output_dir is not None:
            output_dir.mkdir(parents=True, exist_ok=True)

        for index, input_path in enumerate(inputs, start=1):
            if progress is not None:
                progress(index, len(inputs), input_path)
            summary = self._sanitize_one(input_path, output_dir, preserve_name=preserve_names)
            report.files.append(summary)
            if summary.output_path:
                report.output_files.append(summary.output_path)
            if summary.error:
                report.errors.append(f"{input_path}: {summary.error}")
        report.complete()

        log_path = log_dir / f"{report.run_id}.json"
        log_path.write_text(json.dumps(report.to_json_dict(output_mode=self.output_mode), indent=2, sort_keys=True), encoding="utf-8")
        return report, log_path

    def _sanitize_one(self, input_path: Path, output_dir: Path | None, *, preserve_name: bool = False) -> FileScanSummary:
        input_path = input_path.expanduser().resolve()
        if not input_path.exists():
            return FileScanSummary(input_path=str(input_path), status="failed", error="Input file does not exist.")
        if input_path.suffix.lower() not in {".csv", ".xlsx", ".pptx"}:
            return FileScanSummary(input_path=str(input_path), status="failed", error=f"Unsupported file type: {input_path.suffix}")

        output_path = sanitized_output_path(input_path, output_dir, preserve_name=preserve_name)
        processor = self._processor_for(input_path)
        try:
            return processor.sanitize(
                input_path,
                output_path,
                self.header_detector,
                self.regex_detector,
                self.sanitizer,
                self.min_confidence,
            )
        except Exception as exc:
            return FileScanSummary(input_path=str(input_path), output_path=str(output_path), status="failed", error=str(exc))

    def _processor_for(self, input_path: Path) -> object:
        suffix = input_path.suffix.lower()
        for processor in self.processors:
            if suffix in processor.extensions:
                return processor
        raise ValueError(f"No processor registered for {suffix}")
