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

extension Expression: Hashable {
    var hashValue: Int {
        return range.hashValue
    }

    static func ==(lhs: Expression, rhs: Expression) -> Bool {
        return lhs.range == rhs.range
    }
}

enum Declaration {
    case `class`(ClassDeclaration)
    case function(FunctionDeclaration)
}

struct ClassDeclaration {
    let accessLevel: String
    let name: String
    let typeInheritance: String?
    let members: [ClassMember]
}

enum ClassMember {
    case declaration(Declaration)
}

struct FunctionDeclaration {
    let accessLevel: String
    let name: String
    let parameters: [Parameter]
    let body: [Statement]
}

struct Parameter {
    let externalName: String?
    let localName: String
    let type: String
}

struct FunctionResult {
    let type: String
}

struct SourceRange {
    let start: SourceLocation
    let end: SourceLocation
}

extension SourceRange: Hashable {
    var hashValue: Int {
        return 31 &* start.hashValue &+ end.hashValue
    }

    static func ==(lhs: SourceRange, rhs: SourceRange) -> Bool {
        return lhs.start == rhs.start && lhs.end == rhs.end
    }
}

struct SourceLocation {
    let line: Int
    let column: Int
}

extension SourceLocation: Hashable {
    var hashValue: Int {
        return 31 &* line &+ column
    }

    static func ==(lhs: SourceLocation, rhs: SourceLocation) -> Bool {
        return lhs.line == rhs.line && lhs.column == rhs.column
    }
}
