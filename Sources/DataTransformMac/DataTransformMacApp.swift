import SwiftUI

@main
struct FileTransformerAndFormatterApp: App {
    @StateObject private var model = PIISanitizerMenuModel()

    var body: some Scene {
        WindowGroup("Offline PII Sanitizer", id: "main") {
            PIISanitizerAppView(model: model)
        }
        .defaultSize(width: 920, height: 680)

        MenuBarExtra {
            PIISanitizerMenuView(model: model)
        } label: {
            Label("PII Sanitizer", systemImage: "shield.lefthalf.filled")
        }
        .menuBarExtraStyle(.menu)
    }
}
