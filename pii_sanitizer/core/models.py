from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from uuid import uuid4


@dataclass(frozen=True)
class DetectionResult:
    entity_type: str
    detector_name: str
    confidence: float
    evidence_type: str
    strategy: str
    start: int = 0
    end: int = 0
    location: str = ""


@dataclass(frozen=True)
class SanitizationAction:
    entity_type: str
    strategy: str
    location: str


@dataclass(frozen=True)
class SanitizedSpan:
    label: str
    start: int
    end: int
    location: str
    strategy: str
    detector_name: str
    evidence_type: str
    confidence: float
    placeholder: str

    def to_json_dict(self, *, output_mode: str = "typed") -> dict[str, Any]:
        label = "redacted" if output_mode == "redacted" else self.label
        return {
            "label": label,
            "start": self.start,
            "end": self.end,
            "location": self.location,
            "strategy": self.strategy,
            "detector_name": self.detector_name,
            "evidence_type": self.evidence_type,
            "confidence": round(self.confidence, 4),
            "placeholder": self.placeholder,
        }


@dataclass
class FileScanSummary:
    input_path: str
    output_path: str | None = None
    status: str = "pending"
    detections_by_type: dict[str, int] = field(default_factory=dict)
    actions_by_strategy: dict[str, int] = field(default_factory=dict)
    detected_spans: list[SanitizedSpan] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)
    error: str | None = None


@dataclass
class ProcessingReport:
    run_id: str = field(default_factory=lambda: str(uuid4()))
    started_at: str = field(default_factory=lambda: datetime.now(timezone.utc).isoformat())
    completed_at: str | None = None
    offline_mode: bool = True
    input_files: list[str] = field(default_factory=list)
    output_files: list[str] = field(default_factory=list)
    files: list[FileScanSummary] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)
    errors: list[str] = field(default_factory=list)

    def complete(self) -> None:
        self.completed_at = datetime.now(timezone.utc).isoformat()

    def to_json_dict(self, *, output_mode: str = "typed") -> dict[str, Any]:
        detections: dict[str, int] = {}
        actions: dict[str, int] = {}
        for file_summary in self.files:
            for key, value in file_summary.detections_by_type.items():
                detections[key] = detections.get(key, 0) + value
            for key, value in file_summary.actions_by_strategy.items():
                actions[key] = actions.get(key, 0) + value

        return {
            "schema_version": 2,
            "run_id": self.run_id,
            "started_at": self.started_at,
            "completed_at": self.completed_at,
            "offline_mode": self.offline_mode,
            "output_mode": output_mode,
            "input_files": self.input_files,
            "output_files": self.output_files,
            "summary": {
                "files_processed": len([item for item in self.files if item.status == "success"]),
                "span_count": sum(len(item.detected_spans) for item in self.files),
                "detections_by_type": detections,
                "actions_by_strategy": actions,
            },
            "files": [
                {
                    "input_path": item.input_path,
                    "output_path": item.output_path,
                    "status": item.status,
                    "detections_by_type": item.detections_by_type,
                    "actions_by_strategy": item.actions_by_strategy,
                    "detected_spans": [span.to_json_dict(output_mode=output_mode) for span in item.detected_spans],
                    "warnings": item.warnings,
                    "error": item.error,
                }
                for item in self.files
            ],
            "warnings": self.warnings,
            "errors": self.errors,
        }


def sanitized_output_path(input_path: Path, output_dir: Path | None = None, *, preserve_name: bool = False) -> Path:
    target_dir = output_dir if output_dir is not None else input_path.parent
    candidate = target_dir / input_path.name if preserve_name else target_dir / f"{input_path.stem}.sanitized{input_path.suffix}"
    index = 2
    while candidate.exists() or candidate.resolve() == input_path.resolve():
        if preserve_name:
            candidate = target_dir / f"{input_path.stem}-{index}{input_path.suffix}"
        else:
            candidate = target_dir / f"{input_path.stem}.sanitized-{index}{input_path.suffix}"
        index += 1
    return candidate
