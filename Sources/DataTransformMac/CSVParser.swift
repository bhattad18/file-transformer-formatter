import Foundation

enum CSVParser {
    static func parse(_ text: String) throws -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        var index = text.startIndex

        while index < text.endIndex {
            let char = text[index]

            if inQuotes {
                if char == "\"" {
                    let nextIndex = text.index(after: index)
                    if nextIndex < text.endIndex, text[nextIndex] == "\"" {
                        field.append("\"")
                        index = nextIndex
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(char)
                }
                index = text.index(after: index)
                continue
            }

            switch char {
            case "\"":
                inQuotes = true
            case ",":
                row.append(field)
                field = ""
            case "\n":
                row.append(field)
                rows.append(row)
                row = []
                field = ""
            case "\r":
                break
            default:
                field.append(char)
            }

            index = text.index(after: index)
        }

        if inQuotes {
            throw TransformError.invalidInput("CSV contains an unclosed quote.")
        }

        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            rows.append(row)
        }

        return rows
    }

    static func escape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return value
    }
}
