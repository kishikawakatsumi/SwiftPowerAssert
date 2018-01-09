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

struct SourceFile {
    let sourceText: String.UTF8View
    let sourceLines: [SourceLine]

    subscript(range: SourceRange) -> String {
        let start = range.start
        let end = range.end
        let startIndex: String.Index
        if start.line > 0 {
            startIndex = sourceText.index(sourceText.startIndex, offsetBy: sourceLines[start.line].offset + start.column)
        } else {
            startIndex = sourceText.index(sourceText.startIndex, offsetBy: start.column)
        }
        let endIndex: String.Index
        if end.line > 0 {
            endIndex = sourceText.index(sourceText.startIndex, offsetBy: sourceLines[end.line].offset + end.column)
        } else {
            endIndex = sourceText.index(sourceText.startIndex, offsetBy: end.column)
        }
        return String(String(sourceText)[startIndex..<endIndex])
    }
}

struct SourceLine {
    let text: String.UTF8View
    let lineNumber: Int
    let offset: Int
}
