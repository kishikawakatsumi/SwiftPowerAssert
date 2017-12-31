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

class Parser {
    class State {
        let root: Node<[Token]>

        init(root: Node<[Token]>) {
            self.root = root
        }
    }

    func parse(root: Node<[Token]>) -> AST {
        let state = State(root: root)
        return parseSourceFileNode(node: state.root)
    }

    private func parseSourceFileNode(node sourceFileNode: Node<[Token]>) -> AST {
        var declarations = [Declaration]()
        for node in sourceFileNode.children {
            for token in node.value {
                switch (token.type, token.value) {
                case (.token, "class_decl"):
                    declarations.append(.class(parseClassDeclarationNode(node: node)))
                default:
                    break
                }
            }
        }
        return AST(declarations: declarations)
    }

    private func parseClassDeclarationNode(node: Node<[Token]>) -> ClassDeclaration {
        let tokens = node.value

        var name: String!
        for token in tokens {
            switch token.type {
            case .string:
                name = token.value
            default:
                break
            }
        }

        let accessLevel: AccessLevelModifier
        let attributes = parseKeyValueAttributes(tokens: tokens)
        if let access = attributes["access"] {
            accessLevel = AccessLevelModifier(rawValue: access)!
        } else {
            accessLevel = .internal
        }

        let typeInheritance = parseInherits(tokens: tokens)

        var members = [ClassMember]()
        for node in node.children {
            let tokens = node.value
            if isImplicit(tokens: tokens) {
                continue
            }
            for token in tokens {
                switch (token.type, token.value) {
                case (.token, "func_decl"):
                    members.append(.declaration(.function(parseFunctionDeclarationNode(node: node))))
                default:
                    break
                }
            }
        }

        return ClassDeclaration(accessLevel: accessLevel, name: name, typeInheritance: typeInheritance, members: members)
    }

    private func parseFunctionDeclarationNode(node: Node<[Token]>) -> FunctionDeclaration {
        let tokens = node.value

        var name: String!
        var modifiers = [DeclarationModifier]()

        for token in tokens {
            switch (token.type, token.value) {
            case (.string, _):
                name = token.value
            case (.token, "@objc"):
                modifiers.append(.objc)
            case (.token, "dynamic"):
                modifiers.append(.dynamic)
            default:
                break
            }
        }

        var parameters = [Parameter]()
        var result: FunctionResult? = nil
        var body = [Statement]()
        for node in node.children {
            for token in node.value {
                switch (token.type, token.value) {
                case (.token, "parameter_list"):
                    parameters.append(contentsOf: parseParameterListNode(node: node))
                case (.token, "result"):
                    result = parseResultNode(node: node)
                case (.token, "brace_stmt"):
                    body.append(.expression(parseExpressionNode(node: node)))
                default:
                    break
                }
            }
        }

        let throwBehavior: ThrowsModifier? = nil

        let accessLevel: AccessLevelModifier
        let attributes = parseKeyValueAttributes(tokens: tokens)
        if let access = attributes["access"] {
            accessLevel = AccessLevelModifier(rawValue: access)!
        } else {
            accessLevel = .internal
        }

        return FunctionDeclaration(accessLevel: accessLevel, modifiers: modifiers, name: name, parameters: parameters, throwBehavior: throwBehavior, result: result, body: body)
    }

    private func parseExpressionNode(node: Node<[Token]>) -> Expression {
        let tokens = node.value
        let attributes = parseKeyValueAttributes(tokens: tokens)

        let rawValue = tokens[1].value
        let type = attributes["type"]
        let rawLocation = attributes["location"]
        var location: SourceLocation?
        if let rawLocation = rawLocation {
            location = parseLocation(rawLocation)
        }
        let rawRange = attributes["range"]
        var sourceRange: SourceRange?
        var source: String?
        if let rawRange = rawRange {
            let (s, r) = parseRange(rawRange)
            sourceRange = r
            source = s
        }
        let decl = attributes["decl"]
        let value = attributes["value"]
        let argumentLabels = attributes["arg_labels"]
        var throwsModifier: String?
        for token in tokens {
            switch (token.type, token.value) {
            case (.token, "nothrow"):
                throwsModifier = "nothrow"
            case (.token, "throws"):
                throwsModifier = "throws"
            case (.token, "rethrows"):
                throwsModifier = "rethrows"
            default:
                break
            }
        }
        var expression = Expression(rawValue: rawValue, type: type, rawLocation: rawLocation, rawRange: rawRange,
                                    location: location, range: sourceRange, source: source,
                                    decl: decl, value: value, throwsModifier: throwsModifier,
                                    argumentLabels: argumentLabels, expressions: [])

        for node in node.children {
            let tokens = node.value
            if tokens.count > 1 {
                expression.expressions.append(parseExpressionNode(node: node))
            }
        }
        return expression
    }

    private func parseLocation(_ locationAttribute: String) -> SourceLocation {
        let info = locationAttribute.split(separator: ":")
        let line = Int(info[1])! - 1
        let column = Int(info[2])!
        return SourceLocation(line: line, column: column)
    }

    private func parseRange(_ rangeAttribute: String) -> (String, SourceRange) {
        let info = rangeAttribute
            .replacingOccurrences(of: "[", with: "")
            .replacingOccurrences(of: "", with: "")
            .replacingOccurrences(of: " - line", with: "")
            .split(separator: ":")
        let path = info[0]
        let start = SourceLocation(line: Int(info[1])! - 1, column: Int(info[2])! - 1)
        let end = SourceLocation(line: Int(info[3])! - 1, column: Int(info[4])!)
        let source = try! String(contentsOfFile: String(path))
        var lines = [String]()
        source.enumerateLines { (line, stop) in
            lines.append(line)
        }
        var text = ""
        for index in start.line...end.line {
            let line = lines[index]
            let utf8 = line.utf8
            if start.line == end.line {
                text += String(utf8[utf8.index(utf8.startIndex, offsetBy: start.column)..<utf8.index(utf8.startIndex, offsetBy: end.column)])!
            } else {
                if index == start.line {
                    text += String(utf8[utf8.index(utf8.startIndex, offsetBy: start.column)...])!
                } else if index == end.line {
                    text += "\n" + String(utf8[utf8.startIndex..<utf8.index(utf8.startIndex, offsetBy: end.column)])!
                } else {
                    text += "\n" + line
                }
            }
        }
        return (text, SourceRange(start: start, end: end))
    }

    private func parseParameterListNode(node: Node<[Token]>) -> [Parameter] {
        return node.children.map { parseParameter(tokens: $0.value) }
    }

    private func parseParameter(tokens: [Token]) -> Parameter {
        let attributes = parseKeyValueAttributes(tokens: tokens)
        let externalName: String? = attributes["apiName"]
        var localName: String!
        for token in tokens {
            if case .string = token.type {
                localName = token.value
            }
        }
        let type = attributes["type"]!
        return Parameter(externalName: externalName, localName: localName, type: type)
    }

    private func parseResultNode(node: Node<[Token]>) -> FunctionResult {
        return FunctionResult(type: parseKeyValueAttributes(tokens: node.child(at: 0).child(at: 0).value)["id"]!)
    }

    private func parseKeyValueAttributes(tokens: [Token]) -> [String: String] {
        var attributes = [String: String]()
        for (index, token) in tokens.enumerated() {
            switch (token.type, token.value) {
            case (.token, "="):
                attributes[tokens[index - 1].value] = tokens[index + 1].value
            default:
                break
            }
        }
        return attributes
    }

    private func parseInherits(tokens: [Token]) -> String? {
        for (index, token) in tokens.enumerated() {
            switch (token.type, token.value) {
            case (.token, ":"):
                if case .token = tokens[index - 1].type, tokens[index - 1].value == "inherits" {
                    return tokens[index + 1].value
                }
            default:
                break
            }
        }
        return nil
    }

    private func isImplicit(tokens: [Token]) -> Bool {
        return tokens.contains {
            if case .token = $0.type, $0.value == "implicit" {
                return true
            }
            return false
        }
    }
}
