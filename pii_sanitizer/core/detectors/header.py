from __future__ import annotations

import re

from pii_sanitizer.core.detectors.base import Detector
from pii_sanitizer.core.models import DetectionResult


class HeaderDetector(Detector):
    name = "header"

    def __init__(self, rules: list[dict[str, object]]) -> None:
        self.rules = rules

    def detect(self, text: str, *, header: str | None = None, location: str = "") -> list[DetectionResult]:
        if not header or not text.strip():
            return []
        normalized = _normalize_header(header)
        results: list[DetectionResult] = []
        for rule in self.rules:
            aliases = [_normalize_header(str(item)) for item in rule.get("headers", [])]
            if normalized in aliases or any(alias and alias in normalized for alias in aliases):
                results.append(
                    DetectionResult(
                        entity_type=str(rule["entity_type"]),
                        detector_name=self.name,
                        confidence=float(rule.get("header_confidence", 0.70)),
                        evidence_type="header",
                        strategy=str(rule.get("strategy", "redact")),
                        start=0,
                        end=len(text),
                        location=location,
                    )
                )
        return results


def _normalize_header(header: str) -> str:
    return re.sub(r"[^\w]+", "_", header.lower(), flags=re.UNICODE).strip("_")
