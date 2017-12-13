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
import SwiftSyntax

class ValueRecorder: SyntaxRewriter {
    var code = ""

    private let target: ExpressionStmtSyntax
    private let testable: Bool

    private var expressions = [ExprSyntax]()
    private var functionCallList = [[TokenSyntax]]()
    private var subscriptingList = [[TokenSyntax]]()

    private var tokens = [TokenSyntax]()
    private var functionCalls = [[TokenSyntax]]()
    private var subscriptings = [[TokenSyntax]]()
    private var binaryOperators = [ExprSyntax]()
    private var binaryOperatorExpressions = [Syntax]()

    init(_ target: ExpressionStmtSyntax, testable: Bool = false) {
        func removeNewline(expression: Syntax) -> Syntax {
            class TokenVisitor: SyntaxRewriter {
                func hasLeadingNewline(_ token: TokenSyntax) -> Bool {
                    for piece in token.leadingTrivia { if case .newlines(_) = piece { return true } }
                    return false
                }

                override func visit(_ token: TokenSyntax) -> Syntax {
                    switch token.tokenKind {
                    case .spacedBinaryOperator(_) where hasLeadingNewline(token): return token.withLeadingTrivia(.spaces(1))
                    default: return token.withLeadingTrivia(.spaces(0))
                    }
                }
            }
            return TokenVisitor().visit(expression)
        }
        self.target = removeNewline(expression: target) as! ExpressionStmtSyntax
        self.testable = testable
    }

    func recordValues() -> String {
        _ = visit(target)
        return code
    }

    override func visit(_ node: FunctionCallArgumentSyntax) -> Syntax {
        _ = TokenVisitor(self).visit(node)
        parseFunctionCall(tokens)
        parseSubscripting(tokens)

        _ = TupleExpressionVisitor(self).visit(node)
        _ = TupleElementVisitor(self).visit(node)
        _ = IdentifierExpressionVisitor(self).visit(node)
        _ = MemberAccessExpressionVisitor(self).visit(node)
        _ = LiteralExpressionVisitor(self).visit(node)
        _ = BinaryOperatorExpressionVisitor(self).visit(node)

        let assersionStatement = node.description.replacingOccurrences(of: "\"", with: "\\\"")
        let offset = "assert(".count
        code =
        """

        do {
            func toString<T>(_ value: T?) -> String {
                switch value {
                case .some(let v): return \"\\(v)\"
                case .none: return \"nil\"
                }
            }
            var valueColumns = [Int: String]()
            let condition = { () -> Bool in
                \({ () -> String in
                    var recodValues = ""
                    for expression in expressions {
                        let column = caluclateColumn(expression.children.flatMap { $0 as? TokenSyntax }.last!, in: node)
                        if let column = column {
                            recodValues += "valueColumns[\(offset + column)] = \"\\(toString(\(expression)))\"\n"
                        }
                    }
                    for expression in functionCallList {
                        let column = caluclateColumn(expression[expression.map {$0.text}.index(of: "(")! - 1], in: node)
                        if let column = column {
                            recodValues += "valueColumns[\(offset + column)] = \"\\(toString(\(expression.map { $0.description }.joined())))\"\n"
                        }
                    }
                    for expression in subscriptingList {
                        let column = caluclateColumn(expression[expression.map {$0.text}.index(of: "[")! - 1], in: node)
                        if let column = column {
                            recodValues += "valueColumns[\(offset + column)] = \"\\(toString(\(expression.map { $0.description }.joined())))\"\n"
                        }
                    }
                    for (index, binaryOperator) in binaryOperators.enumerated() {
                        let binaryOperatorExpression = binaryOperatorExpressions[index]
                        let column = caluclateColumn(binaryOperator.children.flatMap { $0 as? TokenSyntax }[0], in: node)
                        if let column = column {
                            recodValues += "valueColumns[\(offset + column)] = \"\\(toString(\(binaryOperatorExpression)))\"\n"
                        }
                    }
                    return recodValues
                }())
                return \(node)
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
                print(\"assert(\(assersionStatement))\")
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
                        if index == values.count - 1 ||
                            values[index].0 + values[index].1.count < values[index + 1].0 {
                            align(current: &current, column: values[index].0, string: values[index].1)
                            values.remove(at: index)
                        } else {
                            align(current: &current, column: values[index].0, string: \"|\")
                            index += 1
                        }
                    }
                    print()
                }
                \({ () -> String in
                    if !testable {
                        return "XCTFail(\"'\" + \"assertion failed: \" + \"\(assersionStatement)\" + \"'\")"
                    }
                    return ""
                }())
            }
        }
        """

        return node
    }

    private func parseFunctionCall(_ tokens: [TokenSyntax]) {
        var functionCallExpression = [TokenSyntax]()
        var parens = [TokenSyntax]()
        var index = 0
        while index < tokens.count {
            let token = tokens[index]

            switch token.tokenKind {
            case .identifier(_):
                if let nextToken = index < tokens.count - 1 ? tokens[index + 1] : nil, case .leftParen = nextToken.tokenKind {
                    if parens.isEmpty {
                        functionCallExpression.append(token)
                        functionCallExpression.append(nextToken)
                        parens.append(nextToken)
                        index += 2
                        continue
                    }
                }
            case .leftParen:
                parens.append(token)
            case .rightParen:
                parens.removeLast()
                if parens.isEmpty && !functionCallExpression.isEmpty {
                    functionCallExpression.append(token)
                    functionCalls.append(functionCallExpression)
                    parseFunctionCall(Array(functionCallExpression.dropFirst().dropFirst().dropLast()))

                    functionCallExpression.removeAll()
                }
            default:
                break
            }
            if !functionCallExpression.isEmpty {
                functionCallExpression.append(token)
            }
            index += 1
        }
    }

    private func parseSubscripting(_ tokens: [TokenSyntax]) {
        var subscriptingExpression = [TokenSyntax]()
        var squareBrackets = [TokenSyntax]()
        var index = 0
        while index < tokens.count {
            let token = tokens[index]

            switch token.tokenKind {
            case .identifier(_):
                if let nextToken = index < tokens.count - 1 ? tokens[index + 1] : nil, case .leftSquareBracket = nextToken.tokenKind {
                    if squareBrackets.isEmpty {
                        subscriptingExpression.append(token)
                        subscriptingExpression.append(nextToken)
                        squareBrackets.append(nextToken)
                        index += 2
                        continue
                    }
                }
            case .leftSquareBracket:
                squareBrackets.append(token)
            case .rightSquareBracket:
                squareBrackets.removeLast()
                if squareBrackets.isEmpty && !subscriptingExpression.isEmpty {
                    subscriptingExpression.append(token)
                    subscriptings.append(subscriptingExpression)
                    parseFunctionCall(Array(subscriptingExpression.dropFirst().dropFirst().dropLast()))

                    subscriptingExpression.removeAll()
                }
            default:
                break
            }
            if !subscriptingExpression.isEmpty {
                subscriptingExpression.append(token)
            }
            index += 1
        }
    }

    private func caluclateColumn(_ target: TokenSyntax, in node: Syntax) -> Int? {
        class TokenVisitor: SyntaxRewriter {
            var column: Int?
            var count = 0
            let target: TokenSyntax

            init(_ target: TokenSyntax) {
                self.target = target
            }

            override func visit(_ token: TokenSyntax) -> Syntax {
                if token == target {
                    column = count
                } else {
                    count += token.description.count
                }
                return token
            }
        }

        let tokenVisitor = TokenVisitor(target)
        _ = tokenVisitor.visit(node)
        return tokenVisitor.column
    }

    private class TokenVisitor: SyntaxRewriter {
        private let recorder: ValueRecorder

        init(_ recorder: ValueRecorder) {
            self.recorder = recorder
        }

        override func visit(_ token: TokenSyntax) -> Syntax {
            recorder.tokens.append(token)
            return token
        }
    }

    private class IdentifierExpressionVisitor: SyntaxRewriter {
        private let recorder: ValueRecorder

        init(_ recorder: ValueRecorder) {
            self.recorder = recorder
        }

        override func visit(_ node: IdentifierExprSyntax) -> ExprSyntax {
            recorder.expressions.append(node)
            return node
        }
    }

    private class MemberAccessExpressionVisitor: SyntaxRewriter {
        private let recorder: ValueRecorder

        init(_ recorder: ValueRecorder) {
            self.recorder = recorder
        }

        override func visit(_ node: MemberAccessExprSyntax) -> ExprSyntax {
            let expression = Array(node.children)
            if !expression.isEmpty, let token = expression.last as? TokenSyntax {
                for functionCall in recorder.functionCalls where functionCall.first == token {
                    let base = node.base.children.flatMap { $0 as? IdentifierExprSyntax }
                    let expr = (base.isEmpty ? [] : base[0].children.flatMap { $0 as? TokenSyntax }) + node.base.children.flatMap { $0 as? TokenSyntax } + [SyntaxFactory.makeToken(.period, presence: .present)] + functionCall
                    recorder.functionCallList.append(expr)
                    if let expression = expression[0] as? MemberAccessExprSyntax {
                        return visit(expression)
                    }
                    return node
                }
                for subscripting in recorder.subscriptings where subscripting.first == token {
                    let base = node.base.children.flatMap { $0 as? IdentifierExprSyntax }
                    let expr = (base.isEmpty ? [] : base[0].children.flatMap { $0 as? TokenSyntax }) + node.base.children.flatMap { $0 as? TokenSyntax } + [SyntaxFactory.makeToken(.period, presence: .present)] + subscripting
                    recorder.subscriptingList.append(expr)
                    if let expression = expression[0] as? MemberAccessExprSyntax {
                        return visit(expression)
                    }
                    return node
                }
            }
            if !expression.isEmpty, let expression = expression[0] as? MemberAccessExprSyntax {
                recorder.expressions.append(node)
                return visit(expression)
            }
            recorder.expressions.append(node)
            return node
        }
    }

    private class TupleExpressionVisitor: SyntaxRewriter {
        private let recorder: ValueRecorder

        init(_ recorder: ValueRecorder) {
            self.recorder = recorder
        }

        override func visit(_ node: TupleExprSyntax) -> ExprSyntax {
            recorder.expressions.append(node)
            return node
        }
    }

    private class TupleElementVisitor: SyntaxRewriter {
        private let recorder: ValueRecorder

        init(_ recorder: ValueRecorder) {
            self.recorder = recorder
        }

        override func visit(_ node: TupleElementSyntax) -> Syntax {
            _ = MemberAccessExpressionVisitor(recorder).visit(node)
            _ = IdentifierExpressionVisitor(recorder).visit(node)
            return node
        }
    }

    private class LiteralExpressionVisitor: SyntaxRewriter {
        private let recorder: ValueRecorder

        init(_ recorder: ValueRecorder) {
            self.recorder = recorder
        }

        override func visit(_ node: StringLiteralExprSyntax) -> ExprSyntax {
            recorder.expressions.append(node)
            return node
        }

        override func visit(_ node: IntegerLiteralExprSyntax) -> ExprSyntax {
            recorder.expressions.append(node)
            return node
        }

        override func visit(_ node: FloatLiteralExprSyntax) -> ExprSyntax {
            recorder.expressions.append(node)
            return node
        }

        override func visit(_ node: BooleanLiteralExprSyntax) -> ExprSyntax {
            recorder.expressions.append(node)
            return node
        }

        override func visit(_ node: NilLiteralExprSyntax) -> ExprSyntax {
            recorder.expressions.append(node)
            return node
        }
    }

    private class BinaryOperatorExpressionVisitor: SyntaxRewriter {
        private let recorder: ValueRecorder

        init(_ recorder: ValueRecorder) {
            self.recorder = recorder
        }

        override func visit(_ node: BinaryOperatorExprSyntax) -> ExprSyntax {
            if let parent = node.parent {
                recorder.binaryOperators.append(node)
                recorder.binaryOperatorExpressions.append(parent)
            }
            return node
        }
    }
}
