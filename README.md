# File Transformer and Formatter

A native offline app to:
- Convert CSV to nicely formatted flat JSON
- Convert flat JSON to CSV
- Format flat JSON for readability without changing values into grouped arrays

## Why this app helps
- No online converter is required.
- No Python, Node.js, or other runtime is required for team members.
- File data stays local and private.
- Drag-and-drop input makes repeat file operations faster.
- Built-in usage counters show impact over time for each action.

## Creator
- Name: Rohit Bhattad
- Email: rohit.bhattad@outlook.com

## Privacy and Offline Behavior
- No network calls are used.
- All parsing and conversion happen locally.
- Input/output files remain on disk selected by the user.

## Requirements (for building)
- macOS 13+
- Xcode Command Line Tools (Swift)

## Run Locally
```bash
swift run
```

## Build
```bash
swift build -c release
```

## Create a Shareable `.app`
```bash
./scripts/package_app.sh
```

This creates:
- `dist/File Transformer and Formatter.app`

Optional zip for sharing:
```bash
cd dist
zip -r "File Transformer and Formatter.zip" "File Transformer and Formatter.app"
```

## Feedback and Bugs
- The app includes a `Share Feedback / Bug` button.
- Clicking it opens the user's default mail app with a prefilled email to `rohit.bhattad@outlook.com`.

## Update Checks (GitHub)
- The app includes a `Check for Updates` button.
- It checks this GitHub repo for latest release:
  - `https://github.com/bhattad18/file-transformer-formatter`
- It compares the current app version vs GitHub `releases/latest`.
- If a newer version is available, users get:
  - an in-app update message
  - a `Download Latest Version` button
  - a local macOS notification (once per new version while app is in use)

To publish an update:
1. Build and zip the new app.
2. Create a GitHub Release with a tag like `v1.0.1`.
3. Upload the zip/app as a release asset.
4. Users click `Check for Updates` (or wait for periodic check while app is open).

## Sharing With Colleagues
- Yes, you can share `File Transformer and Formatter.app`.
- For easiest delivery over chat/email, share the zip:
  - `File Transformer and Formatter.zip`

## Notes on Input Rules
- CSV -> JSON always outputs a flat JSON array of objects.
- JSON -> CSV and JSON formatting accept:
  - a single flat object, or
  - an array of flat objects
- Nested JSON objects/arrays are rejected with a clear error message.

## Code Signing and Notarization
Update values for your Apple Developer account and certificate names.

1. Create an archive zip for the app:
```bash
cd dist
zip -r "File Transformer and Formatter.zip" "File Transformer and Formatter.app"
```

2. Sign the app with Developer ID Application certificate:
```bash
codesign --deep --force --verify --verbose \
  --sign "Developer ID Application: YOUR_NAME (TEAM_ID)" \
  "File Transformer and Formatter.app"
```

3. Notarize with notarytool:
```bash
xcrun notarytool submit "File Transformer and Formatter.zip" \
  --apple-id "YOUR_APPLE_ID" \
  --team-id "YOUR_TEAM_ID" \
  --password "YOUR_APP_SPECIFIC_PASSWORD" \
  --wait
```

4. Staple notarization ticket:
```bash
xcrun stapler staple "File Transformer and Formatter.app"
```

5. Validate Gatekeeper:
```bash
spctl --assess --type execute --verbose "File Transformer and Formatter.app"
```
