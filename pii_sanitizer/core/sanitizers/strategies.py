from __future__ import annotations

import hashlib
import re

from pii_sanitizer.core.models import DetectionResult, SanitizedSpan


class Sanitizer:
    def __init__(self, salt: str) -> None:
        self.salt = salt
        self.counters: dict[str, int] = {}
        self.replacements: dict[tuple[str, str], str] = {}

    def sanitize_text(self, text: str, detections: list[DetectionResult]) -> tuple[str, list[SanitizedSpan]]:
        if not detections:
            return text, []
        filtered = _remove_overlaps(sorted(detections, key=lambda item: (item.start, -(item.end - item.start))))
        spans: list[SanitizedSpan] = []
        output: list[str] = []
        cursor = 0
        for detection in filtered:
            if detection.start < cursor:
                continue
            raw = text[detection.start:detection.end]
            placeholder = self._apply(raw, detection)
            output.append(text[cursor:detection.start])
            output.append(placeholder)
            cursor = detection.end
            spans.append(
                SanitizedSpan(
                    label=detection.entity_type,
                    start=detection.start,
                    end=detection.end,
                    location=detection.location,
                    strategy=detection.strategy,
                    detector_name=detection.detector_name,
                    evidence_type=detection.evidence_type,
                    confidence=detection.confidence,
                    placeholder=placeholder,
                )
            )
        output.append(text[cursor:])
        return "".join(output), spans

    def sanitize_whole_value(self, text: str, detection: DetectionResult) -> str:
        return self._apply(text, detection)

    def _apply(self, value: str, detection: DetectionResult) -> str:
        strategy = detection.strategy
        if strategy == "mask":
            return _mask(value)
        if strategy == "hash":
            digest = hashlib.sha256(f"{self.salt}:{value}".encode("utf-8")).hexdigest()[:16]
            return f"[HASHED_{detection.entity_type}_{digest}]"
        if strategy == "replace":
            key = (detection.entity_type, value)
            if key not in self.replacements:
                self.counters[detection.entity_type] = self.counters.get(detection.entity_type, 0) + 1
                self.replacements[key] = f"{detection.entity_type}_{self.counters[detection.entity_type]:03d}"
            return self.replacements[key]
        return f"[REDACTED_{detection.entity_type}]"


def _mask(value: str) -> str:
    if "@" in value:
        name, domain = value.split("@", 1)
        visible = name[:2] if len(name) > 2 else name[:1]
        return f"{visible}{'*' * max(3, len(name) - len(visible))}@{domain}"
    digits = re.sub(r"\D", "", value)
    if len(digits) >= 4:
        return re.sub(r"\d", "*", value[:-4]) + value[-4:]
    if len(value) <= 2:
        return "*" * len(value)
    return value[0] + ("*" * (len(value) - 2)) + value[-1]


def _remove_overlaps(detections: list[DetectionResult]) -> list[DetectionResult]:
    selected: list[DetectionResult] = []
    occupied: list[range] = []
    for detection in sorted(detections, key=lambda item: (-item.confidence, -(item.end - item.start))):
        span = range(detection.start, detection.end)
        if any(detection.start < item.stop and item.start < detection.end for item in occupied):
            continue
        selected.append(detection)
        occupied.append(span)
    return sorted(selected, key=lambda item: item.start)
