from __future__ import annotations

from abc import ABC, abstractmethod

from pii_sanitizer.core.models import DetectionResult


class Detector(ABC):
    name: str

    @abstractmethod
    def detect(self, text: str, *, header: str | None = None, location: str = "") -> list[DetectionResult]:
        raise NotImplementedError
