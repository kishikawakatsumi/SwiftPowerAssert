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
        let compile = Process()
        let pipe = Pipe()
        compile.standardError = pipe
        compile.launchPath = "/usr/bin/xcrun"
        compile.arguments = [
            "swift",
            "-frontend",
            "-c",
            fileURL.path,
            "-target",
            "x86_64-apple-macosx10.10",
            "-enable-objc-interop",
            "-sdk",
            "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.13.sdk",
            "-F",
            "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/Library/Frameworks",
            "-Onone",
            "-dump-ast"
        ]
        compile.launch()

        let result = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)!

        let tokenizer = Tokenizer()
        let tokens = tokenizer.tokenize(source: result)

        let lexer = Lexer()
        let node = lexer.lex(tokens: tokens)

        let parser = Parser()
        let root = parser.parse(root: node)

        let instrumentor = Instrumentor(source: try String(contentsOf: fileURL))
        let source = instrumentor.instrument(node: root)

        var isDirectory: ObjCBool = false
        if let output = output, FileManager.default.fileExists(atPath: output, isDirectory: &isDirectory) && isDirectory.boolValue {
            try source.write(to: URL(fileURLWithPath: output).appendingPathComponent(fileURL.lastPathComponent), atomically: true, encoding: .utf8)
        } else {
            try! source.write(to: fileURL, atomically: true, encoding: .utf8)
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
