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

struct ASTPrinter {
    func show(_ node: Declaration) {
        switch node {
        case .import(let declaration):
            show(declaration)
        case .struct(let declaration):
            show(declaration)
        case .enum(let declaration):
            show(declaration)
        case .class(let declaration):
            show(declaration)
        case .variable(let declaration):
            show(declaration)
        case .function(let declaration):
            show(declaration)
        }
    }

    func show(_ node: ImportDeclaration) {
        if let importKind = node.importKind {
            print("import \(importKind) \(node.importPath)")
        } else {
            print("import \(node.importPath)")
        }
    }

    func show(_ node: StructDeclaration) {
        let inheritance: String
        if let typeInheritance = node.typeInheritance {
            inheritance = ": \(typeInheritance)"
        } else {
            inheritance = ""
        }
        print("\(node.accessLevel) struct \(node.name)\(inheritance) {")
        for member in node.members {
            switch member {
            case .declaration(let declaration):
                show(declaration)
            }
        }
        print("}")
    }

    func show(_ node: EnumDeclaration) {
        let inheritance: String
        if let typeInheritance = node.typeInheritance {
            inheritance = ": \(typeInheritance)"
        } else {
            inheritance = ""
        }
        print("\(node.accessLevel) enum \(node.name)\(inheritance) {")
        for member in node.members {
            switch member {
            case .case(let caseClause):
                show(caseClause)
            case .declaration(let declaration):
                show(declaration)
            }
        }
        print("}")
    }

    func show(_ node: EnumCaseClause) {
        for `case` in node.cases {
            print("    case \(`case`.name)")
        }
    }

    func show(_ node: ClassDeclaration) {
        let inheritance: String
        if let typeInheritance = node.typeInheritance {
            inheritance = ": \(typeInheritance)"
        } else {
            inheritance = ""
        }
        print("\(node.accessLevel) class \(node.name)\(inheritance) {")
        for member in node.members {
            switch member {
            case .declaration(let declaration):
                show(declaration)
            }
        }
        print("}")
    }

    func show(_ node: VariableDeclaration) {
        let variable = (node.modifiers.map { "\($0)" } + ["\(node.accessLevel)"] + [node.isConstant ? "let" : "var"] + ["\(node.name): \(node.type)"]).joined(separator: " ")
        print("    " + variable)
    }

    func show(_ node: FunctionDeclaration) {
        let parameters = node.parameters.filter {
            $0.localName != "self"
            }
            .map {
                var parameter = ""
                if let externalName = $0.externalName, externalName != $0.localName {
                    parameter += "\(externalName) "
                }
                parameter += "\($0.localName): "
                parameter += "\($0.type)"
                return parameter
            }
            .joined(separator: ", ")

        let modifiers = (node.modifiers.map { "\($0)" } + ["\(node.accessLevel)"]).joined(separator: " ")
        var function = "    \(modifiers) func \(node.name)(\(parameters))"
        if let _ = node.throwBehavior {
            function += " throws"
        }
        if let result = node.result {
            function += " -> \(result.type) {"
        } else {
            function += " {"
        }
        print(function)

        for statement in node.body {
            switch statement {
            case .expression(let expression):
                print(expression.rawValue)
            case .declaration(let declaration):
                show(declaration)
            }
        }
        print("    }")
    }

    func show(_ node: AST) {
        node.declarations.forEach {
            show($0)
        }
    }
}
