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

struct ArgumentCaptor {
    let sourceFile: SourceFile

    func captureArguments(_ asserttion: Assertion) -> [CapturedExpression] {
        var capturedExpressions = [CapturedExpression]()
        let formatter = SourceFormatter()
        let completion = SourceCompletion(expression: asserttion.expression, sourceFile: sourceFile)
        let argumentExpressions = asserttion.argumentExpressions()

        argumentExpressions.forEach {
            traverse($0) { (part, stop) in
                guard let wholeRange = asserttion.expression.range, let partRange = part.range else {
                    return
                }

                let wholeSource = sourceFile[wholeRange]
                let partSource = sourceFile[partRange]

                switch part.rawValue {
                case "declref_expr" where !part.type.contains("->"):
                    let source = completion.completeSource(range: partRange)
                    if source.hasPrefix("$") {
                        return
                    }
                    let tokens = formatter.tokenize(source: wholeSource)
                    let column = columnInFunctionCall(start: wholeRange.start, target: partRange.end, tokens: tokens)
                    let text = formatter.format(source: source)
                    let capturedExpression = CapturedExpression(text: text, column: column, source: source, expression: part)
                    capturedExpressions.append(capturedExpression)
                case "magic_identifier_literal_expr":
                    let source = completion.completeSource(range: partRange)
                    let tokens = formatter.tokenize(source: wholeSource)
                    let column = columnInFunctionCall(start: wholeRange.start, target: partRange.end, tokens: tokens)
                    switch source {
                    case "#column":
                        let text = "\(part.location.column)"
                        let capturedExpression = CapturedExpression(text: text, column: column, source: source, expression: part)
                        capturedExpressions.append(capturedExpression)
                    case "#line":
                        let text = "\(part.location.line + 1)"
                        let capturedExpression = CapturedExpression(text: text, column: column, source: source, expression: part)
                        capturedExpressions.append(capturedExpression)
                    default:
                        let text = formatter.format(source: source)
                        let capturedExpression = CapturedExpression(text: text, column: column, source: source, expression: part)
                        capturedExpressions.append(capturedExpression)
                    }
                case "member_ref_expr" where !part.type.contains("->"):
                    let source = completion.completeSource(range: partRange)
                    let tokens = formatter.tokenize(source: wholeSource)
                    let column = columnInFunctionCall(start: wholeRange.start, target: partRange.end, tokens: tokens)

                    // FIXME: Extend expression source to a receiver
                    if source.hasPrefix("?") || source.hasPrefix("!") {
                        return
                    }

                    // FIXME
                    var containsThrowsFunction = false
                    traverse(part) { (expression, _) in
                        guard !containsThrowsFunction else { return }
                        containsThrowsFunction = expression.rawValue == "call_expr" && expression.throwsModifier == "throws"
                    }
                    var partTokens = formatter.tokenize(source: source)
                    if containsThrowsFunction {
                        var iterator = partTokens.enumerated().makeIterator()
                        var tryOperatorIndices = [Int]()
                        while let (index, token) = iterator.next() {
                            switch token.type {
                            case .token where token.value == "try":
                                tryOperatorIndices.append(index)
                                if let (index, token) = iterator.next() {
                                    switch token.type {
                                    case .token where token.value == "?" ||  token.value == "!":
                                        tryOperatorIndices.append(index)
                                    default:
                                        break
                                    }
                                }
                            default:
                                break
                            }
                        }
                        for index in tryOperatorIndices {
                            partTokens.remove(at: index)
                        }
                    }

                    if source.hasPrefix(".") {
                        let text = (containsThrowsFunction ? "try " : "") + part.type.replacingOccurrences(of: "@lvalue ", with: "") + formatter.format(tokens: partTokens)
                        let capturedExpression = CapturedExpression(text: text, column: column, source: source, expression: part)
                        capturedExpressions.append(capturedExpression)
                    } else {
                        let text = (containsThrowsFunction ? "try " : "") + formatter.format(tokens: partTokens)
                        let capturedExpression = CapturedExpression(text: text, column: column, source: source, expression: part)
                        capturedExpressions.append(capturedExpression)
                    }
                case "dot_self_expr":
                    let source = completion.completeSource(range: partRange)
                    let tokens = formatter.tokenize(source: wholeSource)
                    let column = columnInFunctionCall(start: wholeRange.start, target: partRange.end, tokens: tokens)
                    if source.hasPrefix(".") {
                        let text = part.type.replacingOccurrences(of: "@lvalue ", with: "") + formatter.format(source: source)
                        let capturedExpression = CapturedExpression(text: text, column: column, source: source, expression: part)
                        capturedExpressions.append(capturedExpression)
                    } else {
                        let text = formatter.format(source: source)
                        let capturedExpression = CapturedExpression(text: text, column: column, source: source, expression: part)
                        capturedExpressions.append(capturedExpression)
                    }
                case "tuple_element_expr", "keypath_expr":
                    let source = completion.completeSource(range: partRange)
                    let tokens = formatter.tokenize(source: wholeSource)
                    let column = columnInFunctionCall(start: wholeRange.start, target: partRange.end, tokens: tokens)
                    let text = formatter.format(source: source) + " as \(part.type!.replacingOccurrences(of: "@lvalue ", with: ""))"
                    let capturedExpression = CapturedExpression(text: text, column: column, source: source, expression: part)
                    capturedExpressions.append(capturedExpression)
                case "string_literal_expr":
                    if !sourceFile[partRange].hasPrefix("\"") {
                        return
                    }
                    let source = completion.completeStringLiteral(part, asserttion.expression)
                    let tokens = formatter.tokenize(source: wholeSource)
                    let column = columnInFunctionCall(start: wholeRange.start, target: partRange.end, tokens: tokens)
                    var text = formatter.format(source: source)
                    if text.hasPrefix("\\(") && text.hasSuffix(")") {
                        text = "\"\(text)\""
                    }
                    let capturedExpression = CapturedExpression(text: text, column: column, source: source, expression: part)
                    capturedExpressions.append(capturedExpression)
                case "array_expr", "dictionary_expr", "object_literal":
                    let source = partSource
                    let tokens = formatter.tokenize(source: wholeSource)
                    let column = columnInFunctionCall(start: wholeRange.start, target: part.location, tokens: tokens)
                    let text = formatter.format(source: source) + " as \(part.type!.replacingOccurrences(of: "@lvalue ", with: ""))"
                    let capturedExpression = CapturedExpression(text: text, column: column, source: source, expression: part)
                    capturedExpressions.append(capturedExpression)
                case "subscript_expr", "keypath_application_expr", "objc_selector_expr":
                    let source = partSource
                    let tokens = formatter.tokenize(source: wholeSource)
                    let column = columnInFunctionCall(start: wholeRange.start, target: partRange.end, tokens: tokens)
                    // FIXME
                    var containsThrowsFunction = false
                    traverse(part) { (expression, _) in
                        guard !containsThrowsFunction else { return }
                        containsThrowsFunction = expression.rawValue == "call_expr" && expression.throwsModifier == "throws"
                    }
                    var partTokens = formatter.tokenize(source: source)
                    if containsThrowsFunction {
                        var iterator = partTokens.enumerated().makeIterator()
                        var tryOperatorIndices = [Int]()
                        while let (index, token) = iterator.next() {
                            switch token.type {
                            case .token where token.value == "try":
                                tryOperatorIndices.append(index)
                                if let (index, token) = iterator.next() {
                                    switch token.type {
                                    case .token where token.value == "?" ||  token.value == "!":
                                        tryOperatorIndices.append(index)
                                    default:
                                        break
                                    }
                                }
                            default:
                                break
                            }
                        }
                        for index in tryOperatorIndices {
                            partTokens.remove(at: index)
                        }
                    }
                    let text = (containsThrowsFunction ? "try " : "") + formatter.format(tokens: partTokens)
                    let capturedExpression = CapturedExpression(text: text, column: column, source: source, expression: part)
                    capturedExpressions.append(capturedExpression)
                case "call_expr":
                    let tokens = formatter.tokenize(source: wholeSource)

                    var extendedRange = partRange
                    if let overlappedExpression = findFirst(asserttion.expression, where: { $0.rawValue == "member_ref_expr" && $0.range.start < part.range.start && part.range.start < $0.range.end && $0.range.end < part.range.end }) {
                        // FIXME: Extend to receiver
                        // Workaround for `XCTAssertTrue(db.schemaCache.primaryKey("items") == nil)`
                        // https://github.com/groue/GRDB.swift/blob/c6ab92e60a670c5042d9519f1d6f5a95e6f054ec/Tests/GRDBTests/DatabasePoolSchemaCacheTests.swift#L22
                        extendedRange = SourceRange(start: overlappedExpression.range.start, end: partRange.end)
                    } else {
                        // FIXME: Extend to receiver
                        // Workaround for `XCTAssertEqual(try tableRequest.select((Col.age * 2).aliased("ignored")).distinct().fetchCount(db), 0)`
                        // https://github.com/groue/GRDB.swift/blob/master/Tests/GRDBTests/QueryInterfaceRequestTests.swift#L118
                        let line = wholeRange.start.line
                        let c = wholeRange.start.column
                        var iterator = tokens.reversed().makeIterator()
                        while let token = iterator.next() {
                            let offset = token.location.line == 0 ? c : 0
                            if SourceLocation(line: token.location.line + line, column: token.location.column + offset) < partRange.end {
                                break
                            }
                        }
                        var stack = [String]()
                        while let token = iterator.next() {
                            if token.value == ")" {
                                stack.append(")")
                            }
                            if token.value == "(" && !stack.isEmpty {
                                stack.removeLast()
                            }
                            let offset = token.location.line == 0 ? c : 0
                            if SourceLocation(line: token.location.line + line, column: token.location.column + offset) <= partRange.start {
                                break
                            }
                        }
                        if !stack.isEmpty {
                            while let token = iterator.next() {
                                let offset = token.location.line == 0 ? c : 0
                                if token.value == ")" {
                                    stack.append(")")
                                }
                                if token.value == "(" {
                                    stack.removeLast()
                                }
                                if stack.isEmpty {
                                    extendedRange = SourceRange(start: SourceLocation(line: token.location.line + line, column: token.location.column + offset), end: extendedRange.end)
                                    break
                                }
                            }
                        }
                    }

                    let source = completion.completeSource(range: extendedRange)
                    if source.hasPrefix("#") {
                        return
                    }
                    // FIXME: Extend expression source to a receiver
                    if source.hasPrefix("?") || source.hasPrefix("!") {
                        return
                    }
                    let column = columnInFunctionCall(start: wholeRange.start, target: part.location, tokens: tokens)

                    // FIXME
                    var containsThrowsFunction = false
                    traverse(part) { (expression, _) in
                        guard !containsThrowsFunction else { return }
                        containsThrowsFunction = expression.rawValue == "call_expr" && expression.throwsModifier == "throws"
                    }
                    var partTokens = formatter.tokenize(source: source)
                    if containsThrowsFunction {
                        var iterator = partTokens.enumerated().makeIterator()
                        var tryOperatorIndices = [Int]()
                        while let (index, token) = iterator.next() {
                            switch token.type {
                            case .token where token.value == "try":
                                tryOperatorIndices.append(index)
                                if let (index, token) = iterator.next() {
                                    switch token.type {
                                    case .token where token.value == "?" ||  token.value == "!":
                                        tryOperatorIndices.append(index)
                                    default:
                                        break
                                    }
                                }
                            default:
                                break
                            }
                        }
                        for index in tryOperatorIndices {
                            partTokens.remove(at: index)
                        }
                    }
                    var formatted = (containsThrowsFunction ? "try " : "") + formatter.format(tokens: partTokens, withHint: part)
                    if source.hasPrefix(".") || part.type!.contains("<") || part.argumentLabels == "nilLiteral:" {
                        formatted = formatted + " as \(part.type!.replacingOccurrences(of: "@lvalue ", with: ""))"
                    }

                    let capturedExpression = CapturedExpression(text: formatted, column: column, source: source, expression: part)
                    capturedExpressions.append(capturedExpression)
                case "dot_syntax_call_expr" where !part.type.contains("->"):
                    let source = completion.completeSource(range: partRange)
                    let tokens = formatter.tokenize(source: wholeSource)
                    let column = columnInFunctionCall(start: wholeRange.start, target: part.location, tokens: tokens)
                    let formatted = formatter.format(tokens: formatter.tokenize(source: source), withHint: part)
                    let text = formatted + " as \(part.type!.replacingOccurrences(of: "@lvalue ", with: ""))"
                    let capturedExpression = CapturedExpression(text: text, column: column, source: source, expression: part)
                    capturedExpressions.append(capturedExpression)
                case "binary_expr", "prefix_unary_expr":
                    // FIXME
                    var widestRange = partRange
                    traverse(part) { (expression, stop) in
                        if let range = expression.range  {
                            if range.start < widestRange.start {
                                widestRange = SourceRange(start: range.start, end: widestRange.end)
                            }
                            if range.end > widestRange.end {
                                widestRange = SourceRange(start: widestRange.start, end: range.end)
                            }
                        }
                    }
                    let source = completion.completeSource(range: widestRange)
                    let tokens = formatter.tokenize(source: wholeSource)
                    let column = columnInFunctionCall(start: wholeRange.start, target: part.location, tokens: tokens)

                    // FIXME
                    var containsThrowsFunction = false
                    traverse(part) { (expression, _) in
                        guard !containsThrowsFunction else { return }
                        containsThrowsFunction = expression.rawValue == "call_expr" && expression.throwsModifier == "throws"
                    }
                    var partTokens = formatter.tokenize(source: source)
                    if containsThrowsFunction {
                        var iterator = partTokens.enumerated().makeIterator()
                        var tryOperatorIndices = [Int]()
                        while let (index, token) = iterator.next() {
                            switch token.type {
                            case .token where token.value == "try":
                                tryOperatorIndices.append(index)
                                if let (index, token) = iterator.next() {
                                    switch token.type {
                                    case .token where token.value == "?" ||  token.value == "!":
                                        tryOperatorIndices.append(index)
                                    default:
                                        break
                                    }
                                }
                            default:
                                break
                            }
                        }
                        for index in tryOperatorIndices {
                            partTokens.remove(at: index)
                        }
                    }
                    var text = (containsThrowsFunction ? "try " : "") + formatter.format(tokens: partTokens)
                    text = "(\(text)) as (\(part.type!.replacingOccurrences(of: "@lvalue ", with: "")))"
                    let capturedExpression = CapturedExpression(text: text, column: column, source: source, expression: part)
                    capturedExpressions.append(capturedExpression)
                case "if_expr":
                    let source = completion.completeSource(range: partRange)
                    let tokens = formatter.tokenize(source: wholeSource)
                    let column = columnInFunctionCall(start: wholeRange.start, target: part.location, tokens: tokens)
                    let text = formatter.format(source: source)
                    let capturedExpression = CapturedExpression(text: text, column: column, source: source, expression: part)
                    capturedExpressions.append(capturedExpression)
                case "closure_expr":
                    stop = true
                    return
                default:
                    break
                }
            }
        }

        // FIXME
        var expressions = [CapturedExpression]()
        let groupedExpressions = Dictionary(grouping: capturedExpressions) { $0.column }
        let conflicts = groupedExpressions.filter { $1.count > 1 }
        for conflict in conflicts {
            let filtered = conflict.value.filter {
                let source = $0.source
                let column = $0.column
                let expression = $0.expression
                return !capturedExpressions.contains {
                    return $0.source == source && $0.column != column && $0.expression.range == expression.range
                }
            }
            expressions.append(contentsOf: filtered)
        }
        expressions.append(contentsOf: groupedExpressions.filter { $1.count == 1 }.flatMap { $0.value })
        return Array(Set(expressions)).sorted()
    }

    private func columnInFunctionCall(start: SourceLocation, target: SourceLocation, tokens: [Token]) -> Int {
        let location: SourceLocation
        if target.line == start.line {
            location = SourceLocation(line: target.line - start.line, column: target.column - start.column)
        } else {
            location = SourceLocation(line: target.line - start.line, column: target.column)
        }

        var source = ""
        var column = 0
        for token in tokens {
            if location.line == token.location.line {
                if case .indent = token.type {
                    continue
                }
                column = token.location.column
                for character in token.formattedValue {
                    let s = String(character)
                    source += s
                    column += s.utf8.count
                    if column >= location.column {
                        return __Util.displayWidth(of: source)
                    }
                }
            } else {
                if case .indent = token.type {
                    continue
                } else {
                    source += token.formattedValue
                }
            }
        }
        return __Util.displayWidth(of: source)
    }
}
