import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    private let brandLightStart = Color(red: 0.95, green: 0.97, blue: 1.0)
    private let brandLightEnd = Color(red: 0.88, green: 0.94, blue: 0.98)
    private let brandDarkStart = Color(red: 0.08, green: 0.12, blue: 0.20)
    private let brandDarkEnd = Color(red: 0.06, green: 0.20, blue: 0.26)
    private let brandAccent = Color(red: 0.10, green: 0.55, blue: 0.82)
    private let updateCheckTimer = Timer.publish(every: 60 * 60 * 4, on: .main, in: .common).autoconnect()
    @Environment(\.colorScheme) private var activeColorScheme
    @AppStorage("app_appearance_mode") private var appearanceModeRaw = AppearanceMode.system.rawValue

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
                colors: backgroundColors,
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
                appearanceCard
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
                    .tint(brandAccent)

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

                    Button {
                        openFeedbackInBrowser(provider: .gmail)
                    } label: {
                        Label("Gmail", systemImage: "globe")
                    }

                    Button {
                        openFeedbackInBrowser(provider: .outlookWeb)
                    } label: {
                        Label("Outlook Web", systemImage: "globe")
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
                .background(cardBackgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(20)
            .frame(minWidth: 820, minHeight: 580)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        Image(nsImage: NSApp.applicationIconImage)
                            .resizable()
                            .frame(width: 16, height: 16)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        Text(AppInfo.appName)
                            .font(.headline)
                    }
                }
            }
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
        .preferredColorScheme(appearanceMode.colorScheme)
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
        .background(cardBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var appearanceCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Appearance")
                .font(.headline)
            Picker("Appearance", selection: $appearanceModeRaw) {
                ForEach(AppearanceMode.allCases, id: \.rawValue) { mode in
                    Text(mode.label).tag(mode.rawValue)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(12)
        .background(cardBackgroundColor)
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
        .background(cardBackgroundColor)
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
        .background(cardBackgroundColor)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(brandAccent.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [6]))
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
        .background(cardBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var appearanceMode: AppearanceMode {
        AppearanceMode(rawValue: appearanceModeRaw) ?? .system
    }

    private var backgroundColors: [Color] {
        let isDark = activeColorScheme == .dark || appearanceMode == .dark
        return isDark ? [brandDarkStart, brandDarkEnd] : [brandLightStart, brandLightEnd]
    }

    private var cardBackgroundColor: Color {
        (activeColorScheme == .dark || appearanceMode == .dark) ? .white.opacity(0.08) : .white.opacity(0.86)
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
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = AppInfo.creatorEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body)
        ]

        guard let url = components.url else {
            statusMessage = "Could not open email app for feedback."
            isError = true
            return
        }

        let opened = NSWorkspace.shared.open(url)
        if opened {
            statusMessage = "Opened email app for feedback to \(AppInfo.creatorEmail)."
            isError = false
        } else {
            statusMessage = "Could not open a mail app. Please email feedback to \(AppInfo.creatorEmail)."
            isError = true
        }
    }

    @MainActor
    private func openFeedbackInBrowser(provider: FeedbackProvider) {
        let subject = "File Transformer and Formatter - Feedback or Bug Report"
        let body = """
        Hi Rohit,

        I would like to share the following feedback/bug:

        Steps to reproduce:
        Expected result:
        Actual result:
        """

        guard let url = provider.composeURL(
            to: AppInfo.creatorEmail,
            subject: subject,
            body: body
        ) else {
            statusMessage = "Could not build browser feedback link."
            isError = true
            return
        }

        let opened = NSWorkspace.shared.open(url)
        if opened {
            statusMessage = "Opened \(provider.label) compose page for feedback."
            isError = false
        } else {
            statusMessage = "Could not open browser compose page."
            isError = true
        }
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

private enum FeedbackProvider {
    case gmail
    case outlookWeb

    var label: String {
        switch self {
        case .gmail:
            return "Gmail"
        case .outlookWeb:
            return "Outlook Web"
        }
    }

    func composeURL(to: String, subject: String, body: String) -> URL? {
        switch self {
        case .gmail:
            var components = URLComponents(string: "https://mail.google.com/mail/u/0/")
            components?.queryItems = [
                URLQueryItem(name: "view", value: "cm"),
                URLQueryItem(name: "fs", value: "1"),
                URLQueryItem(name: "to", value: to),
                URLQueryItem(name: "su", value: subject),
                URLQueryItem(name: "body", value: body)
            ]
            return components?.url
        case .outlookWeb:
            var components = URLComponents(string: "https://outlook.office.com/mail/deeplink/compose")
            components?.queryItems = [
                URLQueryItem(name: "to", value: to),
                URLQueryItem(name: "subject", value: subject),
                URLQueryItem(name: "body", value: body)
            ]
            return components?.url
        }
    }
}

private enum AppearanceMode: String, CaseIterable {
    case system
    case light
    case dark

    var label: String {
        switch self {
        case .system:
            return "System"
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}
