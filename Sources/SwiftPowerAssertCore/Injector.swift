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

class Injector: SyntaxRewriter {
    private var instruments: [SourceFileSyntax]

    private var isInTestFunc = false
    private var braces = [String]()

    private var currentExpression: Expression?
    private var brackets = [String]()

    init(instruments: [SourceFileSyntax]) {
        self.instruments = instruments
    }

    override func visit(_ token: TokenSyntax) -> Syntax {
        switch token.tokenKind {
        case .funcKeyword:
            if let sibling = token.parent?.child(at: token.indexInParent + 1) as? TokenSyntax,
                case .identifier(let identifier) = sibling.tokenKind, identifier.hasPrefix("test") {
                isInTestFunc = true
            }
        case let .identifier(identifier) where identifier == "assert" && isInTestFunc:
            currentExpression = Expression()
            return instruments.removeFirst()
        default:
            if isInTestFunc {
                switch token.tokenKind {
                case .leftBrace:
                    braces.append(token.text)
                case .rightBrace:
                    braces.removeLast()
                    if braces.isEmpty {
                        isInTestFunc = false
                    }
                default:
                    break
                }
            }
            if let _ = currentExpression {
                switch token.tokenKind {
                case .leftParen:
                    brackets.append(token.text)
                case .rightParen:
                    brackets.removeLast()
                    if brackets.isEmpty {
                        currentExpression = nil
                    }
                default:
                    break
                }
                return SyntaxFactory.makeIdentifier("")
            }
            return token
        }
        return token
    }
}
