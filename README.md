# Offline PII Sanitizer

A fully offline macOS menu bar app and Python sanitizer engine for CSV, Excel, and PowerPoint files.

## What It Does

- Sanitizes `.csv`, `.xlsx`, and `.pptx` files.
- Writes new `.sanitized` files and never overwrites originals.
- Creates structured JSON logs for every run.
- Runs locally with no update checks, telemetry, analytics, remote logging, or network calls.
- Detects PII using a lightweight header + regex pipeline inspired by Presidio-style modular detectors and scrubadub-style simple cleaning patterns.

## Project Structure

```text
pii_sanitizer/
  core/
    detectors/      Header and regex detectors.
    sanitizers/     Redact, mask, hash, and replacement strategies.
    processors/     CSV, Excel, and PowerPoint processors.
    pipeline.py     Detection, sanitization, output, and log orchestration.
    models.py       Shared run, detection, and report models.
    registry.py     Built-in detector rule registration.
  cli/
    main.py         Local command line entrypoint.
config/             Rule, strategy, and runtime defaults.
logs/               Placeholder for local JSON logs.
Sources/            Native SwiftUI macOS menu bar app.
```

## Data Flow

1. Select files from the macOS menu bar app or pass files to the CLI.
2. The processor extracts editable text from CSV rows or Office XML parts.
3. Header and regex detectors identify likely PII.
4. Sanitizers redact, mask, hash, or replace detected values.
5. The app writes new sanitized files.
6. The pipeline writes a JSON log without raw PII values.

## CLI

```bash
python3 -m pii_sanitizer sanitize ./input.csv --output-dir ./sanitized --log-dir ./logs --json
```

Batch sanitize every supported file in a folder:

```bash
python3 -m pii_sanitizer sanitize ./client_documents --log-dir ./logs
```

Folder input creates `./client_documents/Sanitized_Output` by default and keeps original filenames inside that output folder. Terminal output shows progress such as `[1/12] Sanitizing customers.xlsx`.

Every run writes a JSON audit log with timestamp, processed files, output files, redaction counts by PII type, skipped files, and errors.

## Verification Suite

Generate synthetic CSV, Excel, and PowerPoint files, run the sanitizer, and produce a pass/fail verification report:

```bash
python3 -B scripts/verification_suite.py
```

The suite writes fixtures, sanitized outputs, JSON audit logs, and `Verification_Report.md` under `verification_artifacts/`.

## Add Rules

Add a new detector rule in `config/rules.yaml`, then mirror it in `pii_sanitizer/core/registry.py` if it should ship as a built-in default.

Built-in regional coverage currently includes:

- Saudi National ID numbers.
- Saudi Iqama/residency numbers.
- GCC mobile numbers using Saudi, UAE, Bahrain, Qatar, Kuwait, and Oman country codes.
- GCC IBAN formats for Saudi Arabia, UAE, Bahrain, Kuwait, Qatar, and Oman.
- UAE Emirates ID.
- GCC passport-like values when supported by a passport header.
- English and Arabic header aliases for common Saudi/GCC fields.
- Survey and organization hierarchy name fields such as manager, mgr, mngr, director, supervisor, executive, VP, team lead, department head, regional manager, and common abbreviated variants.

Example:

```yaml
- id: uae_id
  entity_type: NATIONAL_ID_UAE
  headers: [uae_id, emirates_id, eid]
  regex: "\\b784[-\\s]?[0-9]{4}[-\\s]?[0-9]{7}[-\\s]?[0-9]\\b"
  strategy: redact
  min_confidence: 0.80
```

## Build

```bash
swift build
```

## Package a macOS App

```bash
./scripts/package_app.sh
```

The packaging script bundles the Swift executable, app icon, Python sanitizer package, and config files into:

```text
dist/Offline PII Sanitizer.app
```
