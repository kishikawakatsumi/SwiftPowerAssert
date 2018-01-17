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

class ASTNode<T> {
    var value: T
    var children = [ASTNode]()
    weak var parent: ASTNode?

    init(_ value: T) {
        self.value = value
    }

    func append(_ child: ASTNode) {
        children.append(child)
        child.parent = self
    }
}

extension ASTNode: CustomStringConvertible {
    var description: String {
        return recursiveDescription(self, level: 0)
    }

    private func recursiveDescription(_ node: ASTNode, level: Int) -> String {
        var description = "\(String(repeating: "  ", count: level))\(node.value)\n"
        for child in node.children {
            description += recursiveDescription(child, level: level + 1)
        }
        return description
    }
}
