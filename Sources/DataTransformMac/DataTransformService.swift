import Foundation

enum DataTransformService {
    static func run(action: TransformAction, inputURL: URL) throws -> String {
        let rawText = try String(contentsOf: inputURL, encoding: .utf8)
        switch action {
        case .csvToJSON:
            return try convertCSVToJSON(rawText)
        case .jsonToCSV:
            return try convertJSONToCSV(rawText)
        case .formatJSONByLine:
            return try formatJSONToLineView(rawText)
        }
    }

    private static func convertCSVToJSON(_ csvText: String) throws -> String {
        let rows = try CSVParser.parse(csvText)
        guard let headerRow = rows.first, !headerRow.isEmpty else {
            throw TransformError.invalidInput("CSV is empty or missing a header row.")
        }

        let headers = headerRow.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        var objects: [[String: String]] = []

        for row in rows.dropFirst() where !row.allSatisfy({ $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            var object: [String: String] = [:]
            for (index, header) in headers.enumerated() {
                let value = index < row.count ? row[index] : ""
                object[header] = value
            }
            objects.append(object)
        }

        let data = try JSONSerialization.data(
            withJSONObject: objects,
            options: [.prettyPrinted, .sortedKeys]
        )
        guard let json = String(data: data, encoding: .utf8) else {
            throw TransformError.internalError("Could not encode JSON output.")
        }
        return json
    }

    private static func convertJSONToCSV(_ jsonText: String) throws -> String {
        let jsonObject = try parseJSON(jsonText)
        let flatObjects = try extractFlatObjects(jsonObject)
        guard !flatObjects.isEmpty else {
            throw TransformError.invalidInput("JSON has no records to convert.")
        }

        let headers = Array(Set(flatObjects.flatMap { $0.keys })).sorted()
        var lines: [String] = [headers.map(CSVParser.escape).joined(separator: ",")]

        for object in flatObjects {
            let row = headers.map { header in
                CSVParser.escape(object[header] ?? "")
            }
            lines.append(row.joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }

    private static func formatJSONToLineView(_ jsonText: String) throws -> String {
        let jsonObject = try parseJSON(jsonText)
        try validateFlatJSON(jsonObject)

        let data = try JSONSerialization.data(
            withJSONObject: jsonObject,
            options: [.prettyPrinted, .sortedKeys]
        )
        guard let json = String(data: data, encoding: .utf8) else {
            throw TransformError.internalError("Could not encode formatted JSON output.")
        }
        return json
    }

    private static func parseJSON(_ text: String) throws -> Any {
        guard let data = text.data(using: .utf8) else {
            throw TransformError.invalidInput("Input is not valid UTF-8 text.")
        }
        return try JSONSerialization.jsonObject(with: data)
    }

    private static func extractFlatObjects(_ jsonObject: Any) throws -> [[String: String]] {
        if let dict = jsonObject as? [String: Any] {
            return [try flattenDictionary(dict)]
        }
        if let array = jsonObject as? [Any] {
            return try array.enumerated().map { (index, item) in
                guard let dict = item as? [String: Any] else {
                    throw TransformError.invalidInput("Array item \(index + 1) is not a JSON object.")
                }
                return try flattenDictionary(dict)
            }
        }
        throw TransformError.invalidInput("JSON must be an object or array of objects.")
    }

    private static func flattenDictionary(_ dict: [String: Any]) throws -> [String: String] {
        var result: [String: String] = [:]

        for (key, value) in dict {
            switch value {
            case let bool as Bool:
                result[key] = bool ? "true" : "false"
            case let string as String:
                result[key] = string
            case let number as NSNumber:
                result[key] = number.stringValue
            case _ as NSNull:
                result[key] = ""
            default:
                throw TransformError.invalidInput("Only flat JSON is supported. Field '\(key)' contains a nested value.")
            }
        }

        return result
    }

    private static func validateFlatJSON(_ jsonObject: Any) throws {
        switch jsonObject {
        case let dict as [String: Any]:
            try validateFlatDictionary(dict)
        case let array as [Any]:
            for (index, item) in array.enumerated() {
                guard let dict = item as? [String: Any] else {
                    throw TransformError.invalidInput("Array item \(index + 1) is not a JSON object.")
                }
                try validateFlatDictionary(dict)
            }
        default:
            throw TransformError.invalidInput("JSON must be an object or array of objects.")
        }
    }

    private static func validateFlatDictionary(_ dict: [String: Any]) throws {
        for (key, value) in dict {
            switch value {
            case is String, is NSNumber, is NSNull:
                continue
            default:
                throw TransformError.invalidInput("Only flat JSON is supported. Field '\(key)' contains a nested value.")
            }
        }
    }
}

enum TransformError: LocalizedError {
    case invalidInput(String)
    case internalError(String)

    var errorDescription: String? {
        switch self {
        case let .invalidInput(message):
            return "Invalid input: \(message)"
        case let .internalError(message):
            return "Internal error: \(message)"
        }
    }
}
