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
import Basic
import PowerAssertCore

struct TransformTool {
    func run(source: URL, options: [String], verbose: Bool = false) throws {
        #if os(macOS)
        let targetTriple = "x86_64-apple-macosx10.10"
        #else
        let targetTriple = "x86_64-unknown-linux"
        #endif
        var buildOptions = [
            "-target",
            targetTriple,
        ]
        #if os(macOS)
        let sdk = try! SDK.macosx.path()
        buildOptions += [
            "-sdk",
            sdk,
            "-F",
            sdk + "/../../../Developer/Library/Frameworks"
        ]
        #endif
        let processor = SwiftPowerAssert(buildOptions: buildOptions)
        let transformed = try processor.processFile(input: source, verbose: verbose)
        
        try transformed.write(to: source, atomically: true, encoding: .utf8)
        try __Util.source.write(to: source.deletingLastPathComponent().appendingPathComponent("Utilities.swift"), atomically: true, encoding: .utf8)
    }
}
