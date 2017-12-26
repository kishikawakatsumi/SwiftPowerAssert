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

public final class SwiftPowerAssert {
    private let sources: String
    private let output: String?
    private let options: Options

    public init(sources: String, output: String? = nil, options: Options = Options()) {
        self.sources = sources
        self.output = output
        self.options = options
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
        let sdk = options.sdk
        let sdkPath = sdk.path
        let target = "\(options.arch)-apple-\(options.sdk)\(options.deploymentTarget)"

        let arguments = [
            "/usr/bin/xcrun",
            "swiftc",
            fileURL.path,
            "-target",
            target,
            "-sdk",
            sdkPath,
            "-F",
            "\(sdkPath)/../../../Developer/Library/Frameworks",
            "-Onone",
            "-dump-ast"
        ]

        let compile = Process(arguments: arguments)
        try compile.launch()
        let compileResult = try compile.waitUntilExit()
        switch compileResult.exitStatus {
        case .terminated(_):
            break
        case .signalled(_):
            break
        }

        let result = try compileResult.utf8stderrOutput()
        var lines = [String]()
        result.enumerateLines { (line, stop) in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("(normal_conformance") ||
                trimmed.hasPrefix("(abstract_conformance") ||
                trimmed.hasPrefix("(specialized_conformance") ||
                trimmed.hasPrefix("(assoc_type") ||
                trimmed.hasPrefix("(value req") ||
                !trimmed.hasPrefix("(") {
                return
            }
            lines.append(line)
        }

        let tokenizer = Tokenizer()
        let tokens = tokenizer.tokenize(source: lines.joined(separator: "\n"))

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

public struct Options {
    public let sdk = SDK.macosx
    public let arch = Arch.x86_64
    public let deploymentTarget = "10.10"
    public let testable: Bool = false

    public init() {}
}

public enum SDK: String {
    case macosx
    case iphoneos
    case iphonesimulator
    case appletvos
    case appletvsimulator
    case watchos
    case watchsimulator

    public var path: String {
        let shell = Process(arguments: ["/usr/bin/xcrun", "--sdk", "\(self)", "--show-sdk-path"])
        try! shell.launch()
        let result = try! shell.waitUntilExit().utf8Output()
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public enum Arch: String {
    case x86_64
    case i386
}
