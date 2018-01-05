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
import Basic

class Transformer {
    let sourceFile: SourceFile
    let verbose: Bool

    init(source: String, verbose: Bool = false) {
        var lineNumber = 1
        var offset = 0
        var sourceLines = [SourceLine]()
        source.enumerateLines { (line, stop) in
            sourceLines.append(SourceLine(text: line.utf8, lineNumber: lineNumber, offset: offset))
            lineNumber += 1
            offset += line.utf8.count + 1 // characters + newline
        }
        self.sourceFile = SourceFile(sourceText: source.utf8, sourceLines: sourceLines)
        self.verbose = verbose
    }

    func transform(node: AST) -> String {
        var expressions = OrderedSet<ExpressionMap>()

        node.declarations.forEach {
            switch $0 {
            case .class(let declaration) where declaration.typeInheritance == "XCTestCase":
                declaration.members.forEach {
                    switch $0 {
                    case .declaration(let declaration):
                        switch declaration {
                        case .function(let declaration) where declaration.name.hasPrefix("test"):
                            declaration.body.forEach {
                                switch $0 {
                                case .expression(let expression):
                                    traverse(expression) { (expression, _) in
                                        if expression.rawValue == "call_expr", !expression.expressions.isEmpty, let decl = expression.expressions[0].decl {
                                            switch decl {
                                            case "Swift.(file).assert(_:_:file:line:)",
                                                 "XCTest.(file).XCTAssert(_:_:file:line:)",
                                                 "XCTest.(file).XCTAssertTrue(_:_:file:line:)",
                                                 "XCTest.(file).XCTAssertFalse(_:_:file:line:)",
                                                 "XCTest.(file).XCTAssertEqual(_:_:_:file:line:)",
                                                 "XCTest.(file).XCTAssertNotEqual(_:_:_:file:line:)",
                                                 "XCTest.(file).XCTAssertGreaterThan(_:_:_:file:line:)",
                                                 "XCTest.(file).XCTAssertGreaterThanOrEqual(_:_:_:file:line:)",
                                                 "XCTest.(file).XCTAssertLessThanOrEqual(_:_:_:file:line:)",
                                                 "XCTest.(file).XCTAssertLessThan(_:_:_:file:line:)":
                                                expressions.append(ExpressionMap(sourceRange: expression.range, expression: expression))
                                            default:
                                                break
                                            }
                                        }
                                    }
                                default:
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

        var replacements = [Replacement]()
        for expressionMap in expressions {
            let source = instrument(functionCall: expressionMap.expression)
            replacements.append(Replacement(sourceRange: expressionMap.sourceRange, sourceText: source))
        }

        var sourceText = sourceFile.sourceText
        for replacement in replacements.reversed() {
            let sourceRange = replacement.sourceRange
            let transformedSource = replacement.sourceText

            let startIndex: String.Index
            if sourceRange.start.line > 0 {
                startIndex = sourceText.index(sourceText.startIndex, offsetBy: sourceFile.sourceLines[sourceRange.start.line].offset + sourceRange.start.column)
            } else {
                startIndex = sourceText.index(sourceText.startIndex, offsetBy: sourceRange.start.column)
            }
            let endIndex: String.Index
            if sourceRange.end.line > 0 {
                endIndex = sourceText.index(sourceText.startIndex, offsetBy: sourceFile.sourceLines[sourceRange.end.line].offset + sourceRange.end.column)
            } else {
                endIndex = sourceText.index(sourceText.startIndex, offsetBy: sourceRange.end.column)
            }
            let prefix = sourceText.prefix(upTo: startIndex)
            let suffix = sourceText.suffix(from: endIndex)
            sourceText = (String(prefix)! + transformedSource + String(suffix)!).utf8
        }

        return String(sourceText)
    }

    private func instrument(functionCall expression: Expression) -> String {
        if !expression.expressions.isEmpty, let decl = expression.expressions[0].decl {
            switch decl {
            case "Swift.(file).assert(_:_:file:line:)",
                 "XCTest.(file).XCTAssert(_:_:file:line:)",
                 "XCTest.(file).XCTAssertTrue(_:_:file:line:)":
                let values = recordValues(expression, 1)
                return instrument(expression: expression, with: values)
            case "XCTest.(file).XCTAssertFalse(_:_:file:line:)":
                let values = recordValues(expression, 1)
                return instrument(expression: expression, with: values, failureCondition: true)
            case "XCTest.(file).XCTAssertEqual(_:_:_:file:line:)":
                if let tupleExpression = findFirst(expression, where: { $0.rawValue == "tuple_expr" }) {
                    let values = recordValues(expression, 2)
                    return instrument(equality: expression, tupleExpression: tupleExpression, values: values)
                }
            case "XCTest.(file).XCTAssertNotEqual(_:_:_:file:line:)":
                if let tupleExpression = findFirst(expression, where: { $0.rawValue == "tuple_expr" }) {
                    let values = recordValues(expression, 2)
                    return instrument(equality: expression, tupleExpression: tupleExpression, values: values, failureCondition: true)
                }
            case "XCTest.(file).XCTAssertGreaterThan(_:_:_:file:line:)":
                if let tupleExpression = findFirst(expression, where: { $0.rawValue == "tuple_expr" }) {
                    let values = recordValues(expression, 2)
                    return instrument(greaterThan: expression, tupleExpression: tupleExpression, values: values)
                }
            case "XCTest.(file).XCTAssertGreaterThanOrEqual(_:_:_:file:line:)":
                if let tupleExpression = findFirst(expression, where: { $0.rawValue == "tuple_expr" }) {
                    let values = recordValues(expression, 2)
                    return instrument(greaterThanOrEqual: expression, tupleExpression: tupleExpression, values: values)
                }
            case "XCTest.(file).XCTAssertLessThanOrEqual(_:_:_:file:line:)":
                if let tupleExpression = findFirst(expression, where: { $0.rawValue == "tuple_expr" }) {
                    let values = recordValues(expression, 2)
                    return instrument(greaterThan: expression, tupleExpression: tupleExpression, values: values, failureCondition: true)
                }
            case "XCTest.(file).XCTAssertLessThan(_:_:_:file:line:)":
                if let tupleExpression = findFirst(expression, where: { $0.rawValue == "tuple_expr" }) {
                    let values = recordValues(expression, 2)
                    return instrument(greaterThanOrEqual: expression, tupleExpression: tupleExpression, values: values, failureCondition: true)
                }
            default:
                break
            }
        }
        return sourceFile[expression.range]
    }

    private func recordValues(_ expression: Expression, _ numberOfParameters: Int) -> [Int: String] {
        var values = [Int: String]()
        let formatter = SourceFormatter()
        let completion = SourceCompletion(expression: expression, numberOfParameters: numberOfParameters, sourceFile: sourceFile)

        traverse(expression) { (childExpression, stop) in
            if childExpression == completion.sentinelExpression {
                stop = true
                return
            }
            guard let wholeRange = expression.range, let partRange = childExpression.range, wholeRange != partRange else {
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
                values[column] = formatter.format(source: source)
            case "magic_identifier_literal_expr":
                let source = completion.completeSource(expression: childExpression)
                let tokens = formatter.tokenize(source: wholeExpressionSource)
                let column = columnInFunctionCall(start: wholeRange.start, target: partRange.end, tokens: tokens)
                switch source {
                case "#column":
                    values[column] = "\(childExpression.location.column)"
                case "#line":
                    values[column] = "\(childExpression.location.line + 1)"
                default:
                    values[column] = formatter.format(source: source)
                }
            case "member_ref_expr" where !childExpression.type.contains("->"):
                let source = completion.completeSource(expression: childExpression)
                let tokens = formatter.tokenize(source: wholeExpressionSource)
                let column = columnInFunctionCall(start: wholeRange.start, target: partRange.end, tokens: tokens)
                if source.hasPrefix(".") {
                    values[column] = childExpression.type.replacingOccurrences(of: "@lvalue ", with: "") + formatter.format(source: source)
                } else {
                    values[column] = formatter.format(source: source)
                }
            case "dot_self_expr":
                let source = completion.completeSource(expression: childExpression)
                let tokens = formatter.tokenize(source: wholeExpressionSource)
                let column = columnInFunctionCall(start: wholeRange.start, target: partRange.end, tokens: tokens)
                if source.hasPrefix(".") {
                    values[column] = childExpression.type.replacingOccurrences(of: "@lvalue ", with: "") + formatter.format(source: source)
                } else {
                    values[column] = formatter.format(source: source)
                }
            case "tuple_element_expr", "keypath_expr":
                let source = completion.completeSource(expression: childExpression)
                let tokens = formatter.tokenize(source: wholeExpressionSource)
                let column = columnInFunctionCall(start: wholeRange.start, target: partRange.end, tokens: tokens)
                values[column] = formatter.format(source: source) + " as \(childExpression.type!)"
            case "string_literal_expr":
                let source = stringLiteralExpression(childExpression, expression)
                let tokens = formatter.tokenize(source: wholeExpressionSource)
                let column = columnInFunctionCall(start: wholeRange.start, target: partRange.end, tokens: tokens)
                values[column] = formatter.format(source: source)
            case "array_expr", "dictionary_expr", "object_literal":
                let source = partExpressionSource
                let tokens = formatter.tokenize(source: wholeExpressionSource)
                let column = columnInFunctionCall(start: wholeRange.start, target: childExpression.location, tokens: tokens)
                values[column] = formatter.format(source: source) + " as \(childExpression.type!)"
            case "subscript_expr", "keypath_application_expr", "objc_selector_expr":
                let source = partExpressionSource
                let tokens = formatter.tokenize(source: wholeExpressionSource)
                let column = columnInFunctionCall(start: wholeRange.start, target: partRange.end, tokens: tokens)
                values[column] = formatter.format(source: source)
            case "call_expr":
                let source = completion.completeSource(expression: childExpression)
                let tokens = formatter.tokenize(source: wholeExpressionSource)
                let column = columnInFunctionCall(start: wholeRange.start, target: childExpression.location, tokens: tokens)
                let formatted = formatter.format(tokens: formatter.tokenize(source: source), withHint: childExpression)
                if !childExpression.expressions.isEmpty && childExpression.throwsModifier == "throws" {
                    values[column] = "try! " + formatted
                } else if childExpression.argumentLabels == "nilLiteral:" {
                    values[column] = formatted + " as \(childExpression.type!)"
                } else {
                    values[column] = formatted
                }
            case "binary_expr", "prefix_unary_expr":
                let source = completion.completeSource(expression: childExpression)
                let tokens = formatter.tokenize(source: wholeExpressionSource)
                var containsThrowsFunction = false
                traverse(childExpression) { (expression, _) in
                    guard !containsThrowsFunction else { return }
                    containsThrowsFunction = expression.rawValue == "call_expr" && expression.throwsModifier == "throws"
                }
                let column = columnInFunctionCall(start: wholeRange.start, target: childExpression.location, tokens: tokens)
                values[column] = (containsThrowsFunction ? "try! " : "") + formatter.format(source: source)
            case "if_expr":
                let source = completion.completeSource(expression: childExpression)
                let tokens = formatter.tokenize(source: wholeExpressionSource)
                let column = columnInFunctionCall(start: wholeRange.start, target: childExpression.location, tokens: tokens)
                values[column] = formatter.format(source: source)
            case "closure_expr":
                stop = true
                return
            default:
                break
            }
        }
        return values
    }

    func recordValuesCodeFragment(values: [Int: String]) -> String {
        var code = ""
        for (key, value) in values {
            code += "valueColumns[\(key)] = __Util.toString(\(value))\n"
        }
        return code
    }

    private func instrument(expression: Expression, with values: [Int: String], failureCondition: Bool = false) -> String {
        let expressionSource = sourceFile[expression.range]
        let tupleExpression = expression.expressions[1]
        let tupleExpressionSource = sourceFile[tupleExpression.range]
        let formatter = SourceFormatter()
        let recordValues = recordValuesCodeFragment(values: values)
        let condition = "__Util.equal(\(formatter.format(tokens: formatter.tokenize(source: tupleExpressionSource), withHint: tupleExpression)))"
        let assertion = formatter.escaped(tokens: formatter.tokenize(source: expressionSource), withHint: tupleExpression)
        return instrument(expression: expression, recordValues: recordValues, condition: condition, assertion: assertion, failureCondition: failureCondition)
    }

    private func instrument(equality expression: Expression, tupleExpression: Expression, values: [Int: String], failureCondition: Bool = false) -> String {
        let expressionSource = sourceFile[expression.range]
        let tupleExpressionSource = sourceFile[tupleExpression.range]
        let formatter = SourceFormatter()
        let recordValues = recordValuesCodeFragment(values: values)
        let condition = "__Util.equal(\(formatter.format(tokens: formatter.tokenize(source: tupleExpressionSource), withHint: tupleExpression)))"
        let assertion = formatter.escaped(tokens: formatter.tokenize(source: expressionSource), withHint: tupleExpression)
        return instrument(expression: expression, recordValues: recordValues, condition: condition, assertion: assertion, failureCondition: failureCondition)
    }

    private func instrument(greaterThan expression: Expression, tupleExpression: Expression, values: [Int: String], failureCondition: Bool = false) -> String {
        let expressionSource = sourceFile[expression.range]
        let tupleExpression = expression.expressions[1]
        let tupleExpressionSource = sourceFile[tupleExpression.range]
        let formatter = SourceFormatter()
        let recordValues = recordValuesCodeFragment(values: values)
        let condition = "__Util.greaterThan(\(formatter.format(tokens: formatter.tokenize(source: tupleExpressionSource), withHint: tupleExpression)))"
        let assertion = formatter.escaped(tokens: formatter.tokenize(source: expressionSource), withHint: tupleExpression)
        return instrument(expression: expression, recordValues: recordValues, condition: condition, assertion: assertion, failureCondition: failureCondition)
    }

    private func instrument(greaterThanOrEqual expression: Expression, tupleExpression: Expression, values: [Int: String], failureCondition: Bool = false) -> String {
        let expressionSource = sourceFile[expression.range]
        let tupleExpression = expression.expressions[1]
        let tupleExpressionSource = sourceFile[tupleExpression.range]
        let formatter = SourceFormatter()
        let recordValues = recordValuesCodeFragment(values: values)
        let condition = "__Util.greaterThanOrEqual(\(formatter.format(tokens: formatter.tokenize(source: tupleExpressionSource), withHint: tupleExpression)))"
        let assertion = formatter.escaped(tokens: formatter.tokenize(source: expressionSource), withHint: tupleExpression)
        return instrument(expression: expression, recordValues: recordValues, condition: condition, assertion: assertion, failureCondition: failureCondition)
    }

    private func instrument(expression: Expression, recordValues: String, condition: String, assertion: String, failureCondition: Bool = false) -> String {
        let inUnitTests = NSClassFromString("XCTest") != nil
        return """

        do {
            struct __Util {
                static func equal(_ parameters: (Bool)) -> Bool {
                    return parameters
                }
                static func equal(_ parameters: (condition: Bool, message: String)) -> Bool {
                    return parameters.condition
                }
                static func equal<T>(_ parameters: (lhs: T, rhs: T)) -> Bool where T: Equatable {
                    return parameters.lhs == parameters.rhs
                }
                static func equal<T>(_ parameters: (lhs: T, rhs: T, message: String)) -> Bool where T: Equatable {
                    return equal((parameters.lhs, parameters.rhs))
                }
                static func equal<T>(_ parameters: (lhs: T, rhs: T, message: String, file: StaticString)) -> Bool where T: Equatable {
                    return equal((parameters.lhs, parameters.rhs))
                }
                static func equal<T>(_ parameters: (lhs: T, rhs: T, message: String, file: StaticString, line: UInt)) -> Bool where T: Equatable {
                    return equal((parameters.lhs, parameters.rhs))
                }
                static func equal<T>(_ parameters: (lhs: T?, rhs: T?)) -> Bool where T: Equatable {
                    return parameters.lhs == parameters.rhs
                }
                static func equal<T>(_ parameters: (lhs: T?, rhs: T?, message: String)) -> Bool where T: Equatable {
                    return equal((parameters.lhs, parameters.rhs))
                }
                static func equal<T>(_ parameters: (lhs: T?, rhs: T?, message: String, file: StaticString)) -> Bool where T: Equatable {
                    return equal((parameters.lhs, parameters.rhs))
                }
                static func equal<T>(_ parameters: (lhs: T?, rhs: T?, message: String, file: StaticString, line: UInt)) -> Bool where T: Equatable {
                    return equal((parameters.lhs, parameters.rhs))
                }
                static func equal<T>(_ parameters: (lhs: [T], rhs: [T])) -> Bool where T: Equatable {
                    return parameters.lhs == parameters.rhs
                }
                static func equal<T>(_ parameters: (lhs: [T], rhs: [T], message: String)) -> Bool where T: Equatable {
                    return equal((parameters.lhs, parameters.rhs))
                }
                static func equal<T>(_ parameters: (lhs: [T], rhs: [T], message: String, file: StaticString)) -> Bool where T: Equatable {
                    return equal((parameters.lhs, parameters.rhs))
                }
                static func equal<T>(_ parameters: (lhs: [T], rhs: [T], message: String, file: StaticString, line: UInt)) -> Bool where T: Equatable {
                    return equal((parameters.lhs, parameters.rhs))
                }
                static func equal<T>(_ parameters: (lhs: ArraySlice<T>, rhs: ArraySlice<T>)) -> Bool where T: Equatable {
                    return parameters.lhs == parameters.rhs
                }
                static func equal<T>(_ parameters: (lhs: ArraySlice<T>, rhs: ArraySlice<T>, message: String)) -> Bool where T: Equatable {
                    return equal((parameters.lhs, parameters.rhs))
                }
                static func equal<T>(_ parameters: (lhs: ArraySlice<T>, rhs: ArraySlice<T>, message: String, file: StaticString)) -> Bool where T: Equatable {
                    return equal((parameters.lhs, parameters.rhs))
                }
                static func equal<T>(_ parameters: (lhs: ArraySlice<T>, rhs: ArraySlice<T>, message: String, file: StaticString, line: UInt)) -> Bool where T: Equatable {
                    return equal((parameters.lhs, parameters.rhs))
                }
                static func equal<T>(_ parameters: (lhs: ContiguousArray<T>, rhs: ContiguousArray<T>)) -> Bool where T: Equatable {
                    return parameters.lhs == parameters.rhs
                }
                static func equal<T>(_ parameters: (lhs: ContiguousArray<T>, rhs: ContiguousArray<T>, message: String)) -> Bool where T: Equatable {
                    return equal((parameters.lhs, parameters.rhs))
                }
                static func equal<T>(_ parameters: (lhs: ContiguousArray<T>, rhs: ContiguousArray<T>, message: String, file: StaticString)) -> Bool where T: Equatable {
                    return equal((parameters.lhs, parameters.rhs))
                }
                static func equal<T>(_ parameters: (lhs: ContiguousArray<T>, rhs: ContiguousArray<T>, message: String, file: StaticString, line: UInt)) -> Bool where T: Equatable {
                    return equal((parameters.lhs, parameters.rhs))
                }
                static func equal<T, U>(_ parameters: (lhs: [T: U], rhs: [T: U])) -> Bool where U: Equatable {
                    return parameters.lhs == parameters.rhs
                }
                static func equal<T, U>(_ parameters: (lhs: [T: U], rhs: [T: U], message: String)) -> Bool where U: Equatable {
                    return equal((parameters.lhs, parameters.rhs))
                }
                static func equal<T, U>(_ parameters: (lhs: [T: U], rhs: [T: U], message: String, file: StaticString)) -> Bool where U: Equatable {
                    return equal((parameters.lhs, parameters.rhs))
                }
                static func equal<T, U>(_ parameters: (lhs: [T: U], rhs: [T: U], message: String, file: StaticString, line: UInt)) -> Bool where U: Equatable {
                    return equal((parameters.lhs, parameters.rhs))
                }
                static func greaterThan<T>(_ parameters: (lhs: T, rhs: T)) -> Bool where T: Comparable {
                    return parameters.lhs > parameters.rhs
                }
                static func greaterThan<T>(_ parameters: (lhs: T, rhs: T, message: String)) -> Bool where T: Comparable {
                    return greaterThan((parameters.lhs, parameters.rhs))
                }
                static func greaterThan<T>(_ parameters: (lhs: T, rhs: T, message: String, file: StaticString)) -> Bool where T: Comparable {
                    return greaterThan((parameters.lhs, parameters.rhs))
                }
                static func greaterThan<T>(_ parameters: (lhs: T, rhs: T, message: String, file: StaticString, line: UInt)) -> Bool where T: Comparable {
                    return greaterThan((parameters.lhs, parameters.rhs))
                }
                static func greaterThanOrEqual<T>(_ parameters: (lhs: T, rhs: T)) -> Bool where T: Comparable {
                    return parameters.lhs >= parameters.rhs
                }
                static func greaterThanOrEqual<T>(_ parameters: (lhs: T, rhs: T, message: String)) -> Bool where T: Comparable {
                    return greaterThanOrEqual((parameters.lhs, parameters.rhs))
                }
                static func greaterThanOrEqual<T>(_ parameters: (lhs: T, rhs: T, message: String, file: StaticString)) -> Bool where T: Comparable {
                    return greaterThanOrEqual((parameters.lhs, parameters.rhs))
                }
                static func greaterThanOrEqual<T>(_ parameters: (lhs: T, rhs: T, message: String, file: StaticString, line: UInt)) -> Bool where T: Comparable {
                    return greaterThanOrEqual((parameters.lhs, parameters.rhs))
                }
                static func value(_ value: String) -> String {
                    return value
                        .replacingOccurrences(of: "\\"", with: "\\\\\\"")
                        .replacingOccurrences(of: "\\t", with: "\\\\t")
                        .replacingOccurrences(of: "\\r", with: "\\\\r")
                        .replacingOccurrences(of: "\\n", with: "\\\\n")
                        .replacingOccurrences(of: "\\0", with: "\\\\0")
                }
                static func toString<T>(_ value: T?) -> String {
                    switch value {
                    case .some(let v) where v is String || v is Selector: return "\\"\\(__Util.value("\\(v)"))\\""
                    case .some(let v): return "\\(v)".replacingOccurrences(of: "\\n", with: " ")
                    case .none: return "nil"
                    }
                }
            }
            var valueColumns = [Int: String]()
            let condition = { () -> Bool in
                \(recordValues)
                return \(condition)
            }()
            if \(verbose) || condition == \(failureCondition) {
                var message = ""
                func align(current: inout Int, column: Int, string: String) {
                    while current < column - 1 {
                        message += " "
                        current += 1
                    }
                    message += string
                    current += __DisplayWidth.of(string)
                }
                message += "\(assertion)\\n"
                var values = Array(valueColumns).sorted { $0.0 < $1.0 }
                var current = 0
                for value in values {
                    align(current: &current, column: value.0, string: "|")
                }
                message += "\\n"
                while !values.isEmpty {
                    var current = 0
                    var index = 0
                    while index < values.count {
                        if index == values.count - 1 || ((values[index].0 + values[index].1.count < values[index + 1].0) && values[index].1.unicodeScalars.filter({ !$0.isASCII }).isEmpty) {
                            align(current: &current, column: values[index].0, string: values[index].1)
                            values.remove(at: index)
                        } else {
                            align(current: &current, column: values[index].0, string: "|")
                            index += 1
                        }
                    }
                    message += "\\n"
                }
                \(inUnitTests ? "print(message, terminator: \"\")" : "")
                \(!inUnitTests ? "condition == \(failureCondition) ? XCTFail(\"\\n\" + message, line: \(expression.location.line + 1)) : ()" : "")
                \(!inUnitTests && verbose ? "print(message, terminator: \"\")" : "")
            }
        }

        """
    }

    private func stringLiteralExpression(_ child: Expression, _ parent: Expression) -> String {
        var source =  sourceFile[child.range]
        let rest = restOfExpression(child, parent)
        if rest.hasPrefix("\"\"") {
            // Multiline String Literal
            let normalized = rest.replacingOccurrences(of: "\\\"\"\"", with: "\\\"\\\"\\\"")
            if let range = normalized.range(of: "\"\"\"") {
                return source + normalized[..<range.upperBound]
            }
        } else {
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
        }
        return source + rest
    }

    private func restOfExpression(_ child: Expression, _ parent: Expression) -> String {
        let sourceText = sourceFile.sourceText
        let startIndex: String.Index
        if child.range.end.line > 0 {
            startIndex = sourceText.index(sourceText.startIndex, offsetBy: sourceFile.sourceLines[child.range.end.line].offset + child.range.end.column)
        } else {
            startIndex = sourceText.index(sourceText.startIndex, offsetBy: child.range.end.column)
        }
        let endIndex: String.Index
        if parent.range.end.line > 0 {
            endIndex = sourceText.index(sourceText.startIndex, offsetBy: sourceFile.sourceLines[parent.range.end.line].offset + parent.range.end.column)
        } else {
            endIndex = sourceText.index(sourceText.startIndex, offsetBy: parent.range.end.column)
        }

        return String(sourceText[startIndex..<endIndex])!
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
                        return __DisplayWidth.of(source)
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
        return __DisplayWidth.of(source)
    }
}

func traverse(_ expression: Expression, closure: (_ expression: Expression, _ stop: inout Bool) -> ()) {
    var stop = false
    closure(expression, &stop)
    if stop {
        return
    }
    for expression in expression.expressions {
        traverse(expression, closure: closure)
    }
}

func findFirst(_ expression: Expression, where closure: (_ expression: Expression) -> Bool) -> Expression? {
    if closure(expression) {
        return expression
    }
    for expression in expression.expressions {
        if let found = findFirst(expression, where: closure) {
            return found
        }
    }
    return nil
}

class SourceCompletion {
    let sourceFile: SourceFile
    let expression: Expression
    let numberOfParameters: Int

    let parenExpression: Expression
    let sentinelExpression: Expression?
    let boundaries: [SourceLocation]

    init(expression: Expression, numberOfParameters: Int, sourceFile: SourceFile) {
        self.expression = expression
        self.numberOfParameters = numberOfParameters
        self.sourceFile = sourceFile

        parenExpression = findFirst(expression) { $0.rawValue == "tuple_shuffle_expr" } ?? findFirst(expression) { $0.rawValue == "paren_expr" }!
        sentinelExpression = SourceCompletion.findSentinelExpression(expression: parenExpression, numberOfParameters)

        var boundaries = OrderedSet<SourceLocation>()
        traverse(expression) { (expression, stop) in
            if expression.rawValue == "declref_expr" {
                boundaries.append(expression.range.start)
            }
            if expression.rawValue == "call_expr" && !expression.isImplicit {
                boundaries.append(expression.range.start)
                boundaries.append(expression.range.end)
            }
            if expression.rawValue == "member_ref_expr" {
                boundaries.append(SourceLocation(line: expression.range.end.line, column: expression.range.end.column - 2 /* foo.b -> foo */))
            }
            if expression.rawValue == "string_literal_expr" {
                boundaries.append(expression.range.start)
            }
            if expression.rawValue == "paren_expr" {
                boundaries.append(SourceLocation(line: expression.range.end.line, column: expression.range.end.column - 1 /* ...foo) -> foo */))
            }
        }
        let source = sourceFile[parenExpression.range]

        let formatter = SourceFormatter()
        let tokens = formatter.tokenize(source: source)
        let line = parenExpression.range.start.line
        let column = parenExpression.range.start.column

        for token in tokens {
            let offset = token.location.line == 0 ? column : 0
            switch token.type {
            case .token:
                switch token.value {
                case ".", ",", " ", "\"", "\t", "\n", "(", "[", "{", ")", "]", "}", ":", ";", "?":
                    boundaries.append(SourceLocation(line: token.location.line + line, column: token.location.column + offset))
                default:
                    break
                }
            case .string:
                boundaries.append(SourceLocation(line: token.location.line + line, column: token.location.column + offset))
            case .multilineString:
                boundaries.append(SourceLocation(line: token.location.line + line, column: token.location.column + offset))
            case .newline:
                boundaries.append(SourceLocation(line: token.location.line + line, column: token.location.column + offset))
            case .indent(_):
                boundaries.append(SourceLocation(line: token.location.line + line, column: token.location.column + offset))
            case .whitespaces:
                boundaries.append(SourceLocation(line: token.location.line + line, column: token.location.column + offset))
            }
        }

        self.boundaries = boundaries.sorted()
    }

    func completeSource(expression: Expression) -> String {
        var nextBoundary = parenExpression.range.end
        for boundary in boundaries {
            if expression.range.end <= boundary {
                nextBoundary = boundary
                break
            }
        }
        let range = SourceRange(start: expression.range.start, end: SourceLocation(line: nextBoundary.line, column: nextBoundary.column))
        return sourceFile[range]
    }

    private static func findSentinelExpression(expression: Expression, _ numberOfParameters: Int) -> Expression? {
        var sentinel: Expression?
        var sentinelParent: Expression?
        var current: Expression?
        traverse(expression) { (childExpression, stop) in
            if childExpression.rawValue == "autoclosure_expr" {
                sentinelParent = current
                stop = true
                return
            }
            current = childExpression
        }
        if let sentinelParent = sentinelParent, numberOfParameters < sentinelParent.expressions.count {
            sentinel = sentinelParent.expressions[numberOfParameters]
        }
        return sentinel
    }
}

struct Replacement {
    let sourceRange: SourceRange
    let sourceText: String
}
