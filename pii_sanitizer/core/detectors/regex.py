from __future__ import annotations

import re

from pii_sanitizer.core.detectors.base import Detector
from pii_sanitizer.core.models import DetectionResult


class RegexDetector(Detector):
    name = "regex"

    def __init__(self, rules: list[dict[str, object]]) -> None:
        self.compiled_rules: list[tuple[dict[str, object], re.Pattern[str]]] = []
        for rule in rules:
            pattern = str(rule.get("regex", ""))
            if pattern:
                self.compiled_rules.append((rule, re.compile(pattern, re.IGNORECASE)))

    def detect(self, text: str, *, header: str | None = None, location: str = "") -> list[DetectionResult]:
        results: list[DetectionResult] = []
        for rule, regex in self.compiled_rules:
            for match in regex.finditer(text):
                confidence = float(rule.get("confidence", 0.75))
                if header and _header_matches(header, rule):
                    confidence = min(1.0, confidence + 0.15)
                results.append(
                    DetectionResult(
                        entity_type=str(rule["entity_type"]),
                        detector_name=self.name,
                        confidence=confidence,
                        evidence_type="content",
                        strategy=str(rule.get("strategy", "redact")),
                        start=match.start(),
                        end=match.end(),
                        location=location,
                    )
                )
        return results


def _header_matches(header: str, rule: dict[str, object]) -> bool:
    normalized = re.sub(r"[^\w]+", "_", header.lower(), flags=re.UNICODE).strip("_")
    aliases = [re.sub(r"[^\w]+", "_", str(item).lower(), flags=re.UNICODE).strip("_") for item in rule.get("headers", [])]
    return normalized in aliases or any(alias and alias in normalized for alias in aliases)
