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
        for line in source.split(separator: "\n", omittingEmptySubsequences: false) {
            sourceLines.append(SourceLine(text: String(line).utf8, lineNumber: lineNumber, offset: offset))
            lineNumber += 1
            offset += line.utf8.count + 1 // characters + newline
        }
        self.sourceFile = SourceFile(sourceText: source.utf8, sourceLines: sourceLines)
        self.verbose = verbose
    }

    func transform(node: AST) -> String {
        var assertions = OrderedSet<Assertion>()
        node.declarations.forEach {
            switch $0 {
            case .topLevelCode(let declaration):
                declaration.statements.forEach {
                    switch $0 {
                    case .declaration(let declaration):
                        switch declaration {
                        case .function(let declaration):
                            declaration.body.forEach {
                                switch $0 {
                                case .expression(let expression):
                                    traverse(expression) { (expression, _) in
                                        if expression.rawValue == "call_expr", !expression.expressions.isEmpty {
                                            if let assertion = Assertion.make(from: expression, in: sourceFile) {
                                                assertions.append(assertion)
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
                    case .expression(let expression):
                        traverse(expression) { (expression, _) in
                            if expression.rawValue == "call_expr", !expression.expressions.isEmpty {
                                if let assertion = Assertion.make(from: expression, in: sourceFile) {
                                    assertions.append(assertion)
                                }
                            }
                        }
                    }
                }
            case .struct(let declaration):
                declaration.members.forEach {
                    switch $0 {
                    case .declaration(let declaration):
                        switch declaration {
                        case .function(let declaration):
                            declaration.body.forEach {
                                switch $0 {
                                case .expression(let expression):
                                    traverse(expression) { (expression, _) in
                                        if expression.rawValue == "call_expr", !expression.expressions.isEmpty {
                                            if let assertion = Assertion.make(from: expression, in: sourceFile) {
                                                assertions.append(assertion)
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
            case .class(let declaration):
                declaration.members.forEach {
                    switch $0 {
                    case .declaration(let declaration):
                        switch declaration {
                        case .function(let declaration):
                            declaration.body.forEach {
                                switch $0 {
                                case .expression(let expression):
                                    traverse(expression) { (expression, _) in
                                        if expression.rawValue == "call_expr", !expression.expressions.isEmpty {
                                            if let assertion = Assertion.make(from: expression, in: sourceFile) {
                                                assertions.append(assertion)
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
            case .enum(let declaration):
                declaration.members.forEach {
                    switch $0 {
                    case .declaration(let declaration):
                        switch declaration {
                        case .function(let declaration):
                            declaration.body.forEach {
                                switch $0 {
                                case .expression(let expression):
                                    traverse(expression) { (expression, _) in
                                        if expression.rawValue == "call_expr", !expression.expressions.isEmpty {
                                            if let assertion = Assertion.make(from: expression, in: sourceFile) {
                                                assertions.append(assertion)
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
            case .extension(let declaration):
                declaration.members.forEach {
                    switch $0 {
                    case .declaration(let declaration):
                        switch declaration {
                        case .function(let declaration):
                            declaration.body.forEach {
                                switch $0 {
                                case .expression(let expression):
                                    traverse(expression) { (expression, _) in
                                        if expression.rawValue == "call_expr", !expression.expressions.isEmpty {
                                            if let assertion = Assertion.make(from: expression, in: sourceFile) {
                                                assertions.append(assertion)
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

        let processor = AssertionProcessor(sourceFile: sourceFile, verbose: verbose)
        let replacements = processor.process(Array(assertions))
        
        var sourceText = sourceFile.sourceText
        for replacement in replacements.reversed() {
            let range = replacement.sourceRange
            let enhancedSource = replacement.sourceText

            let startIndex: String.Index
            if range.start.line > 0 {
                startIndex = sourceText.index(sourceText.startIndex, offsetBy: sourceFile.sourceLines[range.start.line].offset + range.start.column)
            } else {
                startIndex = sourceText.index(sourceText.startIndex, offsetBy: range.start.column)
            }
            let endIndex: String.Index
            if range.end.line > 0 {
                endIndex = sourceText.index(sourceText.startIndex, offsetBy: sourceFile.sourceLines[range.end.line].offset + range.end.column)
            } else {
                endIndex = sourceText.index(sourceText.startIndex, offsetBy: range.end.column)
            }
            let prefix = sourceText.prefix(upTo: startIndex)
            let suffix = sourceText.suffix(from: endIndex)
            sourceText =
                (String(prefix)! +
                enhancedSource + String(repeating: "\n", count: range.end.line - range.start.line)
                + String(suffix)!).utf8
        }

        return String(sourceText)
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
    for child in expression.expressions {
        if let found = findFirst(child, where: closure) {
            return found
        }
    }
    return nil
}

func findFirstParent(_ expression: Expression, where closure: (_ expression: Expression) -> Bool) -> Expression? {
    for child in expression.expressions {
        if closure(child) {
            return expression
        }
        if let expression = findFirstParent(child, where: closure) {
            return expression
        }
    }
    return nil
}
