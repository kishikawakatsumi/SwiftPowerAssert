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

class Instrumentor: SyntaxRewriter {
    let testable: Bool
    
    var target: StmtSyntax?
    var injectionCode: String?

    init(testable: Bool = false) {
        self.testable = testable
    }

    func instrument(sourceFile: SourceFileSyntax) throws -> Syntax {
        let declarationStatementVisitor = DeclarationStatementVisitor(self)
        _ = declarationStatementVisitor.visit(sourceFile)

        if let injectionCode = injectionCode {
            let tempDir = NSTemporaryDirectory() as NSString
            let tempFileUrl = URL(fileURLWithPath: tempDir.appendingPathComponent("swift-power-assert-\(UUID().uuidString).swift"))

            try injectionCode.write(to: tempFileUrl, atomically: true, encoding: .utf8)
            let translator = UnknownStatementVisitor()
            _ = translator.visit(try Syntax.parse(tempFileUrl))

            if let target = target, let replacement = translator.statement {
                return FunctionCallVisitor(target: target, replacement: replacement).visit(sourceFile)
            }
        }
        return sourceFile
    }

    class UnknownStatementVisitor: SyntaxRewriter {
        var statement: StmtSyntax!

        override func visit(_ node: UnknownStmtSyntax) -> StmtSyntax {
            statement = node
            return node
        }
    }

    class FunctionCallVisitor: SyntaxRewriter {
        let target: StmtSyntax
        let replacement: StmtSyntax

        init(target: StmtSyntax, replacement: StmtSyntax) {
            self.target = target
            self.replacement = replacement
        }

        override func visit(_ node: ExpressionStmtSyntax) -> StmtSyntax {
            if node == target {
                return replacement
            }
            return node
        }
    }
}

class DeclarationStatementVisitor: SyntaxRewriter {
    let instrumentor: Instrumentor

    init(_ instrumentor: Instrumentor) {
        self.instrumentor = instrumentor
    }

    override func visit(_ node: DeclarationStmtSyntax) -> StmtSyntax {
        let typeInheritanceClauseVisitor = TypeInheritanceClauseVisitor(instrumentor, node)
        _ = typeInheritanceClauseVisitor.visit(node)
        for testCaseNode in typeInheritanceClauseVisitor.testCaseNodes {
            let functionDeclarationVisitor = FunctionDeclarationVisitor()
            _ = functionDeclarationVisitor.visit(testCaseNode)
            for testMethodNode in functionDeclarationVisitor.testMethodNodes {
                let functionCallVisitor = FunctionCallVisitor(instrumentor)
                _ = functionCallVisitor.visit(testMethodNode)
            }
        }
        return node
    }
}

class TypeInheritanceClauseVisitor: SyntaxRewriter {
    let instrumentor: Instrumentor

    var currentDeclarationNode: DeclarationStmtSyntax
    var testCaseNodes = [DeclarationStmtSyntax]()

    init(_ instrumentor: Instrumentor, _ currentDeclarationNode: DeclarationStmtSyntax) {
        self.instrumentor = instrumentor
        self.currentDeclarationNode = currentDeclarationNode
    }
    
    override func visit(_ node: TypeInheritanceClauseSyntax) -> Syntax {
        for inheritedType in node.inheritedTypeCollection where !(inheritedType.typeName.children.flatMap { $0 as? TokenSyntax }.filter { $0.text == "XCTestCase" }.isEmpty) {
            testCaseNodes.append(currentDeclarationNode)
            return node
        }
        return node
    }
}

class FunctionDeclarationVisitor: SyntaxRewriter {
    var testMethodNodes = [DeclListSyntax]()

    override func visit(_ token: TokenSyntax) -> Syntax {
        if case .funcKeyword = token.tokenKind,
            let sibling = token.parent?.child(at: token.indexInParent + 1) as? TokenSyntax,
            case .identifier = sibling.tokenKind,
            sibling.text.hasPrefix("test"),
            let testMethodNode = token.parent?.parent as? DeclListSyntax {
            testMethodNodes.append(testMethodNode)
        }
        return token
    }
}

class FunctionCallVisitor: SyntaxRewriter {
    let instrumentor: Instrumentor

    init(_ instrumentor: Instrumentor) {
        self.instrumentor = instrumentor
    }

    override func visit(_ node: ExpressionStmtSyntax) -> StmtSyntax {
        let identifierExpressionVisitor = IdentifierExpressionVisitor()
        _ = identifierExpressionVisitor.visit(node)
        if identifierExpressionVisitor.foundAssert {
            let transformer = ExpressionTransformer(node, trivia: identifierExpressionVisitor.trivia, internalTest: instrumentor.testable)
            _ = transformer.visit(node)

            instrumentor.target = node
            instrumentor.injectionCode = transformer.injectionCode
        }
        return node
    }
}

class IdentifierExpressionVisitor: SyntaxRewriter {
    var visited = false
    var foundAssert = false
    var trivia: Trivia?

    override func visit(_ node: IdentifierExprSyntax) -> ExprSyntax {
        guard !visited else {
            visited = true
            return node
        }
        if node.identifier.text == "assert",
            let sibling = node.parent?.child(at: node.indexInParent + 1) as? TokenSyntax,
            case sibling.tokenKind = TokenKind.leftParen {
            foundAssert = true
            if let token = node.child(at: 0) as? TokenSyntax {
                trivia = token.trailingTrivia + sibling.trailingTrivia
            }
            return node
        }
        return node
    }
}

class ExpressionTransformer: SyntaxRewriter {
    var injectionCode = ""

    private let parentNode: ExpressionStmtSyntax
    private let trivia: Trivia?
    private let internalTest: Bool

    private var expressions = [ExprSyntax]()
    private var functionCallList = [[TokenSyntax]]()
    private var subscriptingList = [[TokenSyntax]]()

    private var tokens = [TokenSyntax]()
    private var functionCalls = [[TokenSyntax]]()
    private var subscriptings = [[TokenSyntax]]()
    private var binaryOperators = [ExprSyntax]()
    private var binaryOperatorExpressions = [Syntax]()

    init(_ parentNode: ExpressionStmtSyntax, trivia: Trivia? = nil, internalTest: Bool = false) {
        self.parentNode = parentNode
        self.trivia = trivia
        self.internalTest = internalTest
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

        var offset = "assert(".count
        if let trivia = trivia {
            for t in trivia {
                switch t {
                case .spaces(let spaces):
                    offset += spaces
                case .tabs(let tabs):
                    offset += tabs * 4
                case .blockComment(let blockComment):
                    offset += blockComment.count
                default:
                    break
                }
            }
        }

        injectionCode =
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
                        let determiner = TokenColumnFinder(expression.children.flatMap { $0 as? TokenSyntax }.last!)
                        _ = determiner.visit(node)
                        if let column = determiner.column {
                            recodValues += "valueColumns[\(offset + column)] = \"\\(toString(\(expression)))\"\n"
                        }
                    }
                    for expression in functionCallList {
                        let determiner = TokenColumnFinder(expression[expression.map {$0.text}.index(of: "(")! - 1])
                        _ = determiner.visit(node)
                        if let column = determiner.column {
                            recodValues += "valueColumns[\(offset + column)] = \"\\(toString(\(expression.map { $0.description }.joined())))\"\n"
                        }
                    }
                    for expression in subscriptingList {
                        let determiner = TokenColumnFinder(expression[expression.map {$0.text}.index(of: "[")! - 1])
                        _ = determiner.visit(node)
                        if let column = determiner.column {
                            recodValues += "valueColumns[\(offset + column)] = \"\\(toString(\(expression.map { $0.description }.joined())))\"\n"
                        }
                    }
                    for (index, binaryOperator) in binaryOperators.enumerated() {
                        let binaryOperatorExpression = binaryOperatorExpressions[index]
                        let determiner = TokenColumnFinder(binaryOperator.children.flatMap { $0 as? TokenSyntax }[0])
                        _ = determiner.visit(binaryOperatorExpression)
                        if let column = determiner.column {
                            recodValues += "valueColumns[\(offset + column)] = \"\\(toString(\(binaryOperatorExpression.description)))\"\n"
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
                    if !internalTest {
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

    class TokenVisitor: SyntaxRewriter {
        private let transformer: ExpressionTransformer

        init(_ transformer: ExpressionTransformer) {
            self.transformer = transformer
        }

        override func visit(_ token: TokenSyntax) -> Syntax {
            transformer.tokens.append(token)
            return token
        }
    }

    class IdentifierExpressionVisitor: SyntaxRewriter {
        private let transformer: ExpressionTransformer

        init(_ transformer: ExpressionTransformer) {
            self.transformer = transformer
        }

        override func visit(_ node: IdentifierExprSyntax) -> ExprSyntax {
            transformer.expressions.append(node)
            return node
        }
    }

    class MemberAccessExpressionVisitor: SyntaxRewriter {
        private let transformer: ExpressionTransformer

        init(_ transformer: ExpressionTransformer) {
            self.transformer = transformer
        }

        override func visit(_ node: MemberAccessExprSyntax) -> ExprSyntax {
            let expression = Array(node.children)
            if !expression.isEmpty, let token = expression.last as? TokenSyntax {
                for functionCall in transformer.functionCalls where functionCall.first == token {
                    let base = node.base.children.flatMap { $0 as? IdentifierExprSyntax }
                    let expr = (base.isEmpty ? [] : base[0].children.flatMap { $0 as? TokenSyntax }) + node.base.children.flatMap { $0 as? TokenSyntax } + [SyntaxFactory.makeToken(.period, presence: .present)] + functionCall
                    transformer.functionCallList.append(expr)
                    if let expression = expression[0] as? MemberAccessExprSyntax {
                        return visit(expression)
                    }
                    return node
                }
                for subscripting in transformer.subscriptings where subscripting.first == token {
                    let base = node.base.children.flatMap { $0 as? IdentifierExprSyntax }
                    let expr = (base.isEmpty ? [] : base[0].children.flatMap { $0 as? TokenSyntax }) + node.base.children.flatMap { $0 as? TokenSyntax } + [SyntaxFactory.makeToken(.period, presence: .present)] + subscripting
                    transformer.subscriptingList.append(expr)
                    if let expression = expression[0] as? MemberAccessExprSyntax {
                        return visit(expression)
                    }
                    return node
                }
            }
            if !expression.isEmpty, let expression = expression[0] as? MemberAccessExprSyntax {
                transformer.expressions.append(node)
                return visit(expression)
            }
            transformer.expressions.append(node)
            return node
        }
    }

    class TupleExpressionVisitor: SyntaxRewriter {
        private let transformer: ExpressionTransformer

        init(_ transformer: ExpressionTransformer) {
            self.transformer = transformer
        }

        override func visit(_ node: TupleExprSyntax) -> ExprSyntax {
            transformer.expressions.append(node)
            return node
        }
    }

    class TupleElementVisitor: SyntaxRewriter {
        private let transformer: ExpressionTransformer

        init(_ transformer: ExpressionTransformer) {
            self.transformer = transformer
        }

        override func visit(_ node: TupleElementSyntax) -> Syntax {
            _ = MemberAccessExpressionVisitor(transformer).visit(node)
            _ = IdentifierExpressionVisitor(transformer).visit(node)
            return node
        }
    }

    class LiteralExpressionVisitor: SyntaxRewriter {
        private let transformer: ExpressionTransformer

        init(_ transformer: ExpressionTransformer) {
            self.transformer = transformer
        }

        override func visit(_ node: StringLiteralExprSyntax) -> ExprSyntax {
            transformer.expressions.append(node)
            return node
        }

        override func visit(_ node: IntegerLiteralExprSyntax) -> ExprSyntax {
            transformer.expressions.append(node)
            return node
        }

        override func visit(_ node: FloatLiteralExprSyntax) -> ExprSyntax {
            transformer.expressions.append(node)
            return node
        }

        override func visit(_ node: BooleanLiteralExprSyntax) -> ExprSyntax {
            transformer.expressions.append(node)
            return node
        }

        override func visit(_ node: NilLiteralExprSyntax) -> ExprSyntax {
            transformer.expressions.append(node)
            return node
        }
    }

    class BinaryOperatorExpressionVisitor: SyntaxRewriter {
        private let transformer: ExpressionTransformer

        init(_ transformer: ExpressionTransformer) {
            self.transformer = transformer
        }

        override func visit(_ node: BinaryOperatorExprSyntax) -> ExprSyntax {
            if let parent = node.parent {
                transformer.binaryOperators.append(node)
                transformer.binaryOperatorExpressions.append(parent)
            }
            return node
        }
    }

    class TokenColumnFinder: SyntaxRewriter {
        var column: Int?
        private let targetToken: TokenSyntax
        private var columnCount = 0

        init(_ targetToken: TokenSyntax) {
            self.targetToken = targetToken
        }

        override func visit(_ token: TokenSyntax) -> Syntax {
            if token == targetToken {
                column = columnCount
            } else {
                columnCount += token.description.count
            }
            return token
        }
    }
}
