////////////////////////////////////////////////////////////////////////////
//
// Copyright 2017 Kishikawa Katsumi.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
////////////////////////////////////////////////////////////////////////////

import Foundation

public class SourceFormatter {
    public init() {}

    public func format(source: String) -> String {
        return format(tokens: tokenize(source: source))
    }

    func format(tokens: [Token]) -> String {
        var formatted = ""
        for token in tokens {
            switch token.type {
            case .token:
                formatted += token.value
            case .string, .multilineString:
                formatted += "\"" + token.value + "\""
            case .indent(_):
                break
            case .newline:
                formatted += " "
            case .whitespaces:
                formatted += token.value
            }
        }
        return formatted
    }

    func format(tokens: [Token], withHint expression: Expression) -> String {
        let range = expression.range
        var line = range!.start.line
        var column = range!.start.column

        var formatted = ""
        for (index, token) in tokens.enumerated() {
            switch token.type {
            case .token:
                formatted += token.value
                column += token.value.utf8.count
            case .string, .multilineString:
                let string = "\"" + token.value + "\""
                formatted += string
                column += string.utf8.count
            case .indent(let count):
                column += count
            case .newline:
                let needed = isSemicolonNeeded(line: line, column: column, expression: expression)
                let required = isSemicolonRequired(startIndex: index, tokens: tokens)
                let canAppend = canAppendSemicolon(startIndex: index, tokens: tokens)
                let isAbleToAppend = isAbleToAppendSemicolon(startIndex: index, tokens: tokens, line: line, column: column, expression: expression)
                let end = isEnd(startIndex: index, tokens: tokens)
                formatted += (needed || required) && canAppend && isAbleToAppend && !end ? ";" : " "
                column = 0
                line += 1
            case .whitespaces:
                formatted += token.value
                column += token.value.utf8.count
            }
        }
        return formatted
    }

    func escaped(tokens: [Token], withHint expression: Expression) -> String {
        let range = expression.range
        var line = range!.start.line
        var column = range!.start.column

        var formatted = ""
        for (index, token) in tokens.enumerated() {
            switch token.type {
            case .token:
                formatted += token.value.replacingOccurrences(of: "\\", with: "\\\\")
                column += token.value.utf8.count
            case .string, .multilineString:
                formatted += "\\\"" + escapeString(token.value) + "\\\""
                column += token.value.utf8.count + 2
            case .indent(let count):
                column += count
            case .newline:
                let needed = isSemicolonNeeded(line: line, column: column, expression: expression)
                let required = isSemicolonRequired(startIndex: index, tokens: tokens)
                let canAppend = canAppendSemicolon(startIndex: index, tokens: tokens)
                let isAbleToAppend = isAbleToAppendSemicolon(startIndex: index, tokens: tokens, line: line, column: column, expression: expression)
                formatted += (needed || required) && canAppend && isAbleToAppend ? ";" : " "
                column = 0
                line += 1
            case .whitespaces:
                formatted += token.value
                column += token.value.utf8.count
            }
        }
        return formatted
    }

    func tokenize(source: String) -> [Token] {
        return Tokenizer().tokenize(source: source)
    }

    private func escapeString(_ value: String) -> String {
        return value
            .replacingOccurrences(of: "\"", with: "\\\\\"")
            .replacingOccurrences(of: "\\t", with: "\\\\t")
            .replacingOccurrences(of: "\\r", with: "\\\\r")
            .replacingOccurrences(of: "\\n", with: "\\\\n")
            .replacingOccurrences(of: "\\0", with: "\\\\0")
            .replacingOccurrences(of: "\\(", with: "\\\\(")
    }

    private func isSemicolonNeeded(line: Int, column: Int, expression: Expression) -> Bool {
        var semicolonNeeded = false
        traverse(expression) { (expression, stop) in
            guard let range = expression.range else {
                return
            }
            if (expression.rawValue == "binary_expr" || expression.rawValue == "erasure_expr" || expression.rawValue == "call_expr" ||
                expression.rawValue == "tuple_expr" || expression.rawValue == "tuple_shuffle_expr" || expression.rawValue == "paren_expr") &&
                line == range.end.line && column == range.end.column {
                stop = true
                semicolonNeeded = true
                return
            }
        }
        return semicolonNeeded
    }

    private func isSemicolonRequired(startIndex index: Int, tokens: [Token]) -> Bool {
        var i = index
        while index >= 0 {
            let token = tokens[i]
            switch token.type {
            case .token:
                switch token.value {
                case "}":
                    return true
                default:
                    return false
                }
            case .indent(_), .newline, .whitespaces:
                break
            case .string:
                return false
            case .multilineString:
                return false
            }
            i -= 1
        }
        return false
    }

    private func canAppendSemicolon(startIndex index: Int, tokens: [Token]) -> Bool {
        loop: for i in index..<tokens.count {
            let token = tokens[i]
            switch token.type {
            case .token:
                switch token.value {
                case "(", ")", "[", "]", "{", "}", ",", ".", ":", ";":
                    return false
                default:
                    break loop
                }
            case .indent(_), .newline:
                break
            default:
                break loop
            }
        }
        return true
    }

    private func isAbleToAppendSemicolon(startIndex index: Int, tokens: [Token], line l: Int, column c: Int, expression: Expression) -> Bool {
        var line = l
        var column = c

        loop: for i in index..<tokens.count {
            let token = tokens[i]
            switch token.type {
            case .token:
                column += 1
                break loop
            case .string:
                column += 1
                break loop
            case .multilineString:
                column += 1
                break loop
            case .indent(let count):
                column += count
            case .whitespaces:
                column += 1
            case .newline:
                column = 0
                line += 1
            }
        }

        var isAbleToAppendSemicolon = true
        traverse(expression) { (expression, stop) in
            guard let location = expression.location else {
                return
            }
            if (expression.rawValue == "binary_expr") {
                if line == location.line && column == location.column {
                    stop = true
                    isAbleToAppendSemicolon = false
                    return
                }
            }
        }
        return isAbleToAppendSemicolon
    }

    private func isEnd(startIndex index: Int, tokens: [Token]) -> Bool {
        loop: for i in index..<tokens.count {
            let token = tokens[i]
            switch token.type {
            case .indent(_), .newline:
                break
            default:
                return false
            }
        }
        return true
    }
}

class Tokenizer {
    class State {
        enum Mode {
            case plain(SourceLocation)
            case token(SourceLocation)
            case string(SourceLocation)
            case multilineString(SourceLocation, Int)
            case stringEscape(SourceLocation)
            case stringEscapeInMultilineString(SourceLocation, Int)
            case unicodeEscape(SourceLocation)
            case unicodeEscapeInMultilineString(SourceLocation, Int)
            case newline(SourceLocation)
            case indent(SourceLocation)
        }

        var mode = Mode.plain(.zero)
        var tokens = [Token]()
        var storage = ""
        var currentLocation = SourceLocation.zero
        var input: String

        init(input: String) {
            self.input = input
        }
    }

    func tokenize(source: String) -> [Token] {
        let state = State(input: source)

        var iterator = source.enumerated().makeIterator()
        while let (index, character) = iterator.next() {
            switch state.mode {
            case .plain(let location):
                switch character {
                case "\"":
                    if !state.storage.isEmpty {
                        state.tokens.append(Token(type: .whitespaces, value: state.storage, location: location))
                        state.storage = ""
                    }
                    startString(&iterator, index, state, source)
                case "\n":
                    if !state.storage.isEmpty {
                        state.tokens.append(Token(type: .whitespaces, value: state.storage, location: location))
                        state.storage = ""
                    }
                    state.tokens.append(Token(type: .newline, value: String(character), location: state.currentLocation))
                    state.mode = .newline(state.currentLocation)
                case ".", ",", "(", "[", "{", ")", "]", "}", ":", ";", "?", "!":
                    if !state.storage.isEmpty {
                        state.tokens.append(Token(type: .whitespaces, value: state.storage, location: location))
                        state.storage = ""
                    }
                    state.tokens.append(Token(type: .token, value: String(character), location: state.currentLocation))
                    state.mode = .plain(SourceLocation(line: state.currentLocation.line, column: state.currentLocation.column + 1))
                case " ", "\t":
                    state.storage.append(character)
                default:
                    if !state.storage.isEmpty {
                        state.tokens.append(Token(type: .whitespaces, value: state.storage, location: location))
                        state.storage = ""
                    }
                    state.mode = .token(state.currentLocation)
                    state.storage = String(character)
                }
            case .token(let location):
                switch character {
                case "\"":
                    state.tokens.append(Token(type: .token, value: state.storage, location: location))
                    state.mode = .string(state.currentLocation)
                    state.storage = ""
                case " ", "\t":
                    state.tokens.append(Token(type: .token, value: state.storage, location: location))
                    state.mode = .plain(state.currentLocation)
                    state.storage = String(character)
                case "\n":
                    state.tokens.append(Token(type: .token, value: state.storage, location: location))
                    state.tokens.append(Token(type: .newline, value: String(character), location: state.currentLocation))
                    state.mode = .newline(SourceLocation(line: state.currentLocation.line, column: state.currentLocation.column + 1))
                    state.storage = ""

                case ".", ",", "(", "[", "{", ")", "]", "}", ":", ";", "?", "!":
                    state.tokens.append(Token(type: .token, value: state.storage, location: location))
                    state.tokens.append(Token(type: .token, value: String(character), location: state.currentLocation))
                    state.mode = .plain(SourceLocation(line: state.currentLocation.line, column: state.currentLocation.column + 1))
                    state.storage = ""
                default:
                    state.storage += String(character)
                }
            case .string(let location):
                switch character {
                case "\"":
                    state.tokens.append(Token(type: .string, value: state.storage, location: location))
                    state.mode = .plain(state.currentLocation)
                    state.storage = ""
                case "\\":
                    state.mode = .stringEscape(location)
                default:
                    state.storage += String(character)
                }
            case .multilineString(let location, let indent):
                switch character {
                case "\"":
                    let startIndex = source.index(source.startIndex, offsetBy: index)
                    if source[startIndex...].hasPrefix("\"\"\"") {
                        _ = iterator.next()
                        _ = iterator.next()
                        state.tokens.append(Token(type: .multilineString(indent), value: String(state.storage.prefix(state.storage.count - 2) /* Remove a trailing newline */), location: location))

                        state.currentLocation = SourceLocation(line: state.currentLocation.line, column: state.currentLocation.column + 2)
                        state.mode = .plain(state.currentLocation)
                        state.storage = ""
                    }
                case "\\":
                    state.mode = .stringEscapeInMultilineString(location, indent)
                case "\n":
                    for _ in 0..<indent {
                        _ = iterator.next()
                    }
                    state.currentLocation = SourceLocation(line: state.currentLocation.line + 1, column: indent)
                    state.storage += "\\n"
                default:
                    state.storage += String(character)
                }
            case .stringEscape(let location):
                switch character {
                case "\"", "\\", "'", "t", "n", "r", "0", "(": // '(' == string interpolation
                    state.mode = .string(location)
                    state.storage += "\\" + String(character)
                case "u":
                    state.mode = .unicodeEscape(location)
                    state.storage += "\\" + String(character)
                default:
                    fatalError("unexpected '\(character)' in string escape")
                }
            case .unicodeEscape(let location):
                switch character {
                case "}":
                    state.mode = .string(location)
                    state.storage += String(character)
                default:
                    state.storage += String(character)
                }
            case .stringEscapeInMultilineString(let location, let indent):
                switch character {
                case "\"":
                    let startIndex = source.index(source.startIndex, offsetBy: index)
                    if source[startIndex...].hasPrefix("\"\"\"") {
                        _ = iterator.next()
                        _ = iterator.next()
                        state.currentLocation = SourceLocation(line: state.currentLocation.line, column: state.currentLocation.column + 2)
                        state.mode = .multilineString(location, indent)
                        state.storage.append(contentsOf: "\\\"\\\"\\\"")
                    } else {
                        state.mode = .multilineString(location, indent)
                        state.storage += "\\" + String(character)
                    }
                case "\\", "'", "t", "n", "r", "0", "(": // '(' == string interpolation
                    state.mode = .multilineString(location, indent)
                    state.storage += "\\" + String(character)
                case "u":
                    state.mode = .unicodeEscapeInMultilineString(location, indent)
                    state.storage += "\\" + String(character)
                default:
                    fatalError("unexpected '\(character)' in string escape")
                }
            case .unicodeEscapeInMultilineString(let location, let indent):
                switch character {
                case "}":
                    state.mode = .multilineString(location, indent)
                    state.storage += String(character)
                default:
                    state.storage += String(character)
                }
            case .indent(let location):
                switch character {
                case "\"":
                    startString(&iterator, index, state, source)
                    state.tokens.append(Token(type: .indent(state.storage.count), value: state.storage, location: location))
                    state.storage = ""
                case " ", "\t":
                    state.storage += String(character)
                case "\n":
                    state.tokens.append(Token(type: .indent(state.storage.count), value: state.storage, location: location))
                    state.tokens.append(Token(type: .newline, value: String(character), location: state.currentLocation))
                    state.mode = .newline(SourceLocation(line: state.currentLocation.line, column: state.currentLocation.column + 1))
                    state.storage = ""
                case ".", ",", "(", "[", "{", ")", "]", "}", ":", ";", "?", "!":
                    state.tokens.append(Token(type: .indent(state.storage.count), value: state.storage, location: location))
                    state.tokens.append(Token(type: .token, value: String(character), location: state.currentLocation))
                    state.mode = .plain(SourceLocation(line: state.currentLocation.line, column: state.currentLocation.column + 1))
                    state.storage = ""
                default:
                    state.tokens.append(Token(type: .indent(state.storage.count), value: state.storage, location: location))
                    state.mode = .token(state.currentLocation)
                    state.storage = String(character)
                }
            case .newline(_):
                state.currentLocation = SourceLocation(line: state.currentLocation.line + 1, column: 0)

                switch character {
                case " ", "\t":
                    state.mode = .indent(state.currentLocation)
                    state.storage = String(character)
                case ".", ",", "\"", "(", "[", "{", ")", "]", "}", ":", ";", "?", "!":
                    state.tokens.append(Token(type: .token, value: String(character), location: state.currentLocation))
                    state.mode = .plain(state.currentLocation)
                case "\n":
                    state.tokens.append(Token(type: .newline, value: String(character), location: state.currentLocation))
                default:
                    state.mode = .token(state.currentLocation)
                    state.storage = String(character)
                }
            }
            state.currentLocation = SourceLocation(line: state.currentLocation.line, column: state.currentLocation.column + String(character).utf8.count)
        }
        if !state.storage.isEmpty {
            switch state.mode {
            case .plain(_):
                break
            case .token(let location):
                state.tokens.append(Token(type: .token, value: state.storage, location: location))
            case .string(let location):
                state.tokens.append(Token(type: .string, value: state.storage, location: location))
            case .multilineString(let location, let indent):
                state.tokens.append(Token(type: .multilineString(indent), value: state.storage, location: location))
            case .indent(let location):
                state.tokens.append(Token(type: .indent(state.storage.count), value: state.storage, location: location))
            case .newline(_):
                state.tokens.append(Token(type: .newline, value: state.storage, location: state.currentLocation))
            default:
                fatalError()
            }
        }
        return state.tokens
    }

    private func startString(_ iterator: inout EnumeratedIterator<IndexingIterator<String>>, _ index: Int, _ state: Tokenizer.State, _ source: String) {
        let startIndex = source.index(source.startIndex, offsetBy: index)
        if source[startIndex...].hasPrefix("\"\"\"\n") {
            _ = iterator.next()
            _ = iterator.next()
            _ = iterator.next()
            let contents = source[source.index(source.startIndex, offsetBy: index + 4)...]
            var indent = 0
            loop: for character in contents {
                switch character {
                case " ", "\t":
                    indent += 1
                    _ = iterator.next()
                default:
                    break loop
                }
            }
            state.mode = .multilineString(state.currentLocation, indent)
            state.currentLocation = SourceLocation(line: state.currentLocation.line + 1, column: indent)
        } else {
            state.mode = .string(state.currentLocation)
        }
    }

    private func normalizeMultilineLiteral(_ literal: String) -> String {
        var lines = [String]()
        var isFirstLine = true
        var indentCount = 0
        literal.trimmingCharacters(in: .newlines).enumerateLines { (line, stop) in
            if isFirstLine {
                for character in line {
                    if character == " " {
                        indentCount += 1
                    } else {
                        break
                    }
                }
                isFirstLine = false
            }
            lines.append(String(line.suffix(line.count - indentCount)))
        }
        return lines.dropLast().joined(separator: "\\n")
    }
}

public class Token {
    enum TokenType {
        case token
        case string
        case multilineString(Int)
        case indent(Int)
        case whitespaces
        case newline
    }

    let type: TokenType
    let value: String
    var formattedValue: String {
        switch type {
        case .string, .multilineString:
            return "\"" + value + "\""
        default:
            return value
        }
    }
    let location: SourceLocation

    init(type: TokenType, value: String, location: SourceLocation) {
        self.type = type
        self.value = value
        self.location = location
    }
}

extension Token: Comparable {
    public static func <(lhs: Token, rhs: Token) -> Bool {
        return lhs.location < rhs.location
    }

    public static func ==(lhs: Token, rhs: Token) -> Bool {
        return lhs.location == rhs.location
    }
}

extension Token: CustomStringConvertible {
    public var description: String {
        switch self.type {
        case .token:
            return "\(location.line):\(location.column) \(value)"
        case .string, .multilineString:
            return "\(location.line):\(location.column) \"\(value)\""
        case .indent(let count):
            return "\(location.line):\(location.column) \(String(repeating: "␣", count: count))"
        case .whitespaces:
            return "\(location.line):\(location.column) \(value.replacingOccurrences(of: " ", with: "␣").replacingOccurrences(of: "\t", with: "\\t"))"
        case .newline:
            return "\(location.line):\(location.column) \\n"
        }
    }
}
