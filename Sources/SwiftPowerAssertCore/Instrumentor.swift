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

class Instrumentor {
    let source: String
    let sourceIndices: [Int: Int]

    init(source: String) {
        self.source = source
        var sourceIndices = [Int: Int]()
        var index = 0
        var characterCount = 0
        source.enumerateLines { (line, stop) in
            let count = line.count
            sourceIndices[index] = characterCount + count + 1
            index += 1
            characterCount += count + 1
        }
        self.sourceIndices = sourceIndices
    }

    func instrument(node: AST) -> String {
        var instruments = [(SourceRange, String)]()

        node.declarations.forEach {
            switch $0 {
            case .class(let declaration) where declaration.typeInheritance == "XCTestCase":
                declaration.members.forEach {
                    switch $0 {
                    case .declaration(let declaration):
                        switch declaration {
                        case .function(let declaration):
                            declaration.body.forEach {
                                switch $0 {
                                case .expression(let expression):
                                    let source = instrument(functionCall: expression)
                                    instruments.append((expression.range, source))
                                case .declaration(_):
                                    break
                                }
                            }
                        default:
                            break
                        }
                    }
                }
            default:
                break
            }
        }

        var instrumented = source
        for instrument in instruments.reversed() {
            let sourceLocation = instrument.0
            let code = instrument.1

            let startIndex: String.Index
            if sourceLocation.start.line > 0 {
                startIndex = source.index(source.startIndex, offsetBy: sourceIndices[sourceLocation.start.line - 1]! + sourceLocation.start.column)
            } else {
                startIndex = source.index(source.startIndex, offsetBy: sourceLocation.start.column)
            }
            let endIndex: String.Index
            if sourceLocation.end.line > 0 {
                endIndex = source.index(source.startIndex, offsetBy: sourceIndices[sourceLocation.end.line - 1]! + sourceLocation.end.column)
            } else {
                endIndex = source.index(source.startIndex, offsetBy: sourceLocation.end.column)
            }

            instrumented.replaceSubrange(startIndex...endIndex, with: code)
        }

        return instrumented
    }

    private func instrument(functionCall expression: Expression) -> String {
        if expression.rawValue == "call_expr" {
            if !expression.expressions.isEmpty, let decl = expression.expressions[0].decl, decl == "Swift.(file).assert(_:_:file:line:)" {
                let code = instrument(expression)
                return code
            }
        }
        return expression.source
    }

    private func instrument(_ expression: Expression) -> String {
        var values = [Int: String]()
        let formatter = Formatter()
        
        traverse(expression) { (childExpression) in
            if childExpression.source == expression.source || (childExpression.range.start.line == expression.range.start.line && childExpression.range.start.column == expression.range.start.column) {
                return
            }

            if childExpression.rawValue == "declref_expr" && !childExpression.type.contains("->") {
                let source = completeExpressionSource(childExpression, expression)
                
                let formatter = Formatter()
                let tokens = formatter.tokenize(source: expression.source)
                
                let column = columnInFunctionCall(column: childExpression.range.end.column, startLine: childExpression.range.start.line, endLine: childExpression.range.end.line, tokens: tokens, child: childExpression, parent: expression)
                values[column] = formatter.format(tokens: formatter.tokenize(source: source))
            }
            if childExpression.rawValue == "member_ref_expr" {
                let source = completeExpressionSource(childExpression, expression)

                let formatter = Formatter()
                let tokens = formatter.tokenize(source: expression.source)

                let column = columnInFunctionCall(column: childExpression.range.end.column, startLine: childExpression.range.start.line, endLine: childExpression.range.end.line, tokens: tokens, child: childExpression, parent: expression)

                if source.hasPrefix(".") {
                    values[column] = childExpression.type + formatter.format(tokens: formatter.tokenize(source: source))
                } else {
                    values[column] = formatter.format(tokens: formatter.tokenize(source: source))
                }
            }
            if childExpression.rawValue == "tuple_element_expr" {
                let source = completeExpressionSource(childExpression, expression)

                let formatter = Formatter()
                let tokens = formatter.tokenize(source: expression.source)

                let column = columnInFunctionCall(column: childExpression.range.end.column, startLine: childExpression.range.start.line, endLine: childExpression.range.end.line, tokens: tokens, child: childExpression, parent: expression)
                values[column] = formatter.format(tokens: formatter.tokenize(source: source)) + " as \(childExpression.type)"
            }
            if childExpression.rawValue == "string_literal_expr" {
                let source = stringLiteralExpression(childExpression, expression)

                let formatter = Formatter()
                let tokens = formatter.tokenize(source: expression.source)

                let column = columnInFunctionCall(column: childExpression.range.end.column, startLine: childExpression.range.start.line, endLine: childExpression.range.end.line, tokens: tokens, child: childExpression, parent: expression)
                values[column] = formatter.format(tokens: formatter.tokenize(source: source))
            }
            if childExpression.rawValue == "magic_identifier_literal_expr" {
                let source = completeExpressionSource(childExpression, expression)

                let formatter = Formatter()
                let tokens = formatter.tokenize(source: expression.source)

                let column = columnInFunctionCall(column: childExpression.range.end.column, startLine: childExpression.range.start.line, endLine: childExpression.range.end.line, tokens: tokens, child: childExpression, parent: expression)
                values[column] = formatter.format(tokens: formatter.tokenize(source: source))
            }
            if childExpression.rawValue == "array_expr" || childExpression.rawValue == "dictionary_expr" ||
                childExpression.rawValue == "object_literal" {
                let source = childExpression.source

                let formatter = Formatter()
                let tokens = formatter.tokenize(source: expression.source)

                let column = columnInFunctionCall(column: childExpression.location.column, startLine: childExpression.location.line, endLine: childExpression.location.line, tokens: tokens, child: childExpression, parent: expression)
                values[column] = formatter.format(tokens: formatter.tokenize(source: source)) + " as \(childExpression.type)"
            }
            if childExpression.rawValue == "keypath_expr" {
                let source = completeExpressionSource(childExpression, expression)

                let formatter = Formatter()
                let tokens = formatter.tokenize(source: expression.source)

                let column = columnInFunctionCall(column: childExpression.range.end.column, startLine: childExpression.range.start.line, endLine: childExpression.range.end.line, tokens: tokens, child: childExpression, parent: expression)
                values[column] = formatter.format(tokens: formatter.tokenize(source: source)) + " as \(childExpression.type)"
            }
            if childExpression.rawValue == "subscript_expr" || childExpression.rawValue == "keypath_application_expr" {
                let source = childExpression.source

                let formatter = Formatter()
                let tokens = formatter.tokenize(source: expression.source)

                let column = columnInFunctionCall(column: childExpression.range.end.column, startLine: childExpression.range.start.line, endLine: childExpression.range.end.line, tokens: tokens, child: childExpression, parent: expression)
                values[column] = formatter.format(tokens: formatter.tokenize(source: source))
            }
            if childExpression.rawValue == "call_expr" {
                let source = completeExpressionSource(childExpression, expression)

                let formatter = Formatter()
                let tokens = formatter.tokenize(source: expression.source)

                let column = columnInFunctionCall(column: childExpression.location.column, startLine: childExpression.location.line, endLine: childExpression.location.line, tokens: tokens, child: childExpression, parent: expression)

                if !childExpression.expressions.isEmpty && childExpression.throwsModifier == "throws" {
                    values[column] = "try! " + formatter.format(tokens: formatter.tokenize(source: source))
                } else if childExpression.argumentLabels == "nilLiteral:" {
                    values[column] = formatter.format(tokens: formatter.tokenize(source: source)) + " as \(childExpression.type)"
                } else {
                    values[column] = formatter.format(tokens: formatter.tokenize(source: source))
                }
            }
            if childExpression.rawValue == "binary_expr" {
                let source = completeExpressionSource(childExpression, expression)

                let formatter = Formatter()
                let tokens = formatter.tokenize(source: expression.source)

                var containsThrowsFunction = false
                traverse(childExpression) {
                    guard !containsThrowsFunction else { return }
                    containsThrowsFunction = $0.rawValue == "call_expr" && $0.throwsModifier == "throws"
                }

                let column = columnInFunctionCall(column: childExpression.location.column, startLine: childExpression.location.line, endLine: childExpression.location.line, tokens: tokens, child: childExpression, parent: expression)
                values[column] = (containsThrowsFunction ? "try! " : "") + formatter.format(tokens: formatter.tokenize(source: source))
            }
            if childExpression.rawValue == "if_expr" {
                let source = completeExpressionSource(childExpression, expression)

                let formatter = Formatter()
                let tokens = formatter.tokenize(source: expression.source)

                let column = columnInFunctionCall(column: childExpression.location.column, startLine: childExpression.location.line, endLine: childExpression.location.line, tokens: tokens, child: childExpression, parent: expression)
                values[column] = formatter.format(tokens: formatter.tokenize(source: source))
            }
        }

        var recordValues = ""
        for (key, value) in values {
            recordValues += "valueColumns[\(key - 1)] = \"\\(toString(\(value)))\"\n"
        }

        let code =
        """

        do {
        func toString<T>(_ value: T?) -> String {
        switch value {
        case .some(let v) where v is String: return \"\\"\\(v)\\\""
        case .some(let v): return \"\\(v)\"
        case .none: return \"nil\"
        }
        }
        var valueColumns = [Int: String]()
        let condition = { () -> Bool in
        \(recordValues)
        return \(formatter.format(tokens: formatter.tokenize(source: expression.expressions[1].source)))
        }()
        if !condition {
        func align(current: inout Int, column: Int, string: String) {
        while current < column {
        print(\" \", terminator: \"\")
        current += 1
        }
        print(string, terminator: \"\")
        current += string.count
        }
        print(\"\(formatter.escaped(tokens: formatter.tokenize(source: expression.source)))\")
        var values = Array(valueColumns).sorted { $0.0 < $1.0 }
        var current = 0
        for value in values {
        align(current: &current, column: value.0, string: \"|\")
        }
        print()
        while !values.isEmpty {
        var current = 0
        var index = 0
        while index < values.count {
        if index == values.count - 1 || values[index].0 + values[index].1.count < values[index + 1].0 {
        align(current: &current, column: values[index].0, string: values[index].1)
        values.remove(at: index)
        } else {
        align(current: &current, column: values[index].0, string: \"|\")
        index += 1
        }
        }
        print()
        }
        }
        }
        
        """

        return code
    }

    private func completeExpressionSource(_ child: Expression, _ parent: Expression) -> String {
        let source = child.source
        let rest = restOfExpression(child, parent)
        return extendExpression(rest, source)
    }

    private func stringLiteralExpression(_ child: Expression, _ parent: Expression) -> String {
        var source = child.source
        let rest = restOfExpression(child, parent)
        var previous = ""
        for character in rest {
            switch character {
            case "\"" where previous != "\\":
                source += String(character)
                return source
            default:
                previous = String(character)
                source += previous
            }
        }
        return source
    }

    private func traverse(_ expression: Expression, closure: (_ expression: Expression) -> ()) {
        closure(expression)
        for expression in expression.expressions {
            traverse(expression, closure: closure)
        }
    }

    private func restOfExpression(_ child: Expression, _ parent: Expression) -> String {
        let startIndex: String.Index
        if child.range.end.line > 0 {
            startIndex = source.index(source.startIndex, offsetBy: sourceIndices[child.range.end.line - 1]! + child.range.end.column)
        } else {
            startIndex = source.index(source.startIndex, offsetBy: child.range.end.column)
        }
        let endIndex: String.Index
        if parent.range.end.line > 0 {
            endIndex = source.index(source.startIndex, offsetBy: sourceIndices[parent.range.end.line - 1]! + parent.range.end.column)
        } else {
            endIndex = source.index(source.startIndex, offsetBy: parent.range.end.column)
        }

        return String(source[startIndex...endIndex])
    }

    private func extendExpression(_ rest: String, _ source: String) -> String {
        var result = source
        for character in rest {
            switch character {
            case ".", ",", " ", "\t", "\n", "(", "[", "{", ")", "]", "}", ":", ";":
                return result
            default:
                result += String(character)
            }
        }
        return result
    }

    private func columnInFunctionCall(column: Int, startLine: Int, endLine: Int, tokens: [Formatter.Token], child: Expression, parent: Expression) -> Int {
        var columnIndex = 0
        let endLineIndex = endLine - parent.range.start.line

        var lineIndex = 0

        var indent = 0
        if parent.range.start.line == endLine {
            indent = parent.range.start.column
        }

        loop: for token in tokens {
            switch token.type {
            case .token:
                if lineIndex < endLineIndex {
                    columnIndex += token.value.count
                } else if lineIndex == endLineIndex {
                    columnIndex += column
                    break loop
                }
            case .string:
                if lineIndex < endLineIndex {
                    columnIndex += ("\"" + token.value + "\"").count
                } else if lineIndex == endLineIndex {
                    columnIndex += column
                    break loop
                }
            case .indent(let count):
                if lineIndex == endLineIndex {
                    indent += count
                    columnIndex += column
                    break loop
                }
            case .newline:
                columnIndex += 1
                lineIndex += 1
            }
        }

        return columnIndex - indent
    }

    class Formatter {
        class State {
            enum Mode {
                case plain
                case token
                case string
                case stringEscape
                case newline
                case indent
            }

            var mode = Mode.plain
            var tokens = [Token]()
            var storage = ""
            var input: String

            init(input: String) {
                self.input = input
            }
        }

        func tokenize(source: String) -> [Token] {
            let state = State(input: source)
            for character in state.input {
                switch state.mode {
                case .plain:
                    switch character {
                    case "\"":
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
                case .stringEscape:
                    switch character {
                    case "\"", "\\":
                        state.mode = .string
                        state.storage += "\\" + String(character)
                    case "n":
                        state.mode = .string
                        state.storage += "\n"
                    case "t":
                        state.mode = .string
                        state.storage += "\t"
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

        func escaped(tokens: [Token]) -> String {
            var formatted = ""
            for token in tokens {
                switch token.type {
                case .token:
                    formatted += token.value.replacingOccurrences(of: "\\", with: "\\\\")
                case .string:
                    formatted += "\\\"" + token.value.replacingOccurrences(of: "\"", with: "\\\\\"") + "\\\""
                case .indent(_):
                    break
                case .newline:
                    formatted += " "
                }
            }
            return formatted
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
}
