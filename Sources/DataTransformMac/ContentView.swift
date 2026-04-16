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
    @State private var selectedInputURLs: [URL] = []
    @State private var lastOutputURL: URL?
    @State private var isTransformingFile = false
    @State private var isPreviewing = false
    @State private var isCheckingUpdates = false
    @State private var updateMessage = "Update status not checked yet."
    @State private var latestReleaseURL: URL?
    @State private var latestReleaseVersion: String?
    @State private var inlineJSONInput = ""
    @State private var inlineJSONOutput = ""
    @State private var suggestedInlineFixInput: String?
    @State private var inlineFormatterMessage = "Paste JSON and click Format."
    @State private var inlineFormatterIsError = false
    @State private var previewOutput = ""
    @State private var previewReport = "Select a file and click Preview to inspect output before saving."
    @State private var showHelp = false
    @State private var showReleaseNotes = false
    @State private var copyResultPulse = false
    @State private var autoFixPulse = false
    @StateObject private var usageStats = UsageStats()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: backgroundColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                GeometryReader { geometry in
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Offline file conversion and formatting. Your files stay local and no online tools are needed.")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(primaryTextColor)

                        HStack(alignment: .top, spacing: 12) {
                            appearanceCard
                            updatesCard
                        }

                        Picker("Action", selection: $selectedAction) {
                            ForEach(TransformAction.allCases) { action in
                                Text(action.label).tag(action)
                            }
                        }
                        .pickerStyle(.segmented)

                        Text(selectedAction.description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        inlineFormatterCard(editorHeight: max(170, min(250, geometry.size.height * 0.25)))

                        dropArea
                        actionButtons
                        previewCard(editorHeight: max(150, min(220, geometry.size.height * 0.22)))
                        HStack(alignment: .top, spacing: 12) {
                            statsSection
                            developerInfoCard
                        }
                        statusSection
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(20)
                }
                .frame(minHeight: 560)
            }
            .frame(minWidth: 760, minHeight: 560)
            .task {
                await checkForUpdates(manual: false)
            }
            .onReceive(updateCheckTimer) { _ in
                Task {
                    await checkForUpdates(manual: false)
                }
            }
            .sheet(isPresented: $showHelp) {
                helpView
            }
            .sheet(isPresented: $showReleaseNotes) {
                releaseNotesView
            }
        }
        .preferredColorScheme(appearanceMode.colorScheme)
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
        .frame(maxWidth: .infinity, alignment: .leading)
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var dropArea: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Input File")
                .font(.headline)
            Text(inputSelectionDescription)
                .font(.subheadline)
                .foregroundStyle(selectedInputURLs.isEmpty ? .secondary : .primary)
                .lineLimit(3)
            if selectedInputURLs.count > 1 {
                Text("Batch mode: \(selectedInputURLs.count) files will be transformed into a folder you choose.")
                    .font(.caption)
                    .foregroundStyle(brandAccent)
            }
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

    private func inlineFormatterCard(editorHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Quick Paste Transformer")
                        .font(.headline)
                    Text(inlineTransformerDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                HStack(spacing: 8) {
                    workflowButton(
                        title: inlinePrimaryButtonTitle,
                        icon: "wand.and.stars",
                        highlighted: !inlineJSONInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                        enabled: !inlineJSONInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ) {
                        transformInlineInput()
                    }
                    workflowButton(
                        title: "Copy Result",
                        icon: "doc.on.doc",
                        highlighted: !inlineJSONOutput.isEmpty,
                        enabled: !inlineJSONOutput.isEmpty,
                        pulsing: copyResultPulse
                    ) {
                        copyInlineJSONResult()
                    }
                    workflowButton(
                        title: "Clear",
                        icon: "xmark",
                        highlighted: false,
                        enabled: true
                    ) {
                        clearInlineFormatter()
                    }
                }
            }

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 12) {
                    inlineEditor(
                        title: inlineInputTitle,
                        text: $inlineJSONInput,
                        placeholder: inlineInputPlaceholder,
                        editorHeight: editorHeight
                    )
                    inlineEditor(
                        title: "Transformed Output",
                        text: $inlineJSONOutput,
                        placeholder: "Transformed output will appear here.",
                        isOutput: true,
                        editorHeight: editorHeight
                    )
                }
                VStack(alignment: .leading, spacing: 12) {
                    inlineEditor(
                        title: inlineInputTitle,
                        text: $inlineJSONInput,
                        placeholder: inlineInputPlaceholder,
                        editorHeight: editorHeight
                    )
                    inlineEditor(
                        title: "Transformed Output",
                        text: $inlineJSONOutput,
                        placeholder: "Transformed output will appear here.",
                        isOutput: true,
                        editorHeight: editorHeight
                    )
                }
            }

            if let suggestedInlineFixInput {
                HStack(spacing: 10) {
                Text("The pasted JSON looks invalid. I can try to auto-fix common syntax issues for you.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    workflowButton(
                        title: "Auto-Fix and Format",
                        icon: "wrench.and.screwdriver",
                        highlighted: true,
                        enabled: true,
                        pulsing: autoFixPulse,
                        accentColor: Color(red: 0.95, green: 0.50, blue: 0.14)
                    ) {
                        applyInlineFixAndFormat(suggestedInput: suggestedInlineFixInput)
                    }
                }
            }

            HStack(spacing: 8) {
                Image(systemName: inlineFormatterIsError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    .foregroundStyle(inlineFormatterIsError ? Color.orange : brandAccent)
                Text(inlineFormatterMessage)
                    .font(.subheadline)
                    .foregroundStyle(inlineFormatterIsError ? Color.orange : .secondary)
            }
        }
        .padding(14)
        .background(cardBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func inlineEditor(title: String, text: Binding<String>, placeholder: String, isOutput: Bool = false, editorHeight: CGFloat = 220) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                if isOutput && !text.wrappedValue.isEmpty {
                    Text("Click to copy")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            ZStack(alignment: .topLeading) {
                if text.wrappedValue.isEmpty {
                    Text(placeholder)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 12)
                }

                if isOutput {
                    ScrollView {
                        Text(text.wrappedValue)
                            .font(.system(.body, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 12)
                    }
                } else {
                    TextEditor(text: text)
                        .font(.system(.body, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .padding(6)
                        .background(Color.clear)
                }
            }
            .frame(minHeight: editorHeight)
            .background(effectiveColorScheme == .dark ? Color.black.opacity(0.18) : Color.white.opacity(0.92))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(editorBorderColor(isOutput: isOutput), lineWidth: copyResultPulse && isOutput ? 2 : 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 10))
            .onTapGesture {
                if isOutput {
                    copyInlineJSONResult()
                }
            }
            .animation(.easeInOut(duration: 0.35), value: copyResultPulse)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func previewCard(editorHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Preview and Validation Summary")
                        .font(.headline)
                    Text("Preview a single selected file before saving. Batch mode writes all files to a folder after validation.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if !previewOutput.isEmpty {
                    workflowButton(
                        title: "Copy Preview",
                        icon: "doc.on.doc",
                        highlighted: true,
                        enabled: true
                    ) {
                        copyText(previewOutput, message: "Preview copied to clipboard.")
                    }
                }
            }

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 12) {
                    reportBox
                    previewOutputBox(editorHeight: editorHeight)
                }
                VStack(alignment: .leading, spacing: 12) {
                    reportBox
                    previewOutputBox(editorHeight: editorHeight)
                }
            }
        }
        .padding(14)
        .background(cardBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var reportBox: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Validation")
                .font(.headline)
            ScrollView {
                Text(previewReport)
                    .font(.system(.subheadline, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(minHeight: 130)
            .padding(10)
            .background(effectiveColorScheme == .dark ? Color.black.opacity(0.18) : Color.white.opacity(0.92))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func previewOutputBox(editorHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Output Preview")
                .font(.headline)
            ScrollView {
                Text(previewOutput.isEmpty ? "Preview output will appear here." : previewOutput)
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(previewOutput.isEmpty ? .secondary : primaryTextColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(minHeight: editorHeight)
            .padding(10)
            .background(effectiveColorScheme == .dark ? Color.black.opacity(0.18) : Color.white.opacity(0.92))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var actionButtons: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                chooseButton
                previewButton
                runButton
                outputButton
                feedbackButtons
            }
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    chooseButton
                    previewButton
                    runButton
                    outputButton
                }
                HStack(spacing: 10) {
                    Button {
                        showHelp = true
                    } label: {
                        Label("Help / Examples", systemImage: "questionmark.circle")
                    }
                    Button {
                        showReleaseNotes = true
                    } label: {
                        Label("What's New", systemImage: "sparkles")
                    }
                }
                feedbackButtons
            }
        }
    }

    private var chooseButton: some View {
        workflowButton(
            title: "Choose File",
            icon: "doc.badge.plus",
            highlighted: selectedInputURLs.isEmpty,
            enabled: true
        ) {
            pickInputFile()
        }
    }

    private var previewButton: some View {
        workflowButton(
            title: isPreviewing ? "Previewing..." : "Preview",
            icon: "eye",
            highlighted: !selectedInputURLs.isEmpty && previewOutput.isEmpty,
            enabled: !selectedInputURLs.isEmpty && !isPreviewing && selectedInputURLs.count == 1
        ) {
            previewSelectedAction()
        }
    }

    private var runButton: some View {
        workflowButton(
            title: isTransformingFile ? "Working..." : "Run and Save",
            icon: "play.fill",
            highlighted: !selectedInputURLs.isEmpty && lastOutputURL == nil,
            enabled: !isTransformingFile
        ) {
            runSelectedAction()
        }
        .keyboardShortcut(.defaultAction)
    }

    private var outputButton: some View {
        workflowButton(
            title: "Show Output Folder",
            icon: "folder",
            highlighted: lastOutputURL != nil,
            enabled: lastOutputURL != nil
        ) {
            openOutputFolder()
        }
    }

    private var feedbackButtons: some View {
        HStack(spacing: 10) {
            Button {
                openFeedbackEmail()
            } label: {
                Label("Mail App", systemImage: "envelope")
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

            Button("Clear Status") {
                statusMessage = "Status cleared."
                isError = false
            }

            Button {
                showHelp = true
            } label: {
                Label("Help", systemImage: "questionmark.circle")
            }

            Button {
                showReleaseNotes = true
            } label: {
                Label("What's New", systemImage: "sparkles")
            }
        }
    }

    private func workflowButton(
        title: String,
        icon: String,
        highlighted: Bool,
        enabled: Bool,
        pulsing: Bool = false,
        accentColor: Color? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .fontWeight(highlighted ? .semibold : .regular)
                .foregroundStyle((highlighted || pulsing) ? Color.white : primaryTextColor)
                .frame(minWidth: 120, minHeight: 38)
                .padding(.horizontal, 12)
                .background(buttonBackgroundColor(highlighted: highlighted, pulsing: pulsing, accentColor: accentColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(buttonBorderColor(highlighted: highlighted, pulsing: pulsing, accentColor: accentColor), lineWidth: pulsing ? 2 : 1)
                )
                .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .scaleEffect(pulsing ? 1.06 : 1.0)
        .shadow(color: pulsing ? brandAccent.opacity(0.45) : .clear, radius: 12)
        .disabled(!enabled)
        .opacity(enabled ? 1.0 : 0.55)
        .animation(.easeInOut(duration: 0.22), value: pulsing)
    }

    private var statsSection: some View {
        HStack(spacing: 12) {
            statCard(title: "CSV -> JSON", value: usageStats.count(for: .csvToJSON))
            statCard(title: "JSON -> CSV", value: usageStats.count(for: .jsonToCSV))
            statCard(title: "Format JSON", value: usageStats.count(for: .formatJSONByLine))
            statCard(title: "Flatten JSON", value: usageStats.count(for: .flattenJSON))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
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
    }

    private var developerInfoCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Developer Information")
                .font(.headline)
            Text("Name: \(AppInfo.creatorName)")
                .font(.subheadline)
            Text("Email: \(AppInfo.creatorEmail)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(width: 260, alignment: .leading)
        .background(cardBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var appearanceMode: AppearanceMode {
        AppearanceMode(rawValue: appearanceModeRaw) ?? .system
    }

    private var inputSelectionDescription: String {
        if selectedInputURLs.count > 1 {
            return selectedInputURLs.map(\.lastPathComponent).prefix(4).joined(separator: ", ") +
                (selectedInputURLs.count > 4 ? " and \(selectedInputURLs.count - 4) more" : "")
        }
        return selectedInputURL?.path ?? "Drag and drop one or more files here, or use Choose File."
    }

    private var inlineTransformerDescription: String {
        switch selectedAction {
        case .csvToJSON:
            return "Paste CSV on the left and convert it to nicely formatted flat JSON on the right."
        case .jsonToCSV:
            return "Paste flat JSON on the left and convert it to CSV on the right."
        case .formatJSONByLine:
            return "Paste a JSON payload on the left and get formatted output instantly on the right."
        case .flattenJSON:
            return "Paste nested JSON on the left and flatten it into dot-notated JSON on the right."
        }
    }

    private var inlineInputTitle: String {
        selectedAction == .csvToJSON ? "Paste CSV" : "Paste JSON"
    }

    private var inlineInputPlaceholder: String {
        switch selectedAction {
        case .csvToJSON:
            return "policyId,status\n12345,active"
        case .jsonToCSV, .formatJSONByLine:
            return "{\n  \"policyId\": \"12345\"\n}"
        case .flattenJSON:
            return "{\n  \"policy\": {\n    \"id\": \"12345\"\n  }\n}"
        }
    }

    private var inlinePrimaryButtonTitle: String {
        switch selectedAction {
        case .csvToJSON:
            return "Convert"
        case .jsonToCSV:
            return "Convert"
        case .formatJSONByLine:
            return "Format"
        case .flattenJSON:
            return "Flatten"
        }
    }

    private var effectiveColorScheme: ColorScheme {
        appearanceMode.colorScheme ?? activeColorScheme
    }

    private var backgroundColors: [Color] {
        effectiveColorScheme == .dark ? [brandDarkStart, brandDarkEnd] : [brandLightStart, brandLightEnd]
    }

    private var cardBackgroundColor: Color {
        effectiveColorScheme == .dark ? .white.opacity(0.08) : .white.opacity(0.86)
    }

    private var primaryTextColor: Color {
        effectiveColorScheme == .dark ? .white : Color(red: 0.10, green: 0.16, blue: 0.24)
    }

    private func buttonBackgroundColor(highlighted: Bool, pulsing: Bool, accentColor: Color?) -> Color {
        let activeColor = accentColor ?? brandAccent
        if pulsing {
            return activeColor
        }
        return highlighted ? activeColor : cardBackgroundColor
    }

    private func buttonBorderColor(highlighted: Bool, pulsing: Bool, accentColor: Color?) -> Color {
        let activeColor = accentColor ?? brandAccent
        if pulsing {
            return Color.white.opacity(0.9)
        }
        return highlighted ? activeColor : activeColor.opacity(0.25)
    }

    private func editorBorderColor(isOutput: Bool) -> Color {
        if isOutput && copyResultPulse {
            return brandAccent
        }
        return brandAccent.opacity(0.22)
    }

    @MainActor
    private func transformInlineInput() {
        let trimmedInput = inlineJSONInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else {
            inlineJSONOutput = ""
            suggestedInlineFixInput = nil
            autoFixPulse = false
            inlineFormatterMessage = "Paste input first, then click \(inlinePrimaryButtonTitle)."
            inlineFormatterIsError = true
            statusMessage = inlineFormatterMessage
            isError = true
            return
        }

        do {
            let input = selectedAction == .csvToJSON ? inlineJSONInput : JSONRepairService.sanitize(inlineJSONInput)
            let result = try DataTransformService.runDetailed(action: selectedAction, rawText: input)
            inlineJSONOutput = result.output
            previewReport = result.report
            previewOutput = String(result.output.prefix(6_000))
            suggestedInlineFixInput = nil
            autoFixPulse = false
            inlineFormatterMessage = "Inline \(selectedAction.label) completed. Output is ready to copy."
            inlineFormatterIsError = false
            statusMessage = inlineFormatterMessage
            isError = false
            triggerCopyResultPulse()
        } catch {
            inlineJSONOutput = ""
            suggestedInlineFixInput = selectedAction == .csvToJSON ? nil : JSONRepairService.suggestedFix(for: inlineJSONInput)
            if suggestedInlineFixInput != nil {
                inlineFormatterMessage = "\(error.localizedDescription) Auto-Fix and Format is available."
                statusMessage = inlineFormatterMessage
                triggerAutoFixPulse()
            } else {
                inlineFormatterMessage = "\(friendlyErrorMessage(from: error))"
                statusMessage = inlineFormatterMessage
                autoFixPulse = false
            }
            inlineFormatterIsError = true
            isError = true
        }
    }

    @MainActor
    private func copyInlineJSONResult() {
        guard !inlineJSONOutput.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(inlineJSONOutput, forType: .string)
        inlineFormatterMessage = "Transformed output copied to clipboard."
        inlineFormatterIsError = false
        statusMessage = "Transformed output copied to clipboard."
        isError = false
    }

    @MainActor
    private func clearInlineFormatter() {
        inlineJSONInput = ""
        inlineJSONOutput = ""
        suggestedInlineFixInput = nil
        inlineFormatterMessage = "Paste JSON and click Format."
        inlineFormatterIsError = false
        copyResultPulse = false
        autoFixPulse = false
        statusMessage = "Inline formatter cleared."
        isError = false
    }

    @MainActor
    private func applyInlineFixAndFormat(suggestedInput: String) {
        inlineJSONInput = suggestedInput
        transformInlineInput()
    }

    @MainActor
    private func previewSelectedAction() {
        guard !isPreviewing else { return }

        do {
            let inputURLs = try resolveInputFiles()
            guard inputURLs.count == 1, let inputURL = inputURLs.first else {
                previewReport = "Preview is available for one file at a time. Use Run and Save for batch mode."
                previewOutput = ""
                return
            }

            isPreviewing = true
            statusMessage = "Generating preview for \(inputURL.lastPathComponent)..."
            isError = false

            Task {
                do {
                    let action = selectedAction
                    let result = try await Task.detached(priority: .userInitiated) {
                        try DataTransformService.runDetailed(action: action, inputURL: inputURL)
                    }.value
                    await MainActor.run {
                        previewOutput = String(result.output.prefix(6_000))
                        previewReport = result.report + (result.output.count > 6_000 ? "\n\nPreview truncated to first 6,000 characters." : "")
                        statusMessage = "Preview ready. Review the validation summary, then click Run and Save."
                        isError = false
                        isPreviewing = false
                    }
                } catch {
                    await MainActor.run {
                        previewOutput = ""
                        previewReport = friendlyErrorMessage(from: error)
                        statusMessage = previewReport
                        isError = true
                        isPreviewing = false
                    }
                }
            }
        } catch {
            previewOutput = ""
            previewReport = friendlyErrorMessage(from: error)
            statusMessage = previewReport
            isError = true
        }
    }

    @MainActor
    private func clearPreview() {
        previewOutput = ""
        previewReport = "Select a file and click Preview to inspect output before saving."
    }

    @MainActor
    private func copyText(_ text: String, message: String) {
        guard !text.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        statusMessage = message
        isError = false
    }

    private func friendlyErrorMessage(from error: Error) -> String {
        let message = error.localizedDescription
        if message.contains("3840") || message.localizedCaseInsensitiveContains("json") {
            return "\(message)\n\nSuggestion: check for missing commas, extra trailing commas, unclosed quotes, or pasted HTML-encoded quotes such as &#34;."
        }
        if message.localizedCaseInsensitiveContains("nested") || message.localizedCaseInsensitiveContains("Only flat JSON") {
            return "\(message)\n\nSuggestion: choose Flatten JSON if you want dot-notated flat output."
        }
        if message.localizedCaseInsensitiveContains("CSV") {
            return "\(message)\n\nSuggestion: check for unclosed quotes, missing headers, or duplicate column names."
        }
        return message
    }

    @MainActor
    private func triggerCopyResultPulse() {
        copyResultPulse = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            copyResultPulse = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                copyResultPulse = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    copyResultPulse = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
                        copyResultPulse = false
                    }
                }
            }
        }
    }

    @MainActor
    private func triggerAutoFixPulse() {
        autoFixPulse = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            autoFixPulse = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                autoFixPulse = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                    autoFixPulse = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                        autoFixPulse = false
                    }
                }
            }
        }
    }

    @MainActor
    private func pickInputFile() {
        do {
            let urls = try FilePanel.pickFiles(allowedExtensions: selectedAction.allowedInputExtensions)
            selectedInputURLs = urls
            selectedInputURL = urls.first
            lastOutputURL = nil
            clearPreview()
            statusMessage = urls.count == 1 ? "Selected input:\n\(urls[0].path)" : "Selected \(urls.count) files for batch \(selectedAction.label)."
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
        let fileProviders = providers.filter {
            $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
        }
        guard !fileProviders.isEmpty else {
            return false
        }

        let group = DispatchGroup()
        let collector = DroppedURLCollector()

        for provider in fileProviders {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                defer { group.leave() }
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil)
                else {
                    return
                }
                collector.append(url)
            }
        }

        group.notify(queue: .main) {
            let droppedURLs = collector.urls()
            let validURLs = droppedURLs.filter { url in
                selectedAction.allowedInputExtensions.map { $0.lowercased() }.contains(url.pathExtension.lowercased())
            }
            guard !validURLs.isEmpty else {
                self.statusMessage = "Dropped files do not match \(selectedAction.label)."
                self.isError = true
                return
            }
            self.selectedInputURLs = validURLs
            self.selectedInputURL = validURLs.first
            self.lastOutputURL = nil
            self.clearPreview()
            DispatchQueue.main.async {
                self.statusMessage = validURLs.count == 1 ? "Selected input:\n\(validURLs[0].path)" : "Selected \(validURLs.count) files for batch \(selectedAction.label)."
                self.isError = false
            }
        }
        return true
    }

    @MainActor
    private func runSelectedAction() {
        guard !isTransformingFile else { return }

        do {
            let inputURLs = try resolveInputFiles()
            let action = selectedAction
            isTransformingFile = true
            statusMessage = inputURLs.count == 1 ? "Working on \(inputURLs[0].lastPathComponent)..." : "Working on \(inputURLs.count) files..."
            isError = false

            Task {
                do {
                    if inputURLs.count == 1, let inputURL = inputURLs.first {
                        let result = try await Task.detached(priority: .userInitiated) {
                            try DataTransformService.runDetailed(action: action, inputURL: inputURL)
                        }.value

                        await MainActor.run {
                            previewOutput = String(result.output.prefix(6_000))
                            previewReport = result.report
                        }

                        let outputURL = try await MainActor.run {
                            try FilePanel.pickSaveLocation(
                                suggestedName: action.suggestedOutputFileName(from: inputURL),
                                allowedExtension: action.outputExtension
                            )
                        }

                        try await Task.detached(priority: .userInitiated) {
                            try result.output.write(to: outputURL, atomically: true, encoding: .utf8)
                        }.value

                        await MainActor.run {
                            usageStats.increment(action: action)
                            lastOutputURL = outputURL
                            statusMessage = "Done. Output saved to:\n\(outputURL.path)\n\n\(result.report)"
                            isError = false
                            isTransformingFile = false
                        }
                    } else {
                        let outputFolder = try await MainActor.run {
                            try FilePanel.pickOutputFolder()
                        }

                        let batchResult = try await Task.detached(priority: .userInitiated) {
                            try processBatch(inputURLs: inputURLs, action: action, outputFolder: outputFolder)
                        }.value

                        await MainActor.run {
                            usageStats.increment(action: action)
                            lastOutputURL = batchResult.lastOutputURL ?? outputFolder
                            previewReport = batchResult.report
                            previewOutput = ""
                            statusMessage = batchResult.report
                            isError = !batchResult.failures.isEmpty
                            isTransformingFile = false
                        }
                    }
                } catch {
                    await MainActor.run {
                        if (error as NSError).code == NSUserCancelledError {
                            statusMessage = "Operation canceled."
                            isError = false
                        } else {
                            statusMessage = error.localizedDescription
                            isError = true
                        }
                        isTransformingFile = false
                    }
                }
            }
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
    private func resolveInputFiles() throws -> [URL] {
        if !selectedInputURLs.isEmpty {
            try selectedInputURLs.forEach(validateInputFileExtension)
            return selectedInputURLs
        }
        let picked = try FilePanel.pickFiles(allowedExtensions: selectedAction.allowedInputExtensions)
        try picked.forEach(validateInputFileExtension)
        selectedInputURLs = picked
        selectedInputURL = picked.first
        lastOutputURL = nil
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

    private var helpView: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Help and Examples")
                    .font(.title2.bold())
                Spacer()
                Button("Close") { showHelp = false }
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    helpSection(
                        title: "CSV -> JSON",
                        body: "Use this when you have a CSV with headers. The app creates flat JSON records and warns about duplicate or blank headers."
                    )
                    helpCode("policyId,status\n12345,active")
                    helpSection(
                        title: "JSON -> CSV",
                        body: "Use this for a single flat JSON object or an array of flat JSON objects. Nested fields are rejected so the CSV remains predictable."
                    )
                    helpCode("{\n  \"policyId\": \"12345\",\n  \"status\": \"active\"\n}")
                    helpSection(
                        title: "Format JSON",
                        body: "Use this when the JSON is already flat and you want a readable, sorted, copyable result."
                    )
                    helpSection(
                        title: "Flatten JSON",
                        body: "Use this when JSON has nested objects. Nested keys become dot-notated fields such as policy.id."
                    )
                    helpCode("{\n  \"policy\": {\n    \"id\": \"12345\"\n  }\n}\n\nbecomes\n\n{\n  \"policy.id\" : \"12345\"\n}")
                    helpSection(
                        title: "Batch Mode",
                        body: "Choose or drop multiple files, then click Run and Save. The app asks for an output folder and writes one transformed file per input file."
                    )
                    helpSection(
                        title: "Privacy",
                        body: "File contents are transformed locally. Update checks use GitHub only for release metadata, and feedback buttons use your chosen mail/browser flow."
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(22)
        .frame(minWidth: 680, minHeight: 560)
    }

    private var releaseNotesView: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("What's New")
                    .font(.title2.bold())
                Spacer()
                Button("Close") { showReleaseNotes = false }
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    helpSection(
                        title: "v1.0.2",
                        body: "Added batch conversion, preview before save, inline paste conversion for every action, validation summaries, better error guidance, help/examples, duplicate CSV header warnings, and explicit Flatten JSON."
                    )
                    helpSection(
                        title: "v1.0.1",
                        body: "Improved update checks, safer JSON auto-fix validation, better responsiveness for large files, smaller-window layout behavior, and clearer privacy wording."
                    )
                    helpSection(
                        title: "v1.0.0",
                        body: "Initial app release with CSV to JSON, JSON to CSV, JSON formatting, drag/drop input, feedback links, usage stats, dark mode, and GitHub update checks."
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(22)
        .frame(minWidth: 620, minHeight: 420)
    }

    private func helpSection(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            Text(body)
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    private func helpCode(_ text: String) -> some View {
        Text(text)
            .font(.system(.body, design: .monospaced))
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(effectiveColorScheme == .dark ? Color.black.opacity(0.18) : Color.white.opacity(0.88))
            .clipShape(RoundedRectangle(cornerRadius: 10))
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

private struct BatchTransformResult: Sendable {
    let report: String
    let failures: [String]
    let lastOutputURL: URL?
}

private final class DroppedURLCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [URL] = []

    func append(_ url: URL) {
        lock.lock()
        storage.append(url)
        lock.unlock()
    }

    func urls() -> [URL] {
        lock.lock()
        let urls = storage
        lock.unlock()
        return urls
    }
}

private func processBatch(inputURLs: [URL], action: TransformAction, outputFolder: URL) throws -> BatchTransformResult {
    var successCount = 0
    var failures: [String] = []
    var reports: [String] = []
    var lastOutputURL: URL?

    for inputURL in inputURLs {
        do {
            let result = try DataTransformService.runDetailed(action: action, inputURL: inputURL)
            let outputURL = outputFolder.appendingPathComponent(action.suggestedOutputFileName(from: inputURL))
            try result.output.write(to: outputURL, atomically: true, encoding: .utf8)
            successCount += 1
            lastOutputURL = outputURL
            reports.append("\(inputURL.lastPathComponent): saved \(outputURL.lastPathComponent)")
            if !result.warnings.isEmpty {
                reports.append(contentsOf: result.warnings.map { "  Warning: \($0)" })
            }
        } catch {
            failures.append("\(inputURL.lastPathComponent): \(error.localizedDescription)")
        }
    }

    var lines = [
        "Batch \(action.label) complete.",
        "Files selected: \(inputURLs.count)",
        "Succeeded: \(successCount)",
        "Failed: \(failures.count)",
        "Output folder: \(outputFolder.path)"
    ]

    if !reports.isEmpty {
        lines.append("")
        lines.append("Saved files:")
        lines.append(contentsOf: reports.map { "- \($0)" })
    }

    if !failures.isEmpty {
        lines.append("")
        lines.append("Failures:")
        lines.append(contentsOf: failures.map { "- \($0)" })
    }

    return BatchTransformResult(report: lines.joined(separator: "\n"), failures: failures, lastOutputURL: lastOutputURL)
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
