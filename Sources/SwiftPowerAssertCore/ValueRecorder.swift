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

final class ValueRecorder {
    private let tokens: [TokenSyntax]
    private var currentColumn = "assert(".count

    private var os = ""

    init(tokens: [TokenSyntax]) {
        self.tokens = tokens
    }

    func parse() -> String {
        parseKeyPaths(expression: tokens)
        parseLiterals(expression: tokens)
        parseFunctions(expression: tokens)

        return os
    }

    private func takeExpression(in expression: [TokenSyntax], from: Int) -> [TokenSyntax] {
        var parens = [TokenSyntax]()
        var brackets = [TokenSyntax]()
        var angles = [TokenSyntax]()
        var braces = [TokenSyntax]()

        var index = from
        var subExpression = skipToIdentifier(in: expression, from: &index)

        for token in subExpression {
            switch token.tokenKind {
            case .leftParen:
                parens.append(token)
            case .rightParen:
                parens.removeLast()
            case .leftSquareBracket:
                brackets.append(token)
            case .rightSquareBracket:
                brackets.removeLast()
            case .leftAngle:
                angles.append(token)
            case .rightAngle:
                angles.removeLast()
            case .leftBrace:
                braces.append(token)
            case .rightBrace:
                braces.removeLast()
            default:
                break
            }
        }

        while index < expression.count {
            let token = expression[index]
            defer {
                subExpression.append(token)
                index += 1
            }

            switch token.tokenKind {
            case .spacedBinaryOperator(_):
                if parens.isEmpty && brackets.isEmpty && angles.isEmpty && braces.isEmpty {
                    return subExpression
                }
            case .leftParen:
                parens.append(token)
            case .rightParen:
                parens.removeLast()
            case .leftSquareBracket:
                brackets.append(token)
            case .rightSquareBracket:
                brackets.removeLast()
            case .leftAngle:
                angles.append(token)
            case .rightAngle:
                angles.removeLast()
            case .leftBrace:
                braces.append(token)
            case .rightBrace:
                braces.removeLast()
            default:
                break
            }
        }

        return subExpression
    }

    private func parseKeyPaths(expression: [TokenSyntax]) {
        let column = currentColumn
        defer {
            currentColumn = column
        }

        var index = 0
        while index < expression.count {
            let subExpression = takeExpression(in: expression, from: index)
            parseKeyPath(in: subExpression)
            index += subExpression.count
        }
    }

    private func parseKeyPath(in expression: [TokenSyntax]) {
        var subExpression = [TokenSyntax]()
        var index = 0
        var column = currentColumn

        defer {
            currentColumn = column
        }

        while index < expression.count {
            let token = expression[index]
            defer {
                index += 1
                column += "\(token)".count
            }

            switch token.tokenKind {
            case .stringLiteral(_), .integerLiteral(_), .floatingLiteral(_), .trueKeyword, .falseKeyword:
                if let nextToken = index < expression.count - 1 ? expression[index + 1] : nil {
                    switch nextToken.tokenKind {
                    case .period:
                        break
                    default:
                        continue
                    }
                } else {
                    continue
                }
            case .spacedBinaryOperator(_):
                continue
            default:
                break
            }

            subExpression.append(token)
            let value = subExpression.map { "\($0)" }.joined()

            switch token.tokenKind {
            case .identifier(_):
                if let nextToken = index < expression.count - 1 ? expression[index + 1] : nil {
                    switch nextToken.tokenKind {
                    case .period:
                        record(value: value, column: column)
                    case .leftSquareBracket:
                        record(value: value, column: column)

                        let subscriptingExpression = takeSubscriptingExpression(in: expression, from: index + 1)
                        currentColumn = column + "\(token)".count + "\(nextToken)".count
                        parseSubscripting(in: subscriptingExpression)
                    default:
                        break
                    }
                } else {
                    record(value: value, column: column)
                }
            default:
                break
            }
        }
    }

    private func parseLiterals(expression: [TokenSyntax]) {
        let column = currentColumn
        defer {
            currentColumn = column
        }

        var index = 0
        while index < expression.count {
            let subExpression = takeExpression(in: expression, from: index)
            parseLiteral(in: subExpression)
            index += subExpression.count
        }
    }

    private func parseLiteral(in expression: [TokenSyntax]) {
        var subExpression = [TokenSyntax]()
        var index = 0
        var column = currentColumn

        defer {
            currentColumn = column
        }

        while index < expression.count {
            let token = expression[index]
            defer {
                index += 1
                column += "\(token)".count
            }
            if case .spacedBinaryOperator(_) = token.tokenKind {
                continue
            }

            subExpression.append(token)
            let value = subExpression.map { "\($0)" }.joined()

            switch token.tokenKind {
            case .stringLiteral(_), .integerLiteral(_), .floatingLiteral(_), .trueKeyword, .falseKeyword:
                if let nextToken = index < expression.count - 1 ? expression[index + 1] : nil {
                    switch nextToken.tokenKind {
                    case .period:
                        record(value: value, column: column)
                    default:
                        break
                    }
                } else {
                    record(value: value, column: column)
                }
            default:
                break
            }
        }
    }

    private func parseFunctions(expression: [TokenSyntax]) {
        let column = currentColumn
        defer {
            currentColumn = column
        }

        var index = 0
        while index < expression.count {
            let subExpression = takeExpression(in: expression, from: index)
            parseFunction(in: subExpression)
            index += subExpression.count
        }
    }

    private func parseFunction(in expression: [TokenSyntax]) {
        var subExpression = [TokenSyntax]()
        var index = 0
        var column = currentColumn

        var parens = [TokenSyntax]()
        var foundFunction = false
        var functionStartColumn = column

        var functionExpression = [TokenSyntax]()

        defer {
            currentColumn = column
        }

        while index < expression.count {
            let token = expression[index]
            defer {
                index += 1
                column += "\(token)".count
            }

            if !foundFunction {
                switch token.tokenKind {
                case .stringLiteral(_), .integerLiteral(_), .floatingLiteral(_):
                    continue
                case .trueKeyword, .falseKeyword:
                    continue
                case .spacedBinaryOperator(_):
                    continue
                default:
                    break
                }
            }

            subExpression.append(token)
            if foundFunction {
                functionExpression.append(token)
            }
            let value = subExpression.map { "\($0)" }.joined()

            switch token.tokenKind {
            case .identifier(_):
                if let nextToken = index < expression.count - 1 ? expression[index + 1] : nil {
                    switch nextToken.tokenKind {
                    case .leftParen:
                        if parens.isEmpty {
                            foundFunction = true
                            functionStartColumn = column

                            functionExpression.append(token)
                        }
                    default:
                        break
                    }
                }
            case .leftParen:
                parens.append(token)
            case .rightParen:
                parens.removeLast()
                if parens.isEmpty && foundFunction {
                    record(value: value, column: functionStartColumn)

                    currentColumn = column - functionExpression.dropLast().map { "\($0)" }.joined().count
                    parseFunctionArguments(in: functionExpression)
                    functionExpression.removeAll()
                }
            default:
                break
            }
        }
    }

    private func parseFunctionArguments(in expression: [TokenSyntax]) {
        var column = currentColumn
        defer {
            currentColumn = column
        }

        var subExpression = [TokenSyntax]()

        var index = 0
        while index < expression.count {
            let token = expression[index]
            defer {
                index += 1
            }

            switch token.tokenKind {
            case .identifier(_):
                column += "\(token)".count

                if let nextToken = index < expression.count - 1 ? expression[index + 1] : nil {
                    switch nextToken.tokenKind {
                    case .leftParen:
                        index += 2
                        column += "\(nextToken)".count

                        while index < expression.count {
                            defer {
                                index += 1
                            }

                            let token = expression[index]

                            switch token.tokenKind {
                            case .identifier(_), .stringLiteral(_), .integerLiteral(_), .floatingLiteral(_), .trueKeyword, .falseKeyword:
                                if let nextToken = index < expression.count - 1 ? expression[index + 1] : nil {
                                    switch nextToken.tokenKind {
                                    case .colon:
                                        column += "\(token)".count
                                        continue
                                    case .comma, .rightParen:
                                        subExpression.append(token)
                                        currentColumn = column
                                        parseFunctionArgument(in: subExpression)
                                        column += "\(token)".count
                                        subExpression.removeAll()
                                    default:
                                        subExpression.append(token)
                                        column += "\(token)".count
                                    }
                                }
                            default:
                                column += "\(token)".count
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

    private func parseFunctionArgument(in expression: [TokenSyntax]) {
        parseKeyPaths(expression: expression)
        parseLiterals(expression: expression)
        parseFunctions(expression: expression)
    }

    private func takeSubscriptingExpression(in expression: [TokenSyntax], from: Int) -> [TokenSyntax] {
        var subExpression = [TokenSyntax]()
        var brackets = [TokenSyntax]()
        var index = from
        while index < expression.count {
            defer {
                index += 1
            }
            let token = expression[index]
            switch token.tokenKind {
            case .leftSquareBracket:
                brackets.append(token)
            case .rightSquareBracket:
                brackets.removeLast()
                if brackets.isEmpty {
                    return subExpression
                }
            default:
                subExpression.append(token)
            }
        }
        return subExpression
    }

    private func parseSubscripting(in expression: [TokenSyntax]) {
        parseKeyPaths(expression: expression)
        parseLiterals(expression: expression)
        parseFunctions(expression: expression)
    }

    private func skipToIdentifier(in expression: [TokenSyntax], from index: inout Int) -> [TokenSyntax] {
        var subExpression = [TokenSyntax]()
        while index < expression.count {
            let token = expression[index]

            switch token.tokenKind {
            case .identifier(_):
                subExpression.append(token)
                index += 1
                return subExpression
            default:
                subExpression.append(token)
            }
            index += 1
        }
        return subExpression
    }

    private func record(value: String, column: Int) {
        print("values.append((\(column), \"\\(toString(\(value)))\"))", to: &os)
    }
}
