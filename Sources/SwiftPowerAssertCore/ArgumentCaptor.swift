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
        let completion = SourceCompletion(expression: asserttion.expression, numberOfArguments: asserttion.numberOfArguments, sourceFile: sourceFile)

        traverse(asserttion.expression) { (childExpression, stop) in
            if childExpression == completion.sentinelExpression {
                stop = true
                return
            }
            guard let wholeRange = asserttion.expression.range, let partRange = childExpression.range, wholeRange != partRange else {
                return
            }

            let wholeExpressionSource = sourceFile[wholeRange]
            let partExpressionSource = sourceFile[partRange]

            switch childExpression.rawValue {
            case "declref_expr" where !childExpression.type.contains("->"):
                let source = completion.completeSource(expression: childExpression)
                if source.hasPrefix("$") {
                    return
                }
                let tokens = formatter.tokenize(source: wholeExpressionSource)
                let column = columnInFunctionCall(start: wholeRange.start, target: partRange.end, tokens: tokens)
                let text = formatter.format(source: source)
                let capturedExpression = CapturedExpression(text: text, column: column, expression: childExpression)
                capturedExpressions.append(capturedExpression)
            case "magic_identifier_literal_expr":
                let source = completion.completeSource(expression: childExpression)
                let tokens = formatter.tokenize(source: wholeExpressionSource)
                let column = columnInFunctionCall(start: wholeRange.start, target: partRange.end, tokens: tokens)
                switch source {
                case "#column":
                    let text = "\(childExpression.location.column)"
                    let capturedExpression = CapturedExpression(text: text, column: column, expression: childExpression)
                    capturedExpressions.append(capturedExpression)
                case "#line":
                    let text = "\(childExpression.location.line + 1)"
                    let capturedExpression = CapturedExpression(text: text, column: column, expression: childExpression)
                    capturedExpressions.append(capturedExpression)
                default:
                    let text = formatter.format(source: source)
                    let capturedExpression = CapturedExpression(text: text, column: column, expression: childExpression)
                    capturedExpressions.append(capturedExpression)
                }
            case "member_ref_expr" where !childExpression.type.contains("->"):
                let source = completion.completeSource(expression: childExpression)
                let tokens = formatter.tokenize(source: wholeExpressionSource)
                let column = columnInFunctionCall(start: wholeRange.start, target: partRange.end, tokens: tokens)
                if source.hasPrefix(".") {
                    let text = childExpression.type.replacingOccurrences(of: "@lvalue ", with: "") + formatter.format(source: source)
                    let capturedExpression = CapturedExpression(text: text, column: column, expression: childExpression)
                    capturedExpressions.append(capturedExpression)
                } else {
                    let text = formatter.format(source: source)
                    let capturedExpression = CapturedExpression(text: text, column: column, expression: childExpression)
                    capturedExpressions.append(capturedExpression)
                }
            case "dot_self_expr":
                let source = completion.completeSource(expression: childExpression)
                let tokens = formatter.tokenize(source: wholeExpressionSource)
                let column = columnInFunctionCall(start: wholeRange.start, target: partRange.end, tokens: tokens)
                if source.hasPrefix(".") {
                    let text = childExpression.type.replacingOccurrences(of: "@lvalue ", with: "") + formatter.format(source: source)
                    let capturedExpression = CapturedExpression(text: text, column: column, expression: childExpression)
                    capturedExpressions.append(capturedExpression)
                } else {
                    let text = formatter.format(source: source)
                    let capturedExpression = CapturedExpression(text: text, column: column, expression: childExpression)
                    capturedExpressions.append(capturedExpression)
                }
            case "tuple_element_expr", "keypath_expr":
                let source = completion.completeSource(expression: childExpression)
                let tokens = formatter.tokenize(source: wholeExpressionSource)
                let column = columnInFunctionCall(start: wholeRange.start, target: partRange.end, tokens: tokens)
                let text = formatter.format(source: source) + " as \(childExpression.type!)"
                let capturedExpression = CapturedExpression(text: text, column: column, expression: childExpression)
                capturedExpressions.append(capturedExpression)
            case "string_literal_expr":
                let source = completion.completeStringLiteral(childExpression, asserttion.expression)
                let tokens = formatter.tokenize(source: wholeExpressionSource)
                let column = columnInFunctionCall(start: wholeRange.start, target: partRange.end, tokens: tokens)
                let text = formatter.format(source: source)
                let capturedExpression = CapturedExpression(text: text, column: column, expression: childExpression)
                capturedExpressions.append(capturedExpression)
            case "array_expr", "dictionary_expr", "object_literal":
                let source = partExpressionSource
                let tokens = formatter.tokenize(source: wholeExpressionSource)
                let column = columnInFunctionCall(start: wholeRange.start, target: childExpression.location, tokens: tokens)
                let text = formatter.format(source: source) + " as \(childExpression.type!)"
                let capturedExpression = CapturedExpression(text: text, column: column, expression: childExpression)
                capturedExpressions.append(capturedExpression)
            case "subscript_expr", "keypath_application_expr", "objc_selector_expr":
                let source = partExpressionSource
                let tokens = formatter.tokenize(source: wholeExpressionSource)
                let column = columnInFunctionCall(start: wholeRange.start, target: partRange.end, tokens: tokens)
                let text = formatter.format(source: source)
                let capturedExpression = CapturedExpression(text: text, column: column, expression: childExpression)
                capturedExpressions.append(capturedExpression)
            case "call_expr":
                let source = completion.completeSource(expression: childExpression)
                if source.hasPrefix("#") {
                    return
                }
                let tokens = formatter.tokenize(source: wholeExpressionSource)
                let column = columnInFunctionCall(start: wholeRange.start, target: childExpression.location, tokens: tokens)
                var formatted = formatter.format(tokens: formatter.tokenize(source: source), withHint: childExpression)
                if !childExpression.expressions.isEmpty && childExpression.throwsModifier == "throws" {
                    formatted = "try! " + formatted
                }
                if source.hasPrefix(".") || childExpression.argumentLabels == "nilLiteral:" {
                    formatted = formatted + " as \(childExpression.type!)"
                }
                let text = formatted
                let capturedExpression = CapturedExpression(text: text, column: column, expression: childExpression)
                capturedExpressions.append(capturedExpression)
            case "dot_syntax_call_expr" where !childExpression.type.contains("->"):
                let source = completion.completeSource(expression: childExpression)
                let tokens = formatter.tokenize(source: wholeExpressionSource)
                let column = columnInFunctionCall(start: wholeRange.start, target: childExpression.location, tokens: tokens)
                let formatted = formatter.format(tokens: formatter.tokenize(source: source), withHint: childExpression)
                let text = formatted + " as \(childExpression.type!)"
                let capturedExpression = CapturedExpression(text: text, column: column, expression: childExpression)
                capturedExpressions.append(capturedExpression)
            case "binary_expr", "prefix_unary_expr":
                let source = completion.completeSource(expression: childExpression)
                let tokens = formatter.tokenize(source: wholeExpressionSource)
                var containsThrowsFunction = false
                traverse(childExpression) { (expression, _) in
                    guard !containsThrowsFunction else { return }
                    containsThrowsFunction = expression.rawValue == "call_expr" && expression.throwsModifier == "throws"
                }
                let column = columnInFunctionCall(start: wholeRange.start, target: childExpression.location, tokens: tokens)
                let text = (containsThrowsFunction ? "try! " : "") + formatter.format(source: source)
                let capturedExpression = CapturedExpression(text: text, column: column, expression: childExpression)
                capturedExpressions.append(capturedExpression)
            case "if_expr":
                let source = completion.completeSource(expression: childExpression)
                let tokens = formatter.tokenize(source: wholeExpressionSource)
                let column = columnInFunctionCall(start: wholeRange.start, target: childExpression.location, tokens: tokens)
                let text = formatter.format(source: source)
                let capturedExpression = CapturedExpression(text: text, column: column, expression: childExpression)
                capturedExpressions.append(capturedExpression)
            case "closure_expr":
                stop = true
                return
            default:
                break
            }
        }

        var expressions = [CapturedExpression]()
        let groupedExpressions = Dictionary(grouping: capturedExpressions) { $0.column }
        let conflicts = groupedExpressions.filter { $1.count > 1 }
        for conflict in conflicts {
            let filtered = conflict.value.filter {
                let text = $0.text
                let column = $0.column
                let expression = $0.expression
                return !capturedExpressions.contains {
                    return $0.text == text && $0.column != column && $0.expression.range == expression.range
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
