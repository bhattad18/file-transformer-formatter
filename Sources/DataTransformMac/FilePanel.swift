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

    static func pickFiles(allowedExtensions: [String]) throws -> [URL] {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = allowedExtensions.compactMap {
            UTType(filenameExtension: $0)
        }
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.prompt = "Open"

        if panel.runModal() == .OK, !panel.urls.isEmpty {
            return panel.urls
        }
        throw NSError(
            domain: NSCocoaErrorDomain,
            code: NSUserCancelledError,
            userInfo: [NSLocalizedDescriptionKey: "File selection canceled."]
        )
    }

    static func pickOutputFolder() throws -> URL {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Choose Output Folder"

        if panel.runModal() == .OK, let url = panel.url {
            return url
        }
        throw NSError(
            domain: NSCocoaErrorDomain,
            code: NSUserCancelledError,
            userInfo: [NSLocalizedDescriptionKey: "Output folder selection canceled."]
        )
    }

    static func pickInputFolder() throws -> URL {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = false
        panel.prompt = "Choose Folder"

        if panel.runModal() == .OK, let url = panel.url {
            return url
        }
        throw NSError(
            domain: NSCocoaErrorDomain,
            code: NSUserCancelledError,
            userInfo: [NSLocalizedDescriptionKey: "Folder selection canceled."]
        )
    }

    static func pickFeedbackAttachments() throws -> [URL] {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.prompt = "Attach"

        if panel.runModal() == .OK, !panel.urls.isEmpty {
            return panel.urls
        }
        throw NSError(
            domain: NSCocoaErrorDomain,
            code: NSUserCancelledError,
            userInfo: [NSLocalizedDescriptionKey: "Attachment selection canceled."]
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
