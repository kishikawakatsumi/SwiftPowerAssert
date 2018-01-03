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

class Formatter {
    class State {
        enum Mode {
            case plain
            case token
            case string
            case multilineString
            case stringEscape
            case stringEscapeInMultilineString
            case newline
            case indent
        }

        var mode = Mode.plain
        var tokens = [Token]()
        var storage = ""
        var input: String
        var openingDelimiterCount = 0
        var closingDelimiterCount = 0
        var skipEscapedQuoteCount = 0

        init(input: String) {
            self.input = input
        }
    }

    func tokenize(source: String) -> [Token] {
        let state = State(input: source)
        let input = state.input
        for (index, character) in input.enumerated() {
            switch state.mode {
            case .plain:
                switch character {
                case "\"":
                    if index + 2 < input.count {
                        let startIndex = input.index(input.startIndex, offsetBy: index)
                        if input[startIndex...input.index(startIndex, offsetBy: 2)] == "\"\"\"" {
                            state.mode = .multilineString
                            state.openingDelimiterCount = 1
                            break
                        }
                    }
                    state.mode = .string
                case "\n":
                    state.tokens.append(Token(type: .newline, value: String(character)))
                    state.mode = .newline
                case "(", ")", "[", "]", "{", "}", ",", ".", ":", ";":
                    state.tokens.append(Token(type: .token, value: String(character)))
                case " ", "\t":
                    state.tokens.append(Token(type: .token, value: " "))
                default:
                    state.mode = .token
                    state.storage = String(character)
                }
            case .token:
                switch character {
                case "\"":
                    state.tokens.append(Token(type: .token, value: state.storage))
                    state.mode = .string
                    state.storage = ""
                case " ":
                    state.tokens.append(Token(type: .token, value: state.storage))
                    state.tokens.append(Token(type: .token, value: " "))
                    state.mode = .plain
                    state.storage = ""
                case "\n":
                    state.tokens.append(Token(type: .token, value: state.storage))
                    state.tokens.append(Token(type: .newline, value: "\n"))
                    state.mode = .newline
                    state.storage = ""
                case "(", ")", "[", "]", "{", "}", ",", ".", ":", ";":
                    state.tokens.append(Token(type: .token, value: state.storage))
                    state.tokens.append(Token(type: .token, value: String(character)))
                    state.mode = .plain
                    state.storage = ""
                default:
                    state.storage += String(character)
                }
            case .string:
                switch character {
                case "\"":
                    state.tokens.append(Token(type: .string, value: state.storage))
                    state.mode = .plain
                    state.storage = ""
                case "\\":
                    state.mode = .stringEscape
                default:
                    state.storage += String(character)
                }
            case .multilineString:
                switch character {
                case "\"":
                    if state.skipEscapedQuoteCount > 0 && state.skipEscapedQuoteCount < 2 {
                        state.skipEscapedQuoteCount += 1
                        state.storage += "\\" + String(character)
                    } else if state.skipEscapedQuoteCount == 2 {
                        state.skipEscapedQuoteCount = 0
                        state.storage += "\\" + String(character)
                    } else if state.openingDelimiterCount == 3 {
                        if state.closingDelimiterCount == 2 {
                            state.tokens.append(Token(type: .string, value: normalizeMultilineLiteral(state.storage)))
                            state.mode = .plain
                            state.storage = ""
                            state.openingDelimiterCount = 0
                            state.closingDelimiterCount = 0
                        } else {
                            state.closingDelimiterCount += 1
                        }
                    } else {
                        state.openingDelimiterCount += 1
                    }
                case "\\":
                    state.mode = .stringEscapeInMultilineString
                default:
                    state.storage += String(character)
                }
            case .stringEscape:
                switch character {
                case "\"":
                    state.mode = .string
                    state.storage += "\\" + String(character)
                case "\\", "'", "t", "n", "r", "0":
                    state.mode = .string
                    state.storage += "\\" + String(character)
                default:
                    fatalError("unexpected '\(character)' in string escape")
                }
            case .stringEscapeInMultilineString:
                switch character {
                case "\"":
                    if index + 2 < input.count {
                        let startIndex = input.index(input.startIndex, offsetBy: index)
                        if input[startIndex...input.index(startIndex, offsetBy: 2)] == "\"\"\"" {
                            state.mode = .multilineString
                            state.storage += "\\" + String(character)
                            state.skipEscapedQuoteCount = 1
                            break
                        }
                    }
                    state.mode = .multilineString
                    state.storage += "\\" + String(character)
                case "\\", "'", "t", "n", "r", "0":
                    state.mode = .multilineString
                    state.storage += "\\" + String(character)
                default:
                    fatalError("unexpected '\(character)' in string escape")
                }
            case .indent:
                switch character {
                case "\"":
                    state.tokens.append(Token(type: .indent(state.storage.count), value: state.storage))
                    state.mode = .string
                    state.storage = ""
                case " ", "\t":
                    state.storage += " "
                case "\n":
                    state.tokens.append(Token(type: .indent(state.storage.count), value: state.storage))
                    state.tokens.append(Token(type: .newline, value: String(character)))
                    state.mode = .newline
                    state.storage = ""
                case "(", ")", "[", "]", "{", "}", ",", ".", ":", ";":
                    state.tokens.append(Token(type: .indent(state.storage.count), value: state.storage))
                    state.tokens.append(Token(type: .token, value: String(character)))
                    state.mode = .plain
                    state.storage = ""
                default:
                    state.tokens.append(Token(type: .indent(state.storage.count), value: state.storage))
                    state.mode = .token
                    state.storage = String(character)
                }
            case .newline:
                switch character {
                case " ", "\t":
                    state.mode = .indent
                    state.storage = String(character)
                case "(", ")", "[", "]", "{", "}", ",", ".", ":", ";":
                    state.tokens.append(Token(type: .token, value: String(character)))
                    state.mode = .plain
                case "\n":
                    state.tokens.append(Token(type: .newline, value: String(character)))
                default:
                    state.mode = .token
                    state.storage = String(character)
                }
            }
        }
        if !state.storage.isEmpty {
            switch state.mode {
            case .indent:
                state.tokens.append(Token(type: .indent(state.storage.count), value: state.storage))
            case .newline:
                state.tokens.append(Token(type: .newline, value: state.storage))
            case .string:
                state.tokens.append(Token(type: .string, value: state.storage))
            default:
                state.tokens.append(Token(type: .token, value: state.storage))
            }
        }
        return state.tokens
    }

    func normalizeMultilineLiteral(_ literal: String) -> String {
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

    func format(tokens: [Token]) -> String {
        var formatted = ""
        for token in tokens {
            switch token.type {
            case .token:
                formatted += token.value
            case .string:
                formatted += "\"" + token.value + "\""
            case .indent(_):
                break
            case .newline:
                formatted += " "
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
            case .string:
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
                formatted += (needed || required) && canAppend && isAbleToAppend ? ";" : " "
                column = 0
                line += 1
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
                let value = token.value
                formatted += value.replacingOccurrences(of: "\\", with: "\\\\")
                column += value.utf8.count
            case .string:
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
            }
        }
        return formatted
    }

    private func escapeString(_ value: String) -> String {
        return value
            .replacingOccurrences(of: "\"", with: "\\\\\"")
            .replacingOccurrences(of: "\\t", with: "\\\\t")
            .replacingOccurrences(of: "\\r", with: "\\\\r")
            .replacingOccurrences(of: "\\n", with: "\\\\n")
            .replacingOccurrences(of: "\\0", with: "\\\\0")
    }

    private func isSemicolonNeeded(line: Int, column: Int, expression: Expression) -> Bool {
        var semicolonNeeded = false
        traverse(expression) { (expression, skip) in
            guard let range = expression.range else {
                return
            }
            if (expression.rawValue == "binary_expr" || expression.rawValue == "erasure_expr" || expression.rawValue == "call_expr" ||
                expression.rawValue == "tuple_expr" || expression.rawValue == "tuple_shuffle_expr" || expression.rawValue == "paren_expr") &&
                line == range.end.line && column == range.end.column {
                skip = true
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
            case .indent(_), .newline:
                break
            case .string:
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
            case .indent(let count):
                column += count
            case .newline:
                column = 0
                line += 1
            }
        }

        var isAbleToAppendSemicolon = true
        traverse(expression) { (expression, skip) in
            guard let location = expression.location else {
                return
            }
            if (expression.rawValue == "binary_expr") {
                if line == location.line && column == location.column {
                    skip = true
                    isAbleToAppendSemicolon = false
                    return
                }
            }
        }
        return isAbleToAppendSemicolon
    }

    private func traverse(_ expression: Expression, closure: (_ expression: Expression, _ skipChildren: inout Bool) -> ()) {
        var skip = false
        closure(expression, &skip)
        if skip {
            return
        }
        for expression in expression.expressions {
            traverse(expression, closure: closure)
        }
    }

    class Token {
        enum TokenType {
            case token
            case string
            case indent(Int)
            case newline
        }

        var type: TokenType
        var value: String

        init(type: TokenType, value: String) {
            self.type = type
            self.value = value
        }
    }
}
