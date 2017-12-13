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

    var injectionCode: String?

    init(testable: Bool = false) {
        self.testable = testable
    }

    func instrument(sourceFile: SourceFileSyntax) throws -> Syntax {
        var source: Syntax = sourceFile
        let targets = collectInstrumentTargets(sourceFile: sourceFile)
        for target in targets {
            let recorder = ValueRecorder(target, testable: testable)
            let code = recorder.recordValues()
            let replacement = try parseInjectionCode(code)
            source = replaceAssertCall(target: target, replacement: replacement, source: source)
        }
        return source
    }

    private func parseInjectionCode(_ code: String) throws -> StmtSyntax {
        class UnknownStatementVisitor: SyntaxRewriter {
            var statement: StmtSyntax!

            override func visit(_ node: UnknownStmtSyntax) -> StmtSyntax {
                statement = node
                return node
            }
        }

        let tempDir = NSTemporaryDirectory() as NSString
        let tempFileUrl = URL(fileURLWithPath: tempDir.appendingPathComponent("swift-power-assert-\(UUID().uuidString).swift"))
        try code.write(to: tempFileUrl, atomically: true, encoding: .utf8)
        let sourceFile = try Syntax.parse(tempFileUrl)
        let statementVisitor = UnknownStatementVisitor()
        _ = statementVisitor.visit(sourceFile)
        return statementVisitor.statement
    }

    private func replaceAssertCall(target: StmtSyntax, replacement: StmtSyntax, source: Syntax) -> Syntax {
        class ExpressionStatementVisitor: SyntaxRewriter {
            let target: StmtSyntax
            let replacement: StmtSyntax

            init(_ target: StmtSyntax, _ replacement: StmtSyntax) {
                self.target = target
                self.replacement = replacement
            }

            override func visit(_ node: ExpressionStmtSyntax) -> StmtSyntax {
                if node.description == target.description {
                    return replacement
                }
                return node
            }
        }
        return ExpressionStatementVisitor(target, replacement).visit(source)
    }

    private func collectInstrumentTargets(sourceFile: SourceFileSyntax) -> [ExpressionStmtSyntax] {
        var targets = [ExpressionStmtSyntax]()
        let declarations = collectDeclarations(sourceFile)
        for declaration in declarations {
            let testCases = collectTestCases(declaration)
            for testCase in testCases {
                let testFunctions = collectTestFunctions(testCase)
                for testFunction in testFunctions {
                    let assertCalls = collectAssertCalls(testFunction)
                    targets.append(contentsOf: assertCalls)
                }
            }
        }
        return targets
    }

    private func collectDeclarations(_ sourceFile: SourceFileSyntax) -> [DeclarationStmtSyntax] {
        let declarationStatementVisitor = DeclarationStatementVisitor()
        _ = declarationStatementVisitor.visit(sourceFile)
        return declarationStatementVisitor.declarations
    }

    private func collectTestCases(_ node: DeclarationStmtSyntax) -> [DeclarationStmtSyntax] {
        let typeInheritanceClauseVisitor = TypeInheritanceClauseVisitor(node)
        _ = typeInheritanceClauseVisitor.visit(node)
        return typeInheritanceClauseVisitor.testCases
    }

    private func collectTestFunctions(_ node: DeclarationStmtSyntax) -> [DeclListSyntax] {
        let tokenVisitor = TokenVisitor()
        _ = tokenVisitor.visit(node)
        return tokenVisitor.testFunctions
    }

    private func collectAssertCalls(_ node: DeclListSyntax) -> [ExpressionStmtSyntax] {
        let expressionStatementVisitor = ExpressionStatementVisitor()
        _ = expressionStatementVisitor.visit(node)
        return expressionStatementVisitor.assertCalls
    }

    private class DeclarationStatementVisitor: SyntaxRewriter {
        var declarations = [DeclarationStmtSyntax]()

        override func visit(_ node: DeclarationStmtSyntax) -> StmtSyntax {
            declarations.append(node)
            return node
        }
    }

    private class TypeInheritanceClauseVisitor: SyntaxRewriter {
        var declaration: DeclarationStmtSyntax
        var testCases = [DeclarationStmtSyntax]()

        init(_ declaration: DeclarationStmtSyntax) {
            self.declaration = declaration
        }

        override func visit(_ node: TypeInheritanceClauseSyntax) -> Syntax {
            for inheritedType in node.inheritedTypeCollection where !(inheritedType.typeName.children.flatMap { $0 as? TokenSyntax }.filter { $0.text == "XCTestCase" }.isEmpty) {
                testCases.append(declaration)
                return node
            }
            return node
        }
    }

    private class TokenVisitor: SyntaxRewriter {
        var testFunctions = [DeclListSyntax]()

        override func visit(_ token: TokenSyntax) -> Syntax {
            if case .funcKeyword = token.tokenKind, let sibling = token.parent?.child(at: token.indexInParent + 1) as? TokenSyntax,
                case .identifier = sibling.tokenKind, sibling.text.hasPrefix("test"), let testFunction = token.parent?.parent as? DeclListSyntax {
                testFunctions.append(testFunction)
            }
            return token
        }
    }

    private class ExpressionStatementVisitor: SyntaxRewriter {
        var assertCalls = [ExpressionStmtSyntax]()

        override func visit(_ node: ExpressionStmtSyntax) -> StmtSyntax {
            let identifierExpressionVisitor = IdentifierExpressionVisitor()
            _ = identifierExpressionVisitor.visit(node)

            assertCalls.append(contentsOf: identifierExpressionVisitor.assertCalls)
            return node
        }

        class IdentifierExpressionVisitor: SyntaxRewriter {
            var assertCalls = [ExpressionStmtSyntax]()

            override func visit(_ node: IdentifierExprSyntax) -> ExprSyntax {
                if node.identifier.text == "assert", let sibling = node.parent?.child(at: node.indexInParent + 1) as? TokenSyntax,
                    case sibling.tokenKind = TokenKind.leftParen, let parent = node.parent?.parent as? ExpressionStmtSyntax {
                    assertCalls.append(parent)
                }
                return node
            }
        }
    }
}
