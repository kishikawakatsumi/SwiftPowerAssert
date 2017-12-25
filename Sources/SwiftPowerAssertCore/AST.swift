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
    let type: String
    let rawLocation: String
    let rawRange: String
    let location: SourceLocation
    let range: SourceRange
    let source: String
    let decl: String?
    let value: String?
    let throwsModifier: String?
    let argumentLabels: String?
    let isImplicit: Bool
    var expressions = [Expression]()
}

enum Declaration {
    case `import`(ImportDeclaration)
    case `struct`(StructDeclaration)
    case `class`(ClassDeclaration)
    case `enum`(EnumDeclaration)
    case variable(VariableDeclaration)
    case function(FunctionDeclaration)
}

struct ImportDeclaration {
    let importKind: ImportKind?
    let importPath: String
}

enum ImportKind: String {
    case `typealias`
    case `struct`
    case `class`
    case `enum`
    case `protocol`
    case `var`
    case `func`
}

struct StructDeclaration {
    let accessLevel: AccessLevelModifier
    let name: String
    let typeInheritance: String?
    let members: [StructMember]
}

enum StructMember {
    case declaration(Declaration)
}

struct EnumDeclaration {
    let accessLevel: AccessLevelModifier
    let name: String
    let typeInheritance: String?
    let members: [EnumMember]
}

enum EnumMember {
    case `case`(EnumCaseClause)
    case declaration(Declaration)
}

struct EnumCaseClause {
    let cases: [EnumCase]
}

struct EnumCase {
    let name: String
}

struct ClassDeclaration {
    let accessLevel: AccessLevelModifier
    let final: Final?
    let name: String
    let typeInheritance: String?
    let members: [ClassMember]
}

enum ClassMember {
    case declaration(Declaration)
}

enum Final {
    case final
}

struct VariableDeclaration {
    let accessLevel: AccessLevelModifier
    let modifiers: [DeclarationModifier]
    let name: String
    let type: String
    let isConstant: Bool
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
    case `private`, privateSet
    case `fileprivate`, fileprivateSet
    case `internal`, internalSet
    case `public`, publicSet
    case `open`, openSet
}

extension AccessLevelModifier: CustomStringConvertible {
    var description: String {
        switch self {
        case .private, .privateSet:
            return "private"
        case .fileprivate, .fileprivateSet:
            return "fileprivate"
        case .internal, .internalSet:
            return "internal"
        case .public, .publicSet:
            return "public"
        case .open, .openSet:
            return "open"
        }
    }
}

enum DeclarationModifier {
    case `class`
    case `convinience`
    case objc
    case `dynamic`
    case `final`
    case `infix`
    case `lazy`
    case `optional`
    case `override`
    case `postfix`
    case `prefix`
    case `required`
    case `static`
    case `unowned`
    case `unownedSafe`
    case `weak`
    case access(AccessLevelModifier)
    case mutation(MutationModifier)
}

extension DeclarationModifier: CustomStringConvertible {
    var description: String {
        switch self {
        case .class:
            return "class"
        case .convinience:
            return "convinience"
        case .objc:
            return "@objc"
        case .dynamic:
            return "dynamic"
        case .final:
            return "final"
        case .infix:
            return "infix"
        case .lazy:
            return "lazy"
        case .optional:
            return "optional"
        case .override:
            return "override"
        case .postfix:
            return "postfix"
        case .prefix:
            return "prefix"
        case .required:
            return "required"
        case .static:
            return "static"
        case .unowned:
            return "unowned"
        case .unownedSafe:
            return "unownedSafe"
        case .weak:
            return "weak"
        case .access(let accessLevel):
            return "\(accessLevel)"
        case .mutation(let mutation):
            return "\(mutation)"
        }
    }
}

enum MutationModifier {
    case mutating
    case nonmutating
}

extension MutationModifier: CustomStringConvertible {
    var description: String {
        switch self {
        case .mutating:
            return "mutating"
        default:
            return ""
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
