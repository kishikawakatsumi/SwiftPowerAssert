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

class Lexer {
    class State {
        let tokens: [Token]

        var current = Node<[Token]>([])
        let root = Node<[Token]>([])

        init(tokens: [Token]) {
            self.tokens = tokens
        }
    }

    func lex(tokens: [Token]) -> Node<[Token]> {
        let state = State(tokens: tokens)
        var stack = [(Int, Node<[Token]>)]()
        for token in state.tokens {
            switch token.type {
            case .token, .symbol, .string:
                if stack.isEmpty {
                    if state.root.value.isEmpty && state.root.children.count == 0 {
                        state.current = state.root
                    }
                }
                state.current.value.append(token)
            case .indent(let count):
                if let top = stack.last?.0 {
                    if count <= top {
                        while let top = stack.last?.0, count <= top {
                            state.current = stack.removeLast().1
                        }
                    }
                    stack.append((count, state.current))

                    let current = Node<[Token]>([])
                    state.current.append(current)
                    state.current = current
                } else {
                    stack.append((count, state.current))

                    let current = Node<[Token]>([])
                    state.root.append(current)
                    state.current = current
                }
            }
        }
        return state.root
    }
}

class Node<T> {
    var value: T
    var children = [Node]()
    weak var parent: Node?

    init(_ value: T) {
        self.value = value
    }

    func append(_ child: Node) {
        children.append(child)
        child.parent = self
    }
}

extension Node: CustomStringConvertible {
    var description: String {
        return recursiveDescription(self, level: 0)
    }

    private func recursiveDescription(_ node: Node, level: Int) -> String {
        var description = "\(String(repeating: "  ", count: level))\(node.value)\n"
        for child in node.children {
            description += recursiveDescription(child, level: level + 1)
        }
        return description
    }
}
