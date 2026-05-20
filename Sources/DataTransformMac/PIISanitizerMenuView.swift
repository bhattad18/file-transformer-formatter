import AppKit
import SwiftUI

@MainActor
final class PIISanitizerMenuModel: ObservableObject {
    @Published var selectedFiles: [URL] = []
    @Published var outputFolder: URL?
    @Published var lastOutputFiles: [URL] = []
    @Published var lastLogURL: URL?
    @Published var status = "Ready. Files stay local and originals are never overwritten."
    @Published var isWorking = false
    @Published var detectionsByType: [String: Int] = [:]

    var selectionSummary: String {
        let fileText = selectedFiles.isEmpty ? "No files selected" : "\(selectedFiles.count) item(s) selected"
        let outputText = outputFolder?.path ?? "Default output beside each file"
        return "\(fileText)\nOutput: \(outputText)"
    }

    func chooseFiles() {
        do {
            selectedFiles = try FilePanel.pickFiles(allowedExtensions: ["csv", "xlsx", "pptx"])
            status = "Selected \(selectedFiles.count) file(s)."
        } catch {
            handleSelectionError(error)
        }
    }

    func chooseOutputFolder() {
        do {
            let currentSelection = selectedFiles
            outputFolder = try FilePanel.pickOutputFolder()
            selectedFiles = currentSelection
            let selectedText = selectedFiles.isEmpty ? "No files selected yet." : "\(selectedFiles.count) file(s) remain selected."
            status = "\(selectedText)\nOutput folder: \(outputFolder?.path ?? "")"
        } catch {
            handleSelectionError(error)
        }
    }

    func chooseInputFolder() {
        do {
            selectedFiles = [try FilePanel.pickInputFolder()]
            status = "Selected folder for batch sanitization."
        } catch {
            handleSelectionError(error)
        }
    }

    func sanitize() {
        guard !isWorking else { return }
        guard !selectedFiles.isEmpty else {
            status = "Choose files before running sanitization."
            return
        }
        isWorking = true
        status = "Sanitizing \(selectedFiles.count) file(s) offline..."
        let inputs = selectedFiles
        let output = outputFolder

        Task {
            do {
                let result = try await PIISanitizerRunner.sanitize(inputURLs: inputs, outputFolder: output, logFolder: nil)
                await MainActor.run {
                    lastOutputFiles = result.outputFiles
                    lastLogURL = result.logURL
                    detectionsByType = result.detectionsByType
                    status = Self.statusText(for: result)
                    isWorking = false
                }
            } catch {
                await MainActor.run {
                    status = error.localizedDescription
                    isWorking = false
                }
            }
        }
    }

    func openOutputs() {
        guard let first = lastOutputFiles.first else { return }
        NSWorkspace.shared.activateFileViewerSelecting(lastOutputFiles.isEmpty ? [first] : lastOutputFiles)
    }

    func openLog() {
        guard let lastLogURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([lastLogURL])
    }

    func copyDeveloperEmail() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(AppInfo.creatorEmail, forType: .string)
        status = "Copied developer email: \(AppInfo.creatorEmail)"
    }

    func openFeedbackMailApp() {
        do {
            try FeedbackService.openDefaultMailApp()
            status = "Opened feedback draft in the default mail handler."
        } catch {
            status = error.localizedDescription
        }
    }

    func openFeedbackWebmail(_ provider: FeedbackWebmailProvider) {
        do {
            try FeedbackService.openWebmail(provider)
            status = "Opened \(provider.label) feedback draft."
        } catch {
            status = error.localizedDescription
        }
    }

    func openFeedbackApp(_ app: InstalledMailApp) {
        do {
            try FeedbackService.openMailHandler(app)
            status = "Opened feedback draft in \(app.name)."
        } catch {
            status = error.localizedDescription
        }
    }

    func shareFeedbackWithAttachments() {
        do {
            let attachments = try FilePanel.pickFeedbackAttachments()
            try FeedbackService.composeEmailWithAttachments(attachments)
            status = "Opened feedback draft with \(attachments.count) attachment(s)."
        } catch {
            if (error as NSError).code == NSUserCancelledError {
                status = "Feedback attachment selection canceled."
            } else {
                status = error.localizedDescription
            }
        }
    }

    func quit() {
        NSApp.terminate(nil)
    }

    private func handleSelectionError(_ error: Error) {
        if (error as NSError).code == NSUserCancelledError {
            status = "Selection canceled."
        } else {
            status = error.localizedDescription
        }
    }

    private static func statusText(for result: PIISanitizerRunResult) -> String {
        var lines = [
            "Run \(result.runID)",
            "Processed: \(result.filesProcessed)",
            "Outputs: \(result.outputFiles.count)"
        ]
        if !result.detectionsByType.isEmpty {
            let detections = result.detectionsByType
                .sorted { $0.key < $1.key }
                .map { "\($0.key): \($0.value)" }
                .joined(separator: ", ")
            lines.append("Detections: \(detections)")
        }
        if !result.errors.isEmpty {
            lines.append("Errors: \(result.errors.count)")
        }
        if let logURL = result.logURL {
            lines.append("Log: \(logURL.path)")
        }
        return lines.joined(separator: "\n")
    }
}

struct PIISanitizerMenuView: View {
    @ObservedObject var model: PIISanitizerMenuModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Offline PII Sanitizer")
                .font(.headline)
            Text(model.status)
                .font(.caption)
                .lineLimit(8)
                .textSelection(.enabled)
            Text(model.selectionSummary)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(4)
                .textSelection(.enabled)

            Divider()

            Button {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                Label("Open Full App", systemImage: "macwindow")
            }

            Divider()

            Button {
                model.chooseFiles()
            } label: {
                Label("Sanitize Files...", systemImage: "doc.badge.plus")
            }

            Button {
                model.chooseInputFolder()
            } label: {
                Label("Sanitize Folder...", systemImage: "folder")
            }

            Button {
                model.chooseOutputFolder()
            } label: {
                Label("Choose Output Folder...", systemImage: "folder.badge.plus")
            }

            Button {
                model.sanitize()
            } label: {
                Label(model.isWorking ? "Sanitizing..." : "Run Sanitizer", systemImage: "shield")
            }
            .disabled(model.isWorking || model.selectedFiles.isEmpty)

            Divider()

            Button {
                model.openOutputs()
            } label: {
                Label("Show Sanitized Files", systemImage: "folder")
            }
            .disabled(model.lastOutputFiles.isEmpty)

            Button {
                model.openLog()
            } label: {
                Label("Show JSON Log", systemImage: "doc.text.magnifyingglass")
            }
            .disabled(model.lastLogURL == nil)

            Divider()

            VStack(alignment: .leading, spacing: 3) {
                Text("Developer")
                    .font(.caption.bold())
                Text(AppInfo.creatorName)
                    .font(.caption)
                Text(AppInfo.creatorEmail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            Menu {
                Button {
                    model.copyDeveloperEmail()
                } label: {
                    Label("Copy Email Address", systemImage: "doc.on.doc")
                }

                Button {
                    model.openFeedbackMailApp()
                } label: {
                    Label("Default Mail App", systemImage: "envelope")
                }

                Menu {
                    Button {
                        model.openFeedbackWebmail(.gmail)
                    } label: {
                        Label("Gmail", systemImage: "globe")
                    }

                    Button {
                        model.openFeedbackWebmail(.outlook)
                    } label: {
                        Label("Outlook Web", systemImage: "globe")
                    }
                } label: {
                    Label("Webmail", systemImage: "globe")
                }

                let installedApps = FeedbackService.installedMailApps()
                if !installedApps.isEmpty {
                    Menu {
                        ForEach(installedApps) { app in
                            Button {
                                model.openFeedbackApp(app)
                            } label: {
                                Label(app.name, systemImage: "app")
                            }
                        }
                    } label: {
                        Label("Installed Mail Handlers", systemImage: "macwindow")
                    }
                }

                Button {
                    model.shareFeedbackWithAttachments()
                } label: {
                    Label("Default Email App with Files...", systemImage: "paperclip")
                }
            } label: {
                Label("Share Feedback", systemImage: "envelope")
            }

            Divider()

            Button("Quit") {
                model.quit()
            }
            .keyboardShortcut("q")
        }
    }
}

struct PIISanitizerAppView: View {
    @ObservedObject var model: PIISanitizerMenuModel

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    selectionSection
                    runSection
                    resultsSection
                    developerSection
                }
                .padding(22)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(minWidth: 760, minHeight: 560)
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 34))
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 3) {
                Text("Offline PII Sanitizer")
                    .font(.title2.bold())
                Text("Sanitize CSV, Excel, and PowerPoint files locally. Originals are not overwritten.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if model.isWorking {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding(22)
    }

    private var selectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Input and Output")
                .font(.headline)

            HStack(spacing: 10) {
                Button {
                    model.chooseFiles()
                } label: {
                    Label("Choose Files", systemImage: "doc.badge.plus")
                }

                Button {
                    model.chooseInputFolder()
                } label: {
                    Label("Choose Folder", systemImage: "folder")
                }

                Button {
                    model.chooseOutputFolder()
                } label: {
                    Label("Choose Output Folder", systemImage: "folder.badge.plus")
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                infoRow("Selected", model.selectedFiles.isEmpty ? "No files or folders selected." : selectedInputText)
                infoRow("Output", model.outputFolder?.path ?? "Default output beside each file, or Sanitized_Output for folder runs.")
            }
            .padding(12)
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private var runSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Run")
                .font(.headline)

            HStack(spacing: 10) {
                Button {
                    model.sanitize()
                } label: {
                    Label(model.isWorking ? "Sanitizing..." : "Run Sanitizer", systemImage: "shield")
                }
                .keyboardShortcut(.defaultAction)
                .disabled(model.isWorking || model.selectedFiles.isEmpty)

                Button {
                    model.openOutputs()
                } label: {
                    Label("Show Sanitized Files", systemImage: "folder")
                }
                .disabled(model.lastOutputFiles.isEmpty)

                Button {
                    model.openLog()
                } label: {
                    Label("Show JSON Log", systemImage: "doc.text.magnifyingglass")
                }
                .disabled(model.lastLogURL == nil)
            }

            Text(model.status)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, minHeight: 130, alignment: .topLeading)
                .padding(12)
                .background(Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Last Run")
                .font(.headline)

            if model.lastOutputFiles.isEmpty && model.lastLogURL == nil && model.detectionsByType.isEmpty {
                Text("No sanitizer run completed yet.")
                    .foregroundStyle(.secondary)
            } else {
                HStack(alignment: .top, spacing: 16) {
                    summaryTile("Output Files", "\(model.lastOutputFiles.count)")
                    summaryTile("Detection Types", "\(model.detectionsByType.count)")
                    summaryTile("Log", model.lastLogURL?.lastPathComponent ?? "None")
                }

                if !model.detectionsByType.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(model.detectionsByType.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                            HStack {
                                Text(key)
                                    .font(.system(.body, design: .monospaced))
                                Spacer()
                                Text("\(value)")
                                    .font(.system(.body, design: .monospaced).bold())
                            }
                        }
                    }
                    .padding(12)
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    private var developerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Developer")
                .font(.headline)

            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(AppInfo.creatorName)
                    Text(AppInfo.creatorEmail)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }

                Spacer()

                Menu {
                    Button {
                        model.copyDeveloperEmail()
                    } label: {
                        Label("Copy Email Address", systemImage: "doc.on.doc")
                    }

                    Button {
                        model.openFeedbackMailApp()
                    } label: {
                        Label("Default Mail App", systemImage: "envelope")
                    }

                    Menu {
                        Button {
                            model.openFeedbackWebmail(.gmail)
                        } label: {
                            Label("Gmail", systemImage: "globe")
                        }

                        Button {
                            model.openFeedbackWebmail(.outlook)
                        } label: {
                            Label("Outlook Web", systemImage: "globe")
                        }
                    } label: {
                        Label("Webmail", systemImage: "globe")
                    }

                    let installedApps = FeedbackService.installedMailApps()
                    if !installedApps.isEmpty {
                        Menu {
                            ForEach(installedApps) { app in
                                Button {
                                    model.openFeedbackApp(app)
                                } label: {
                                    Label(app.name, systemImage: "app")
                                }
                            }
                        } label: {
                            Label("Installed Mail Handlers", systemImage: "macwindow")
                        }
                    }

                    Button {
                        model.shareFeedbackWithAttachments()
                    } label: {
                        Label("Default Email App with Files...", systemImage: "paperclip")
                    }
                } label: {
                    Label("Share Feedback", systemImage: "envelope")
                }
            }
            .padding(12)
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private var selectedInputText: String {
        model.selectedFiles.map(\.path).prefix(6).joined(separator: "\n") +
            (model.selectedFiles.count > 6 ? "\n...and \(model.selectedFiles.count - 6) more" : "")
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.subheadline.bold())
                .frame(width: 90, alignment: .leading)
            Text(value)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func summaryTile(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .lineLimit(2)
                .truncationMode(.middle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct InstalledMailApp: Identifiable {
    let id: String
    let name: String
    let url: URL
}

enum FeedbackWebmailProvider {
    case gmail
    case outlook

    var label: String {
        switch self {
        case .gmail:
            return "Gmail"
        case .outlook:
            return "Outlook Web"
        }
    }
}

enum FeedbackService {
    static func installedMailApps() -> [InstalledMailApp] {
        guard let mailtoURL = feedbackMailtoURL() else { return [] }
        return NSWorkspace.shared.urlsForApplications(toOpen: mailtoURL)
            .map { appURL in
                InstalledMailApp(
                    id: appURL.path,
                    name: appName(for: appURL),
                    url: appURL
                )
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    static func openDefaultMailApp() throws {
        guard let url = feedbackMailtoURL() else {
            throw TransformError.internalError("Could not create a feedback email link.")
        }
        guard NSWorkspace.shared.open(url) else {
            throw TransformError.internalError("Could not open the default mail handler.")
        }
    }

    static func openMailHandler(_ app: InstalledMailApp) throws {
        guard let url = feedbackMailtoURL() else {
            throw TransformError.internalError("Could not create a feedback email link.")
        }
        let configuration = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.open([url], withApplicationAt: app.url, configuration: configuration)
    }

    static func openWebmail(_ provider: FeedbackWebmailProvider) throws {
        let url: URL?
        switch provider {
        case .gmail:
            var components = URLComponents(string: "https://mail.google.com/mail/u/0/")
            components?.queryItems = [
                URLQueryItem(name: "view", value: "cm"),
                URLQueryItem(name: "fs", value: "1"),
                URLQueryItem(name: "to", value: AppInfo.creatorEmail),
                URLQueryItem(name: "su", value: feedbackSubject()),
                URLQueryItem(name: "body", value: feedbackBody())
            ]
            url = components?.url
        case .outlook:
            var components = URLComponents(string: "https://outlook.office.com/mail/deeplink/compose")
            components?.queryItems = [
                URLQueryItem(name: "to", value: AppInfo.creatorEmail),
                URLQueryItem(name: "subject", value: feedbackSubject()),
                URLQueryItem(name: "body", value: feedbackBody())
            ]
            url = components?.url
        }

        guard let url else {
            throw TransformError.internalError("Could not create the \(provider.label) feedback link.")
        }
        guard NSWorkspace.shared.open(url) else {
            throw TransformError.internalError("Could not open \(provider.label).")
        }
    }

    static func composeEmailWithAttachments(_ attachments: [URL]) throws {
        guard let service = NSSharingService(named: .composeEmail) else {
            throw TransformError.internalError("No email sharing service is available on this Mac.")
        }

        service.recipients = [AppInfo.creatorEmail]
        service.subject = feedbackSubject()
        service.perform(withItems: [feedbackBody()] + attachments)
    }

    private static func feedbackMailtoURL() -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = AppInfo.creatorEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: feedbackSubject()),
            URLQueryItem(name: "body", value: feedbackBody())
        ]
        return components.url
    }

    private static func feedbackSubject() -> String {
        "\(AppInfo.appName) Feedback"
    }

    private static func feedbackBody() -> String {
        """
        Hi \(AppInfo.creatorName),

        I would like to share feedback about \(AppInfo.appName).

        Feedback:

        Steps to reproduce, if reporting a bug:

        Expected result:

        Actual result:

        App version: \(AppInfo.currentVersion)
        """
    }

    private static func appName(for appURL: URL) -> String {
        if let bundle = Bundle(url: appURL),
           let displayName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String {
            return displayName
        }
        if let bundle = Bundle(url: appURL),
           let name = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String {
            return name
        }
        return appURL.deletingPathExtension().lastPathComponent
    }
}
