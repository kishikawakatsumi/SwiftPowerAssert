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
import SwiftSyntax

public final class SwiftPowerAssert {
    private let sources: String
    private let output: String?
    private let testable: Bool

    public init(sources: String, output: String? = nil, testable: Bool = false) {
        self.sources = sources
        self.output = output
        self.testable = testable
    }

    public func run() throws {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: sources, isDirectory: &isDirectory) else {
            throw SwiftPowerAssertError.noSuchFileOrDirectory
        }

        let testFileURLs: [URL]
        if isDirectory.boolValue {
            guard let enumerator = FileManager.default.enumerator(at: URL(fileURLWithPath: sources), includingPropertiesForKeys: nil) else {
                // No file to be processed
                return
            }
            testFileURLs = enumerator.allObjects.flatMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
        } else {
            testFileURLs = [URL(fileURLWithPath: sources)]
        }

        for testFileURL in testFileURLs {
            try processFile(fileURL: testFileURL)
        }
    }

    private func processFile(fileURL: URL) throws {
        let sourceFile: SourceFileSyntax
        do {
            sourceFile = try Syntax.parse(fileURL)
        } catch let error {
            throw SwiftPowerAssertError.parseError(fileURL: fileURL, description: error.localizedDescription)
        }
        
        let instrumented = try Instrumentor(testable: testable).instrument(sourceFile: sourceFile)

        var isDirectory: ObjCBool = false
        if let output = output, FileManager.default.fileExists(atPath: output, isDirectory: &isDirectory) && isDirectory.boolValue {
            try "\(instrumented)".write(to: URL(fileURLWithPath: output).appendingPathComponent(fileURL.lastPathComponent), atomically: true, encoding: .utf8)
        } else {
            try "\(instrumented)".write(to: fileURL, atomically: true, encoding: .utf8)
        }
    }
}

enum SwiftPowerAssertError: Error {
    case noSuchFileOrDirectory
    case parseError(fileURL: URL, description: String)
}

extension SwiftPowerAssertError: CustomStringConvertible {
    var description: String {
        switch self {
        case .noSuchFileOrDirectory:
            return "No such file or directory"
        case .parseError(let fileURL, let description):
            return "Couldn't parse the given source file: \(fileURL)\n\(description)"
        }
    }
}
