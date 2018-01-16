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

struct AssertionProcessor {
    let sourceFile: SourceFile
    let verbose: Bool

    func process(_ assertions: [Assertion]) -> [Replacement] {
        return assertions.map { Replacement(sourceRange: $0.sourceRange, sourceText: process($0)) }
    }

    private func process(_ assertion: Assertion) -> String {
        let inUnitTests = NSClassFromString("XCTest") != nil

        let captor = ArgumentCaptor(sourceFile: sourceFile)
        let expressions = captor.captureArguments(assertion)

        let formatter = SourceFormatter()
        let argumentSource = zip(assertion.argumentSources(), assertion.argumentExpressions()).map { formatter.format(tokens: formatter.tokenize(source: $0), withHint: $1) }.joined(separator: ", ")

        if includesHigerOrderFunctions(assertion) || expressions.count > 30 {
            // Workaround for 'expression was too complex to be solved in reasonable time'
            let random = "__" + UUID().uuidString.replacingOccurrences(of: "-", with: "")
            return """
                var \(random) = __ValueRecorder(assertion: "\(assertion.assertion())", lineNumber: \(assertion.lineNumber), verbose: \(verbose), inUnitTests: \(inUnitTests));
                \(random) = \(random).\(assertion.assertFunction)(\(argumentSource), op: \(assertion.binaryOperator));
                \({
                    return expressions.reduce("") { (source, expression) -> String in
                        return source + "\(random) = \(random).record(expression: \(expression.text), column: \(expression.column));"
                    }
                }())
                \(random).render();
                """.replacingOccurrences(of: "\n", with: "")
        } else {
            return """
                __ValueRecorder(assertion: "\(assertion.assertion())", lineNumber: \(assertion.lineNumber), verbose: \(verbose), inUnitTests: \(inUnitTests))
                .\(assertion.assertFunction)(\(argumentSource), op: \(assertion.binaryOperator))
                \({
                    return expressions.reduce("") { (source, expression) -> String in
                        return source + ".record(expression: \(expression.text), column: \(expression.column))"
                    }
                }())
                .render()
                """.replacingOccurrences(of: "\n", with: "")
        }
    }

    private func includesHigerOrderFunctions(_ assertion: Assertion) -> Bool {
        return findFirst(assertion.expression) { (expression) -> Bool in
            if let decl = expression.decl, decl.hasPrefix("Swift.(file)") {
                return decl.hasSuffix(".map") || decl.hasSuffix(".flatMap") || decl.hasSuffix(".compactMap") ||
                    decl.hasSuffix(".filter") || decl.hasSuffix(".reduce")
            }
            return false
        } != nil
    }
}
