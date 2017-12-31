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

struct AST {
    let declarations: [Declaration]
}

enum Statement {
    case expression(Expression)
    case declaration(Declaration)
}

struct Expression {
    let rawValue: String
    let type: String!
    let rawLocation: String!
    let rawRange: String!
    let location: SourceLocation!
    let range: SourceRange!
    let source: String!
    let decl: String?
    let value: String?
    let throwsModifier: String?
    let argumentLabels: String?
    var expressions = [Expression]()
}

enum Declaration {
    case `class`(ClassDeclaration)
    case function(FunctionDeclaration)
}

struct ClassDeclaration {
    let accessLevel: AccessLevelModifier
    let name: String
    let typeInheritance: String?
    let members: [ClassMember]
}

enum ClassMember {
    case declaration(Declaration)
}

struct FunctionDeclaration {
    let accessLevel: AccessLevelModifier
    let modifiers: [DeclarationModifier]
    let name: String
    let parameters: [Parameter]
    let throwBehavior: ThrowsModifier?
    let result: FunctionResult?
    let body: [Statement]
}

struct Parameter {
    let externalName: String?
    let localName: String
    let type: String
}

enum ThrowsModifier {
    case `throws`, `rethrows`
}

struct FunctionResult {
    let type: String
}

enum AccessLevelModifier: String {
    case `private`
    case `fileprivate`
    case `internal`
    case `public`
    case `open`
}

enum DeclarationModifier {
    case `class`
    case objc
    case `dynamic`
}

extension DeclarationModifier: CustomStringConvertible {
    var description: String {
        switch self {
        case .class:
            return "class"
        case .objc:
            return "@objc"
        case .dynamic:
            return "dynamic"
        }
    }
}

struct SourceRange {
    let start: SourceLocation
    let end: SourceLocation
}

struct SourceLocation {
    let line: Int
    let column: Int
}
