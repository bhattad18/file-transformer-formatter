import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
enum FilePanel {
    static func pickFile(allowedExtensions: [String]) throws -> URL {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = allowedExtensions.compactMap {
            UTType(filenameExtension: $0)
        }
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.prompt = "Open"

        if panel.runModal() == .OK, let url = panel.url {
            return url
        }
        throw NSError(
            domain: NSCocoaErrorDomain,
            code: NSUserCancelledError,
            userInfo: [NSLocalizedDescriptionKey: "File selection canceled."]
        )
    }

    static func pickSaveLocation(suggestedName: String, allowedExtension: String) throws -> URL {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggestedName
        panel.allowedContentTypes = UTType(filenameExtension: allowedExtension).map { [$0] } ?? []
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.prompt = "Save"

        if panel.runModal() == .OK, let url = panel.url {
            return url
        }
        throw NSError(
            domain: NSCocoaErrorDomain,
            code: NSUserCancelledError,
            userInfo: [NSLocalizedDescriptionKey: "Save location selection canceled."]
        )
    }
}
