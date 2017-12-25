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
                case (.token, "import_decl"):
                    declarations.append(.import(parseImportDeclarationNode(node: node)))
                case (.token, "struct_decl"):
                    declarations.append(.struct(parseStructDeclarationNode(node: node)))
                case (.token, "enum_decl"):
                    declarations.append(.enum(parseEnumDeclarationNode(node: node)))
                case (.token, "class_decl"):
                    declarations.append(.class(parseClassDeclarationNode(node: node)))
                case (.token, "func_decl"):
                    declarations.append(.function(parseFunctionDeclarationNode(node: node)))
                case (.token, "var_decl"):
                    declarations.append(.variable(parseVariableDeclarationNode(node: node)))
                default:
                    break
                }
            }
        }
        return AST(declarations: declarations)
    }

    private func parseImportDeclarationNode(node: Node<[Token]>) -> ImportDeclaration {
        var importKind: ImportKind? = nil
        var importPath: String!

        for token in node.value {
            switch token.type {
            case .symbol:
                importPath = token.value
            default:
                break
            }
        }

        let attributes = parseKeyValueAttributes(tokens: node.value)
        if let kind = attributes["kind"] {
            importKind = ImportKind(rawValue: kind)
        }

        return ImportDeclaration(importKind: importKind, importPath: importPath)
    }

    private func parseStructDeclarationNode(node: Node<[Token]>) -> StructDeclaration {
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

        var accessLevel: AccessLevelModifier
        let attributes = parseKeyValueAttributes(tokens: tokens)
        if let access = attributes["access"] {
            accessLevel = AccessLevelModifier(rawValue: access)!
        } else {
            accessLevel = .internal
        }

        let typeInheritance = parseInherits(tokens: tokens)

        var members = [StructMember]()
        for node in node.children {
            let tokens = node.value
            if isImplicit(tokens: tokens) {
                continue
            }
            for token in tokens {
                switch (token.type, token.value) {
                case (.token, "var_decl"):
                    members.append(.declaration(.variable(parseVariableDeclarationNode(node: node))))
                case (.token, "func_decl"):
                    members.append(.declaration(.function(parseFunctionDeclarationNode(node: node))))
                default:
                    break
                }
            }
        }

        return StructDeclaration(accessLevel: accessLevel, name: name, typeInheritance: typeInheritance, members: members)
    }

    private func parseEnumDeclarationNode(node: Node<[Token]>) -> EnumDeclaration {
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

        var members = [EnumMember]()
        var cases = [EnumCase]()
        for node in node.children {
            let tokens = node.value
            for token in tokens {
                if isImplicit(tokens: tokens) {
                    continue
                }
                switch (token.type, token.value) {
                case (.token, "enum_element_decl"):
                    cases.append(parseEnumElementDeclarationNode(node: node))
                case (.token, "var_decl"):
                    members.append(.declaration(.variable(parseVariableDeclarationNode(node: node))))
                case (.token, "func_decl"):
                    members.append(.declaration(.function(parseFunctionDeclarationNode(node: node))))
                default:
                    break
                }
            }
        }
        
        members.append(.case(EnumCaseClause(cases: cases)))

        return EnumDeclaration(accessLevel: accessLevel, name: name, typeInheritance: typeInheritance, members: members)
    }

    private func parseEnumElementDeclarationNode(node: Node<[Token]>) -> EnumCase {
        var name: String!
        for token in node.value {
            switch token.type {
            case .string:
                name = token.value
            default:
                break
            }
        }
        return EnumCase(name: name)
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
        let final = parseFinal(tokens: tokens)

        var members = [ClassMember]()
        for node in node.children {
            let tokens = node.value
            if isImplicit(tokens: tokens) {
                continue
            }
            for token in tokens {
                switch (token.type, token.value) {
                case (.token, "var_decl"):
                    members.append(.declaration(.variable(parseVariableDeclarationNode(node: node))))
                case (.token, "func_decl"):
                    members.append(.declaration(.function(parseFunctionDeclarationNode(node: node))))
                default:
                    break
                }
            }
        }

        return ClassDeclaration(accessLevel: accessLevel, final: final, name: name, typeInheritance: typeInheritance, members: members)
    }

    private func parseVariableDeclarationNode(node: Node<[Token]>) -> VariableDeclaration {
        let tokens = node.value

        var name: String!
        var isConstant = false
        var modifiers = [DeclarationModifier]()

        for token in tokens {
            switch token.type {
            case .token where token.value == "let":
                isConstant = true
            case .token where token.value == "@objc":
                modifiers.append(.objc)
            case .token where token.value == "dynamic":
                modifiers.append(.dynamic)
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

        let type = attributes["type"]!

        return VariableDeclaration(accessLevel: accessLevel, modifiers: modifiers, name: name, type: type, isConstant: isConstant)
    }

    private func parseFunctionDeclarationNode(node: Node<[Token]>) -> FunctionDeclaration {
        let tokens = node.value

        var name: String!
        var modifiers = [DeclarationModifier]()

        for token in tokens {
            switch token.type {
            case .string:
                name = token.value
            case .token where token.value == "@objc":
                modifiers.append(.objc)
            case .token where token.value == "dynamic":
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
                    body.append(contentsOf: parseBraceStatementNode(node: node))
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

    private func parseBraceStatementNode(node: Node<[Token]>) -> [Statement] {
        var statements = [Statement]()
        for node in node.children {
            for token in node.value {
                switch (token.type, token.value) {
                case (.token, "var_decl"):
                    statements.append(.declaration(.variable(parseVariableDeclarationNode(node: node))))
                case (.token, "call_expr"):
                    statements.append(.expression(parseExpressionNode(node: node)))
                default:
                    break
                }
            }
        }
        return statements
    }

    private func parseExpressionNode(node: Node<[Token]>) -> Expression {
        let tokens = node.value
        let attributes = parseKeyValueAttributes(tokens: tokens)

        let rawLocation = attributes["location"]!
        let location = parseLocation(rawLocation)
        let rawRange = attributes["range"]!
        let source = parseRange(rawRange)
        let argumentLabels = attributes["arg_labels"]
        var throwsModifier: String?
        for token in tokens {
            switch token.type {
            case .token where token.value == "nothrow":
                throwsModifier = "nothrow"
            case .token where token.value == "throws":
                throwsModifier = "throws"
            case .token where token.value == "rethrows":
                throwsModifier = "rethrows"
            default:
                break
            }
        }
        var expression = Expression(rawValue: tokens[1].value, type: attributes["type"]!, rawLocation: rawLocation, rawRange: rawRange, location: location, range: source.1, source: source.0, decl: attributes["decl"], value: attributes["value"], throwsModifier: throwsModifier, argumentLabels: argumentLabels, isImplicit: isImplicit(tokens: tokens), expressions: [])

        for node in node.children {
            for token in node.value {
                switch token.type {
                case .token where token.value == "location":
                    expression.expressions.append(parseExpressionNode(node: node))
                default:
                    break
                }
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
            if start.line == end.line {
                let line = lines[index]
                text += line[line.index(line.startIndex, offsetBy: start.column)..<line.index(line.startIndex, offsetBy: end.column)]
            } else {
                if index == start.line {
                    let line = lines[index]
                    text += line[line.index(line.startIndex, offsetBy: start.column)...]
                } else if index == end.line {
                    let line = lines[index]
                    text += "\n" + line[line.startIndex..<line.index(line.startIndex, offsetBy: end.column)]
                } else {
                    let line = lines[index]
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

    private func parseFinal(tokens: [Token]) -> Final? {
        for token in tokens {
            switch (token.type, token.value) {
            case (.token, "final"):
                return .final
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
