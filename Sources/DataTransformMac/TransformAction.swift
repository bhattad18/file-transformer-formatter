import Foundation

enum TransformAction: String, CaseIterable, Identifiable, Sendable {
    case csvToJSON
    case jsonToCSV
    case formatJSONByLine
    case flattenJSON

    var id: String { rawValue }

    var label: String {
        switch self {
        case .csvToJSON:
            return "CSV -> JSON"
        case .jsonToCSV:
            return "JSON -> CSV"
        case .formatJSONByLine:
            return "Format JSON"
        case .flattenJSON:
            return "Flatten JSON"
        }
    }

    var description: String {
        switch self {
        case .csvToJSON:
            return "Converts a CSV file into pretty, flat JSON."
        case .jsonToCSV:
            return "Converts flat JSON (object/array of objects) into CSV."
        case .formatJSONByLine:
            return "Formats flat JSON with one field/value per line and readable indentation."
        case .flattenJSON:
            return "Flattens nested JSON into dot-notated flat JSON."
        }
    }

    var allowedInputExtensions: [String] {
        switch self {
        case .csvToJSON:
            return ["csv", "txt"]
        case .jsonToCSV, .formatJSONByLine, .flattenJSON:
            return ["json", "txt"]
        }
    }

    var outputExtension: String {
        switch self {
        case .csvToJSON, .formatJSONByLine, .flattenJSON:
            return "json"
        case .jsonToCSV:
            return "csv"
        }
    }

    func suggestedOutputFileName(from inputURL: URL) -> String {
        let base = inputURL.deletingPathExtension().lastPathComponent
        switch self {
        case .csvToJSON:
            return "\(base)_converted.json"
        case .jsonToCSV:
            return "\(base)_converted.csv"
        case .formatJSONByLine:
            return "\(base)_line_formatted.json"
        case .flattenJSON:
            return "\(base)_flattened.json"
        }
    }
}
