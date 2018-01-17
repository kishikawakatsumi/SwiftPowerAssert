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

class SourceCompletion {
    let sourceFile: SourceFile
    let expression: Expression

    let tupleExpression: Expression
    let boundaries: [SourceLocation]

    init(expression: Expression, sourceFile: SourceFile) {
        self.expression = expression
        self.sourceFile = sourceFile

        tupleExpression = findFirstParent(expression) { $0.rawValue == "autoclosure_expr" }!

        var boundaries = OrderedSet<SourceLocation>()
        traverse(expression) { (expression, stop) in
            // FIXME: Needs introspection
            guard let range = expression.range else {
                return
            }
            if expression.rawValue == "declref_expr" {
                boundaries.append(range.start)
            }
            if expression.rawValue == "call_expr" && !expression.isImplicit {
                boundaries.append(range.start)
                boundaries.append(range.end)
            }
            if expression.rawValue == "member_ref_expr" {
                boundaries.append(SourceLocation(line: range.end.line, column: range.end.column - 2 /* foo.b -> foo */))
            }
            if expression.rawValue == "string_literal_expr" {
                boundaries.append(range.start)
            }
            if expression.rawValue == "paren_expr" {
                boundaries.append(SourceLocation(line: range.end.line, column: range.end.column - 1 /* ...foo) -> foo */))
            }
        }
        let source = sourceFile[expression.range]

        let formatter = SourceFormatter()
        let tokens = formatter.tokenize(source: source)
        let line = expression.range.start.line
        let column = expression.range.start.column

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

    func completeSource(range: SourceRange) -> String {
        var nextBoundary = tupleExpression.range.end
        for boundary in boundaries {
            if range.end <= boundary {
                nextBoundary = boundary
                break
            }
        }
        let range = SourceRange(start: range.start, end: SourceLocation(line: nextBoundary.line, column: nextBoundary.column))
        return sourceFile[range]
    }

    func completeStringLiteral(_ child: Expression, _ parent: Expression) -> String {
        var source =  sourceFile[child.range]
        let rest = extendSourceToEnd(child, parent)
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

    private func extendSourceToEnd(_ child: Expression, _ parent: Expression) -> String {
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
}
