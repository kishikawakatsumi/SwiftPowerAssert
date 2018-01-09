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

struct CapturedExpression {
    let text: String
    let column: Int
    let expression: Expression
}

extension CapturedExpression: Hashable {
    var hashValue: Int {
        return column.hashValue
    }

    static func ==(lhs: CapturedExpression, rhs: CapturedExpression) -> Bool {
        return lhs.column == rhs.column
    }
}


extension CapturedExpression: Comparable {
    static func <(lhs: CapturedExpression, rhs: CapturedExpression) -> Bool {
        return lhs.column < rhs.column
    }
}
