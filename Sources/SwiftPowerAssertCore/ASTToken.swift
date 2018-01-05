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

class ASTToken {
    enum TokenType {
        case token
        case symbol
        case string
        case indent(Int)
    }

    var type: TokenType
    var value: String

    init(type: TokenType, value: String) {
        self.type = type
        self.value = value
    }
}

extension ASTToken: CustomStringConvertible {
    var description: String {
        switch type {
        case .indent(let count):
            return String(repeating: "_", count: count)
        case .token:
            return "\(value)"
        case .symbol:
            return "'\(value)'"
        case .string:
            return "\"\(value)\""
        }
    }
}
