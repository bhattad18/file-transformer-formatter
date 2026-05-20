from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from pii_sanitizer.core.pipeline import SanitizationPipeline

SUPPORTED_EXTENSIONS = {".csv", ".xlsx", ".pptx"}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="pii-sanitize", description="Offline PII sanitizer for CSV, Excel, and PowerPoint files.")
    subparsers = parser.add_subparsers(dest="command", required=True)

    sanitize = subparsers.add_parser("sanitize", help="Sanitize one or more local files.")
    sanitize.add_argument("inputs", nargs="+", help="Input .csv/.xlsx/.pptx files or one folder for batch mode.")
    sanitize.add_argument("--output-dir", type=Path, default=None, help="Directory for sanitized files. Folder input defaults to Sanitized_Output.")
    sanitize.add_argument("--log-dir", type=Path, default=Path("logs"), help="Directory for JSON logs.")
    sanitize.add_argument("--min-confidence", type=float, default=0.70, help="Minimum detector confidence to sanitize.")
    sanitize.add_argument("--salt", default=None, help="Local salt for deterministic hash strategy.")
    sanitize.add_argument("--output-mode", choices=["typed", "redacted"], default="typed", help="Typed keeps PII labels in JSON; redacted collapses JSON span labels to 'redacted'.")
    sanitize.add_argument("--json", action="store_true", help="Print machine-readable summary.")

    args = parser.parse_args(argv)
    if args.command == "sanitize":
        input_paths, output_dir, preserve_names, skipped = _resolve_inputs([Path(item) for item in args.inputs], args.output_dir)
        pipeline = SanitizationPipeline(salt=args.salt, min_confidence=args.min_confidence, output_mode=args.output_mode)
        report, log_path = pipeline.sanitize_paths(
            input_paths,
            output_dir,
            args.log_dir,
            preserve_names=preserve_names,
            progress=None if args.json else _print_progress,
        )
        report.warnings.extend(skipped)
        if skipped:
            log_path.write_text(json.dumps(report.to_json_dict(output_mode=args.output_mode), indent=2, sort_keys=True), encoding="utf-8")
        payload = report.to_json_dict(output_mode=args.output_mode)
        payload["log_path"] = str(log_path)
        if args.json:
            print(json.dumps(payload, indent=2, sort_keys=True))
        else:
            print(f"Run ID: {report.run_id}")
            print(f"Files processed: {payload['summary']['files_processed']}")
            print(f"Output files: {len(report.output_files)}")
            print(f"Log: {log_path}")
            for warning in skipped:
                print(f"Skipped: {warning}", file=sys.stderr)
            for error in report.errors:
                print(f"Error: {error}", file=sys.stderr)
        return 1 if report.errors else 0
    return 2


def _resolve_inputs(inputs: list[Path], output_dir: Path | None) -> tuple[list[Path], Path | None, bool, list[str]]:
    if len(inputs) == 1 and inputs[0].expanduser().is_dir():
        folder = inputs[0].expanduser().resolve()
        batch_output = output_dir or folder / "Sanitized_Output"
        files = sorted(
            item for item in folder.iterdir()
            if item.is_file() and item.suffix.lower() in SUPPORTED_EXTENSIONS
        )
        skipped = [
            f"{item.name} has unsupported extension {item.suffix or '(none)'}"
            for item in sorted(folder.iterdir())
            if item.is_file() and item.suffix.lower() not in SUPPORTED_EXTENSIONS
        ]
        return files, batch_output, True, skipped
    return inputs, output_dir, False, []


def _print_progress(index: int, total: int, path: Path) -> None:
    print(f"[{index}/{total}] Sanitizing {path.name}", file=sys.stderr)


if __name__ == "__main__":
    raise SystemExit(main())
