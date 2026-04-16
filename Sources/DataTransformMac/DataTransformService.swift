import Foundation

struct TransformResult: Sendable {
    let output: String
    let summary: String
    let warnings: [String]

    var report: String {
        var lines = [summary]
        if !warnings.isEmpty {
            lines.append("")
            lines.append("Warnings:")
            lines.append(contentsOf: warnings.map { "- \($0)" })
        }
        return lines.joined(separator: "\n")
    }
}

enum DataTransformService {
    static func run(action: TransformAction, inputURL: URL) throws -> String {
        let rawText = try String(contentsOf: inputURL, encoding: .utf8)
        return try run(action: action, rawText: rawText)
    }

    static func runDetailed(action: TransformAction, inputURL: URL) throws -> TransformResult {
        let rawText = try String(contentsOf: inputURL, encoding: .utf8)
        return try runDetailed(action: action, rawText: rawText)
    }

    static func run(action: TransformAction, rawText: String) throws -> String {
        try runDetailed(action: action, rawText: rawText).output
    }

    static func runDetailed(action: TransformAction, rawText: String) throws -> TransformResult {
        switch action {
        case .csvToJSON:
            return try convertCSVToJSON(rawText)
        case .jsonToCSV:
            return try convertJSONToCSV(rawText)
        case .formatJSONByLine:
            return try formatJSONToLineView(rawText)
        case .flattenJSON:
            return try flattenJSON(rawText)
        }
    }

    private static func convertCSVToJSON(_ csvText: String) throws -> TransformResult {
        let rows = try CSVParser.parse(csvText)
        guard let headerRow = rows.first, !headerRow.isEmpty else {
            throw TransformError.invalidInput("CSV is empty or missing a header row.")
        }

        let headers = headerRow.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let duplicateHeaders = duplicateValues(in: headers.filter { !$0.isEmpty })
        let blankHeaderCount = headers.filter { $0.isEmpty }.count
        var objects: [[String: String]] = []
        var skippedRows = 0

        for row in rows.dropFirst() where !row.allSatisfy({ $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            var object: [String: String] = [:]
            for (index, header) in headers.enumerated() {
                let value = index < row.count ? row[index] : ""
                object[header] = value
            }
            objects.append(object)
        }
        skippedRows = max(0, rows.dropFirst().filter { $0.allSatisfy { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } }.count)

        let data = try JSONSerialization.data(
            withJSONObject: objects,
            options: [.prettyPrinted, .sortedKeys]
        )
        guard let json = String(data: data, encoding: .utf8) else {
            throw TransformError.internalError("Could not encode JSON output.")
        }
        var warnings: [String] = []
        if !duplicateHeaders.isEmpty {
            warnings.append("Duplicate CSV header(s) found: \(duplicateHeaders.joined(separator: ", ")). Later columns may overwrite earlier values in JSON.")
        }
        if blankHeaderCount > 0 {
            warnings.append("\(blankHeaderCount) CSV column(s) have a blank header.")
        }
        if skippedRows > 0 {
            warnings.append("\(skippedRows) empty row(s) skipped.")
        }
        let summary = """
        CSV -> JSON preview
        Rows processed: \(objects.count)
        Headers found: \(headers.count)
        Output records: \(objects.count)
        """
        return TransformResult(output: json, summary: summary, warnings: warnings)
    }

    private static func convertJSONToCSV(_ jsonText: String) throws -> TransformResult {
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
        let summary = """
        JSON -> CSV preview
        Records processed: \(flatObjects.count)
        Headers found: \(headers.count)
        Output rows: \(flatObjects.count)
        """
        return TransformResult(output: lines.joined(separator: "\n"), summary: summary, warnings: [])
    }

    private static func formatJSONToLineView(_ jsonText: String) throws -> TransformResult {
        let jsonObject = try parseJSON(jsonText)
        try validateFlatJSON(jsonObject)

        let data = try JSONSerialization.data(
            withJSONObject: jsonObject,
            options: [.prettyPrinted, .sortedKeys]
        )
        guard let json = String(data: data, encoding: .utf8) else {
            throw TransformError.internalError("Could not encode formatted JSON output.")
        }
        let recordCount = recordCount(for: jsonObject)
        let fieldCount = fieldCount(for: jsonObject)
        let summary = """
        JSON formatting preview
        Records checked: \(recordCount)
        Fields found: \(fieldCount)
        Flat JSON: Yes
        """
        return TransformResult(output: json, summary: summary, warnings: [])
    }

    private static func flattenJSON(_ jsonText: String) throws -> TransformResult {
        let jsonObject = try parseJSON(jsonText)
        let flattenedObject: Any
        let recordCount: Int

        if let dict = jsonObject as? [String: Any] {
            flattenedObject = flattenNestedDictionary(dict)
            recordCount = 1
        } else if let array = jsonObject as? [Any] {
            flattenedObject = try array.enumerated().map { index, item in
                guard let dict = item as? [String: Any] else {
                    throw TransformError.invalidInput("Array item \(index + 1) is not a JSON object.")
                }
                return flattenNestedDictionary(dict)
            }
            recordCount = array.count
        } else {
            throw TransformError.invalidInput("JSON must be an object or array of objects.")
        }

        let data = try JSONSerialization.data(
            withJSONObject: flattenedObject,
            options: [.prettyPrinted, .sortedKeys]
        )
        guard let json = String(data: data, encoding: .utf8) else {
            throw TransformError.internalError("Could not encode flattened JSON output.")
        }
        let flattenedFields = fieldCount(for: flattenedObject)
        let summary = """
        Flatten JSON preview
        Records processed: \(recordCount)
        Flattened fields found: \(flattenedFields)
        Output format: Flat JSON
        """
        return TransformResult(output: json, summary: summary, warnings: [])
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

    private static func flattenNestedDictionary(_ dict: [String: Any], prefix: String = "") -> [String: String] {
        var result: [String: String] = [:]

        for key in dict.keys.sorted() {
            let outputKey = prefix.isEmpty ? key : "\(prefix).\(key)"
            let value = dict[key] ?? NSNull()

            switch value {
            case let nested as [String: Any]:
                result.merge(flattenNestedDictionary(nested, prefix: outputKey)) { _, new in new }
            case let array as [Any]:
                result[outputKey] = compactJSONString(from: array)
            case let bool as Bool:
                result[outputKey] = bool ? "true" : "false"
            case let string as String:
                result[outputKey] = string
            case let number as NSNumber:
                result[outputKey] = number.stringValue
            case _ as NSNull:
                result[outputKey] = ""
            default:
                result[outputKey] = "\(value)"
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

    private static func duplicateValues(in values: [String]) -> [String] {
        var seen: Set<String> = []
        var duplicates: Set<String> = []
        for value in values {
            if seen.contains(value) {
                duplicates.insert(value)
            }
            seen.insert(value)
        }
        return duplicates.sorted()
    }

    private static func recordCount(for jsonObject: Any) -> Int {
        if let array = jsonObject as? [Any] {
            return array.count
        }
        return 1
    }

    private static func fieldCount(for jsonObject: Any) -> Int {
        if let dict = jsonObject as? [String: Any] {
            return dict.count
        }
        if let array = jsonObject as? [[String: Any]] {
            return array.map(\.count).max() ?? 0
        }
        return 0
    }

    private static func compactJSONString(from value: Any) -> String {
        guard JSONSerialization.isValidJSONObject(value),
              let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]),
              let string = String(data: data, encoding: .utf8)
        else {
            return "\(value)"
        }
        return string
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
