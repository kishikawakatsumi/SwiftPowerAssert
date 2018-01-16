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

struct Assertion {
    let expression: Expression
    let numberOfArguments: Int
    let assertFunction: String
    let binaryOperator: String
    let sourceFile: SourceFile

    let sourceRange: SourceRange
    let lineNumber: UInt

    var hasOperator: Bool {
        return !binaryOperator.isEmpty
    }

    fileprivate init(expression: Expression, numberOfArguments: Int, assertFunction: String, binaryOperator: String, _ sourceFile: SourceFile) {
        self.expression = expression
        self.numberOfArguments = numberOfArguments
        self.assertFunction = assertFunction
        self.binaryOperator = binaryOperator
        self.sourceFile = sourceFile

        self.sourceRange = expression.range
        self.lineNumber = UInt(expression.location.line + 1)
    }

    static func make(from expression: Expression, in sourceFile: SourceFile) -> Assertion? {
        guard !expression.expressions.isEmpty else { return nil }
        guard let decl = expression.expressions[0].decl else { return nil }
        switch decl {
        case "Swift.(file).assert(_:_:file:line:)",
             "XCTest.(file).XCTAssert(_:_:file:line:)",
             "XCTest.(file).XCTAssertTrue(_:_:file:line:)":
            return Assertion(expression: expression, numberOfArguments: 1, assertFunction: "assertBoolean", binaryOperator: "==", sourceFile)
        case "XCTest.(file).XCTAssertFalse(_:_:file:line:)":
            return Assertion(expression: expression, numberOfArguments: 1, assertFunction: "assertBoolean", binaryOperator: "!=", sourceFile)
        case "XCTest.(file).XCTAssertEqual(_:_:_:file:line:)":
            return Assertion(expression: expression, numberOfArguments: 2, assertFunction: "assertEquality", binaryOperator: "==", sourceFile)
        case "XCTest.(file).XCTAssertNotEqual(_:_:_:file:line:)":
            return Assertion(expression: expression, numberOfArguments: 2, assertFunction: "assertEquality", binaryOperator: "!=", sourceFile)
        case "XCTest.(file).XCTAssertGreaterThan(_:_:_:file:line:)":
            return Assertion(expression: expression, numberOfArguments: 2, assertFunction: "assertComparable", binaryOperator: ">", sourceFile)
        case "XCTest.(file).XCTAssertGreaterThanOrEqual(_:_:_:file:line:)":
            return Assertion(expression: expression, numberOfArguments: 2, assertFunction: "assertComparable", binaryOperator: ">=", sourceFile)
        case "XCTest.(file).XCTAssertLessThanOrEqual(_:_:_:file:line:)":
                return Assertion(expression: expression, numberOfArguments: 2, assertFunction: "assertComparable", binaryOperator: "<=", sourceFile)
        case "XCTest.(file).XCTAssertLessThan(_:_:_:file:line:)":
            return Assertion(expression: expression, numberOfArguments: 2, assertFunction: "assertComparable", binaryOperator: "<", sourceFile)
        case "XCTest.(file).XCTAssertNil(_:_:file:line:)":
            return Assertion(expression: expression, numberOfArguments: 1, assertFunction: "assertNil", binaryOperator: "==", sourceFile)
         case "XCTest.(file).XCTAssertNotNil(_:_:file:line:)":
            return Assertion(expression: expression, numberOfArguments: 1, assertFunction: "assertNil", binaryOperator: "!=", sourceFile)
        default:
            return nil
        }
    }

    func assertion() -> String {
        let source = sourceFile[expression.range]
        let tupleExpression = findFirstParent(expression) { return $0.rawValue == "autoclosure_expr" }!
        let formatter = SourceFormatter()
        return formatter.escaped(tokens: formatter.tokenize(source: source), withHint: tupleExpression)
    }

    func argumentExpressions() -> [Expression] {
        let tupleExpression = findFirstParent(expression) { return $0.rawValue == "autoclosure_expr" }!
        return Array(tupleExpression.expressions.prefix(numberOfArguments))
    }

    func argumentSources() -> [String] {
        let tupleExpression = findFirstParent(expression) { return $0.rawValue == "autoclosure_expr" }!
        let argumentExpressions = tupleExpression.expressions
        var sources = [String]()
        for (index, expression) in argumentExpressions.enumerated() {
            var widestRange = expression.range!
            traverse(expression) { (expression, stop) in
                if let range = expression.range  {
                    if range.start < widestRange.start {
                        widestRange = SourceRange(start: range.start, end: widestRange.end)
                    }
                    if range.end > widestRange.end {
                        widestRange = SourceRange(start: widestRange.start, end: range.end)
                    }
                }
            }
            if index + 1 < argumentExpressions.count {
                let source = sourceFile[SourceRange(start: widestRange.start, end: argumentExpressions[index + 1].range.start)]
                for (index, character) in source.reversed().enumerated() {
                    if character == "," {
                        sources.append(String(source[source.startIndex..<source.index(source.endIndex, offsetBy: -(index + 1))]))
                        break
                    }
                }
            } else {
                let source = sourceFile[SourceRange(start: widestRange.start, end: tupleExpression.range.end)]
                for (index, character) in source.reversed().enumerated() {
                    if character == ")" {
                        sources.append(String(source[source.startIndex..<source.index(source.endIndex, offsetBy: -(index + 1))]))
                        break
                    }
                }
            }
        }
        return Array(sources.prefix(numberOfArguments))
    }
}

extension Assertion: Hashable {
    var hashValue: Int {
        return sourceRange.hashValue
    }

    static func ==(lhs: Assertion, rhs: Assertion) -> Bool {
        return lhs.sourceRange == rhs.sourceRange
    }
}
