import Foundation

struct PIISanitizerRunResult: Sendable {
    let runID: String
    let filesProcessed: Int
    let outputFiles: [URL]
    let logURL: URL?
    let detectionsByType: [String: Int]
    let errors: [String]
}

enum PIISanitizerRunner {
    private static let timeoutSeconds: TimeInterval = 180

    static func sanitize(inputURLs: [URL], outputFolder: URL?, logFolder: URL?) async throws -> PIISanitizerRunResult {
        guard !inputURLs.isEmpty else {
            throw TransformError.invalidInput("Choose at least one CSV, Excel, or PowerPoint file.")
        }

        return try await Task.detached(priority: .userInitiated) {
            try runSanitizer(inputURLs: inputURLs, outputFolder: outputFolder, logFolder: logFolder)
        }.value
    }

    private static func runSanitizer(inputURLs: [URL], outputFolder: URL?, logFolder: URL?) throws -> PIISanitizerRunResult {

        let paths = try runtimePaths()
        let logs = logFolder ?? defaultLogFolder()
        try FileManager.default.createDirectory(at: logs, withIntermediateDirectories: true)

        var arguments = [
            "-m", "pii_sanitizer",
            "sanitize"
        ]
        arguments.append(contentsOf: inputURLs.map(\.path))
        if let outputFolder {
            arguments.append("--output-dir")
            arguments.append(outputFolder.path)
        }
        arguments.append("--log-dir")
        arguments.append(logs.path)
        arguments.append("--output-mode")
        arguments.append("redacted")
        arguments.append("--json")

        let process = Process()
        process.executableURL = paths.python
        process.arguments = arguments
        process.currentDirectoryURL = paths.workingDirectory
        process.environment = [
            "PYTHONPATH": paths.pythonPath.path,
            "PYTHONNOUSERSITE": "1"
        ]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        let stdout = LockedDataBuffer()
        let stderr = LockedDataBuffer()

        outputPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            stdout.append(data)
        }
        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            stderr.append(data)
        }

        try process.run()
        let didFinish = waitForProcess(process, timeout: timeoutSeconds)

        outputPipe.fileHandleForReading.readabilityHandler = nil
        errorPipe.fileHandleForReading.readabilityHandler = nil
        let outputData = stdout.data() + outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = stderr.data() + errorPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrText = String(data: errorData, encoding: .utf8) ?? ""

        guard didFinish else {
            if process.isRunning {
                process.terminate()
            }
            throw TransformError.internalError("Sanitization timed out after \(Int(timeoutSeconds)) seconds. Last error output:\n\(stderrText)")
        }

        guard !outputData.isEmpty else {
            throw TransformError.internalError(stderrText.isEmpty ? "Sanitizer produced no output." : stderrText)
        }

        let json = try JSONSerialization.jsonObject(with: outputData) as? [String: Any]
        guard let json else {
            throw TransformError.internalError("Sanitizer returned an unreadable JSON summary.")
        }

        let result = parseResult(json)
        if process.terminationStatus != 0, result.errors.isEmpty {
            throw TransformError.internalError(stderrText.isEmpty ? "Sanitization failed." : stderrText)
        }
        return result
    }

    private static func waitForProcess(_ process: Process, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning {
            if Date() >= deadline {
                return false
            }
            Thread.sleep(forTimeInterval: 0.05)
        }
        return true
    }

    private static func parseResult(_ json: [String: Any]) -> PIISanitizerRunResult {
        let summary = json["summary"] as? [String: Any] ?? [:]
        let outputPaths = json["output_files"] as? [String] ?? []
        let rawDetections = summary["detections_by_type"] as? [String: Any] ?? [:]
        let detections = rawDetections.reduce(into: [String: Int]()) { partial, item in
            if let value = item.value as? Int {
                partial[item.key] = value
            } else if let value = item.value as? NSNumber {
                partial[item.key] = value.intValue
            }
        }
        let logPath = json["log_path"] as? String

        return PIISanitizerRunResult(
            runID: json["run_id"] as? String ?? "unknown",
            filesProcessed: summary["files_processed"] as? Int ?? 0,
            outputFiles: outputPaths.map { URL(fileURLWithPath: $0) },
            logURL: logPath.map { URL(fileURLWithPath: $0) },
            detectionsByType: detections,
            errors: json["errors"] as? [String] ?? []
        )
    }

    private static func runtimePaths() throws -> (python: URL, pythonPath: URL, workingDirectory: URL) {
        let python = URL(fileURLWithPath: "/usr/bin/python3")
        if let resourceURL = Bundle.main.resourceURL {
            let packageURL = resourceURL.appendingPathComponent("pii_sanitizer")
            if FileManager.default.fileExists(atPath: packageURL.path) {
                return (python, resourceURL, resourceURL)
            }
        }

        let current = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let packageURL = current.appendingPathComponent("pii_sanitizer")
        if FileManager.default.fileExists(atPath: packageURL.path) {
            return (python, current, current)
        }

        throw TransformError.internalError("Could not find the bundled pii_sanitizer Python package.")
    }

    private static func defaultLogFolder() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base
            .appendingPathComponent("PII Sanitizer", isDirectory: true)
            .appendingPathComponent("logs", isDirectory: true)
    }
}

private final class LockedDataBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = Data()

    func append(_ data: Data) {
        lock.lock()
        storage.append(data)
        lock.unlock()
    }

    func data() -> Data {
        lock.lock()
        let snapshot = storage
        lock.unlock()
        return snapshot
    }
}
