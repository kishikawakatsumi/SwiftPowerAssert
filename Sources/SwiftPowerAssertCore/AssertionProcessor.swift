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

    private func process(_ asserttion: Assertion) -> String {
        let inUnitTests = NSClassFromString("XCTest") != nil

        // Workaround for 'expression was too complex to be solved in reasonable time'
        let random = "__" + UUID().uuidString.replacingOccurrences(of: "-", with: "")

        let captor = ArgumentCaptor(sourceFile: sourceFile)
        let expressions = captor.captureArguments(asserttion)
        let recording = expressions.reduce("") { (source, expression) -> String in
            return source + "\(random) = \(random).record(expression: \(expression.text), column: \(expression.column));"
        }
        return """
            var \(random) = __ValueRecorder(assertion: "\(asserttion.assertion())", lineNumber: \(asserttion.lineNumber), verbose: \(verbose), inUnitTests: \(inUnitTests))
            .\(asserttion.assertFunction)(\(asserttion.condition())\(asserttion.hasOperator ? ", " + asserttion.binaryOperator : ""));
            \(recording)
            \(random).render();
            """.replacingOccurrences(of: "\n", with: "")
    }
}
