import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    private let updateCheckTimer = Timer.publish(every: 60 * 60 * 4, on: .main, in: .common).autoconnect()

    @State private var selectedAction: TransformAction = .csvToJSON
    @State private var statusMessage = "Choose an action, select or drop a file, then save the output."
    @State private var isError = false
    @State private var selectedInputURL: URL?
    @State private var lastOutputURL: URL?
    @State private var isCheckingUpdates = false
    @State private var updateMessage = "Update status not checked yet."
    @State private var latestReleaseURL: URL?
    @State private var latestReleaseVersion: String?
    @StateObject private var usageStats = UsageStats()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.96, green: 0.98, blue: 1.0), Color(red: 0.93, green: 0.96, blue: 0.93)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                Text(AppInfo.appName)
                    .font(.title2)
                    .bold()

                Text("Offline file conversion and formatting. Your data stays on your machine, and no online tools are required.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                creatorCard
                updatesCard

                Picker("Action", selection: $selectedAction) {
                    ForEach(TransformAction.allCases) { action in
                        Text(action.label).tag(action)
                    }
                }
                .pickerStyle(.segmented)

                Text(selectedAction.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                dropArea

                HStack(spacing: 12) {
                    Button("Choose File") {
                        pickInputFile()
                    }

                    Button("Run and Save") {
                        runSelectedAction()
                    }
                    .keyboardShortcut(.defaultAction)

                    if lastOutputURL != nil {
                        Button {
                            openOutputFolder()
                        } label: {
                            Label("Show Output Folder", systemImage: "folder")
                        }
                    }

                    Button("Clear Status") {
                        statusMessage = "Status cleared."
                        isError = false
                    }

                    Button {
                        openFeedbackEmail()
                    } label: {
                        Label("Share Feedback / Bug", systemImage: "envelope")
                    }
                }

                statsSection

                Divider()

                Text(isError ? "Error" : "Status")
                    .font(.headline)

                ScrollView {
                    Text(statusMessage)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(minHeight: 120)
                .padding(10)
                .background(.white.opacity(0.9))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(20)
            .frame(minWidth: 820, minHeight: 580)
            .task {
                NotificationService.requestPermissionIfNeeded()
                await checkForUpdates(manual: false)
            }
            .onReceive(updateCheckTimer) { _ in
                Task {
                    await checkForUpdates(manual: false)
                }
            }
        }
    }

    private var creatorCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Created by \(AppInfo.creatorName)")
                    .font(.headline)
                Text("Email: \(AppInfo.creatorEmail)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(.white.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var updatesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Updates")
                    .font(.headline)
                Spacer()
                Button {
                    Task { await checkForUpdates(manual: true) }
                } label: {
                    if isCheckingUpdates {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("Check for Updates", systemImage: "arrow.clockwise")
                    }
                }
                .disabled(isCheckingUpdates)
            }

            Text(updateMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let latestReleaseURL, latestReleaseVersion != nil {
                Button {
                    NSWorkspace.shared.open(latestReleaseURL)
                } label: {
                    Label("Download Latest Version", systemImage: "square.and.arrow.down")
                }
            }
        }
        .padding(12)
        .background(.white.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var dropArea: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Input File")
                .font(.headline)
            Text(selectedInputURL?.path ?? "Drag and drop a file here, or use Choose File.")
                .font(.subheadline)
                .foregroundStyle(selectedInputURL == nil ? .secondary : .primary)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, minHeight: 90, alignment: .leading)
        .padding(14)
        .background(.white.opacity(0.85))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.accentColor.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [6]))
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: nil, perform: handleDrop(providers:))
    }

    private var statsSection: some View {
        HStack(spacing: 12) {
            statCard(title: "CSV -> JSON", value: usageStats.count(for: .csvToJSON))
            statCard(title: "JSON -> CSV", value: usageStats.count(for: .jsonToCSV))
            statCard(title: "Format JSON", value: usageStats.count(for: .formatJSONByLine))
        }
    }

    private func statCard(title: String, value: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(value)")
                .font(.title3)
                .bold()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.white.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    @MainActor
    private func pickInputFile() {
        do {
            selectedInputURL = try FilePanel.pickFile(allowedExtensions: selectedAction.allowedInputExtensions)
            statusMessage = "Selected input:\n\(selectedInputURL?.path ?? "")"
            isError = false
        } catch {
            if (error as NSError).code == NSUserCancelledError {
                statusMessage = "File selection canceled."
                isError = false
                return
            }
            statusMessage = error.localizedDescription
            isError = true
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: {
            $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
        }) else {
            return false
        }

        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil)
            else {
                return
            }
            DispatchQueue.main.async {
                self.selectedInputURL = url
                self.statusMessage = "Selected input:\n\(url.path)"
                self.isError = false
            }
        }
        return true
    }

    @MainActor
    private func runSelectedAction() {
        do {
            let inputURL = try resolveInputFile()
            let output = try DataTransformService.run(action: selectedAction, inputURL: inputURL)
            let outputURL = try FilePanel.pickSaveLocation(
                suggestedName: selectedAction.suggestedOutputFileName(from: inputURL),
                allowedExtension: selectedAction.outputExtension
            )
            try output.write(to: outputURL, atomically: true, encoding: .utf8)
            usageStats.increment(action: selectedAction)
            lastOutputURL = outputURL
            statusMessage = "Done. Output saved to:\n\(outputURL.path)"
            isError = false
        } catch {
            if (error as NSError).code == NSUserCancelledError {
                statusMessage = "Operation canceled."
                isError = false
                return
            }
            statusMessage = error.localizedDescription
            isError = true
        }
    }

    @MainActor
    private func resolveInputFile() throws -> URL {
        if let existing = selectedInputURL {
            try validateInputFileExtension(existing)
            return existing
        }
        let picked = try FilePanel.pickFile(allowedExtensions: selectedAction.allowedInputExtensions)
        try validateInputFileExtension(picked)
        selectedInputURL = picked
        return picked
    }

    private func validateInputFileExtension(_ url: URL) throws {
        let ext = url.pathExtension.lowercased()
        let allowed = selectedAction.allowedInputExtensions.map { $0.lowercased() }
        guard allowed.contains(ext) else {
            throw TransformError.invalidInput("Selected file type '.\(ext)' is not valid for \(selectedAction.label).")
        }
    }

    @MainActor
    private func openOutputFolder() {
        guard let url = lastOutputURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    @MainActor
    private func openFeedbackEmail() {
        let subject = "File Transformer and Formatter - Feedback or Bug Report"
        let body = """
        Hi Rohit,

        I would like to share the following feedback/bug:

        Steps to reproduce:
        Expected result:
        Actual result:
        """
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let url = URL(string: "mailto:\(AppInfo.creatorEmail)?subject=\(encodedSubject)&body=\(encodedBody)") else {
            statusMessage = "Could not open email app for feedback."
            isError = true
            return
        }
        NSWorkspace.shared.open(url)
    }

    @MainActor
    private func checkForUpdates(manual: Bool) async {
        isCheckingUpdates = true
        defer { isCheckingUpdates = false }

        let current = UpdateService.currentVersionFromBundle()
        let result = await UpdateService.checkForUpdates(currentVersion: current)

        switch result {
        case let .upToDate(current):
            latestReleaseURL = nil
            latestReleaseVersion = nil
            updateMessage = "You're up to date (v\(current))."
        case let .updateAvailable(current, release):
            latestReleaseURL = release.url
            latestReleaseVersion = release.version
            updateMessage = "Update available: v\(release.version) (current: v\(current))."
            NotificationService.notifyUpdateAvailableIfNeeded(version: release.version)
        case let .failed(message):
            if manual {
                updateMessage = message
            } else if latestReleaseVersion == nil {
                updateMessage = "Unable to check updates automatically right now."
            }
        }
    }
}
