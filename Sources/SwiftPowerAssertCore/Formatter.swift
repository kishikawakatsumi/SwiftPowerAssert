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

class Formatter {
    private var tokens = [TokenSyntax]()

    func format(expression: Syntax) -> Syntax {
        class TokenVisitor: SyntaxRewriter {
            let formatter: Formatter
            var counter = -1

            init(_ formatter: Formatter) {
                self.formatter = formatter
            }

            override func visit(_ token: TokenSyntax) -> Syntax {
                counter += 1
                return formatter.tokens[counter]
            }
        }

        collectTokens(expression)
        removeNewlines()
        return TokenVisitor(self).visit(expression)
    }

    private func collectTokens(_ expression: Syntax) {
        class TokenVisitor: SyntaxRewriter {
            let formatter: Formatter

            init(_ formatter: Formatter) {
                self.formatter = formatter
            }

            override func visit(_ token: TokenSyntax) -> Syntax {
                formatter.tokens.append(token)
                return token
            }
        }

        _ = TokenVisitor(self).visit(expression)
    }

    func removeNewlines() {
        func hasLeadingNewline(_ token: TokenSyntax) -> Bool {
            for piece in token.leadingTrivia {
                if case .newlines(_) = piece { return true }
            }
            return false
        }

        var tokensRemovedNewline = [TokenSyntax]()
        var formatterdTokens = tokens.map { (token) -> TokenSyntax in
            if hasLeadingNewline(token) {
                tokensRemovedNewline.append(token)
                return token.withLeadingTrivia(.zero)
            }
            return token
        }
        for i in 0..<tokens.count {
            let token = tokens[i]
            if tokensRemovedNewline.contains(token) {
                if case .spacedBinaryOperator(_) = token.tokenKind {
                    let previousToken = formatterdTokens[i - 1]
                    formatterdTokens[i - 1] = previousToken.withTrailingTrivia(.spaces(1))
                }
            }
        }

        tokens = formatterdTokens
    }
}
