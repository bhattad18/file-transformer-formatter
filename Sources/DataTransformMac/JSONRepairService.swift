import Foundation

enum JSONRepairService {
    static func sanitize(_ input: String) -> String {
        input.replacingOccurrences(of: "&#34;", with: "\"")
    }

    static func suggestedFix(for input: String) -> String? {
        var candidate = sanitize(input).trimmingCharacters(in: .whitespacesAndNewlines)
        let sanitizedInput = sanitize(input)
        guard !candidate.isEmpty else { return nil }

        if !candidate.hasPrefix("{") && !candidate.hasPrefix("[") {
            return nil
        }

        candidate = candidate.replacingOccurrences(of: ",}", with: "}")
        candidate = candidate.replacingOccurrences(of: ",]", with: "]")
        candidate = insertMissingCommas(in: candidate)

        let openCurly = candidate.filter { $0 == "{" }.count
        let closeCurly = candidate.filter { $0 == "}" }.count
        if openCurly > closeCurly {
            candidate.append(String(repeating: "}", count: openCurly - closeCurly))
        }

        let openSquare = candidate.filter { $0 == "[" }.count
        let closeSquare = candidate.filter { $0 == "]" }.count
        if openSquare > closeSquare {
            candidate.append(String(repeating: "]", count: openSquare - closeSquare))
        }

        guard candidate != sanitizedInput else { return nil }

        do {
            _ = try DataTransformService.run(action: .formatJSONByLine, rawText: candidate)
            return candidate
        } catch {
            return nil
        }
    }

    private static func insertMissingCommas(in input: String) -> String {
        let characters = Array(input)
        var result = ""
        var inString = false
        var isEscaping = false

        for character in characters {
            if inString {
                result.append(character)
                if isEscaping {
                    isEscaping = false
                } else if character == "\\" {
                    isEscaping = true
                } else if character == "\"" {
                    inString = false
                }
                continue
            }

            if character == "\"" {
                if shouldInsertComma(before: character, in: result) {
                    result.append(",")
                }
                inString = true
                result.append(character)
                continue
            }

            if !character.isWhitespace && shouldInsertComma(before: character, in: result) {
                result.append(",")
            }

            result.append(character)
        }

        return result
    }

    private static func shouldInsertComma(before character: Character, in result: String) -> Bool {
        guard let previous = result.last(where: { !$0.isWhitespace }) else { return false }
        let previousEndsValue = previous == "\"" || previous == "}" || previous == "]" || previous.isNumber
        let currentStartsValue = character == "\"" || character == "{" || character == "[" || character.isNumber || character == "-" || character == "t" || character == "f" || character == "n"
        let previousAllowsImplicitComma = previous != ":" && previous != "," && previous != "[" && previous != "{"
        return previousEndsValue && currentStartsValue && previousAllowsImplicitComma
    }
}
