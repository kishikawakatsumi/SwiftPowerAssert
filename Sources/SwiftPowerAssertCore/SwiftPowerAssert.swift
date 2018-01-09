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
    private let buildOptions: [String]
    private let dependencies: [URL]

    public init(buildOptions: [String], dependencies: [URL]) {
        self.buildOptions = buildOptions
        self.dependencies = dependencies
    }

    public func processFile(input: URL, verbose: Bool = false) throws -> String {
        return try transform(sourceFile: input, verbose: verbose)
    }

    private func transform(sourceFile: URL, verbose: Bool = false) throws -> String {
        let sourceText: String
        do {
            sourceText = try String(contentsOf: sourceFile)
        } catch {
            throw SwiftPowerAssertError.internalError("failed to read source file from: \(sourceFile)", error)
        }

        let arguments = buildArguments(source: sourceFile)
        let rawAST = try dumpAST(arguments: arguments)
        let tokens = tokenize(rawAST: rawAST)
        let node = lex(tokens: tokens)
        let root = parse(node: node)
        let transformed = transform(source: sourceText, root: root, verbose: verbose)
        return transformed
    }

    private func buildArguments(source: URL) -> [String] {
        let arguments = [
            "/usr/bin/xcrun",
            "swift",
            "-frontend",
            "-parse-as-library",
            "-dump-ast"
        ]
        return arguments + buildOptions + ["-primary-file", source.path] + dependencies.map { $0.path }
    }

    private func dumpAST(arguments: [String]) throws -> String {
        let process = Process(arguments: arguments)
        try! process.launch()
        let result = try! process.waitUntilExit()
        let output = try! result.utf8stderrOutput()
        switch result.exitStatus {
        case .terminated(let code) where code == 0:
            return output
        default:
            throw SwiftPowerAssertError.buildFailed(output)
        }
    }

    private func tokenize(rawAST: String) -> [ASTToken] {
        var lines = [String]()
        rawAST.enumerateLines { (line, stop) in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("(normal_conformance") || trimmed.hasPrefix("(abstract_conformance") ||
                trimmed.hasPrefix("(specialized_conformance") || trimmed.hasPrefix("(assoc_type") ||
                trimmed.hasPrefix("(value req") || !trimmed.hasPrefix("(") {
                return
            }
            lines.append(line)
        }

        let tokenizer = ASTTokenizer()
        return tokenizer.tokenize(source: lines.joined(separator: "\n"))
    }

    private func lex(tokens: [ASTToken]) -> ASTNode<[ASTToken]> {
        let lexer = ASTLexer()
        return lexer.lex(tokens: tokens)
    }

    private func parse(node: ASTNode<[ASTToken]>) -> AST {
        let parser = ASTParser()
        return parser.parse(root: node)
    }

    private func transform(source: String, root: AST, verbose: Bool = false) -> String {
        let transformer = Transformer(source: source, verbose: verbose)
        return transformer.transform(node: root)
    }
}

public enum SDK {
    case macosx
    case iphoneos
    case iphonesimulator
    case watchos
    case watchsimulator
    case appletvos
    case appletvsimulator

    public var name: String {
        switch self {
        case .macosx:
            return "macosx"
        case .iphoneos:
            return "iphoneos"
        case .iphonesimulator:
            return "iphonesimulator"
        case .watchos:
            return "watchos"
        case .watchsimulator:
            return "watchsimulator"
        case .appletvos:
            return "appletvos"
        case .appletvsimulator:
            return "appletvsimulator"
        }
    }

    public var os: String {
        switch self {
        case .macosx:
            return "macosx"
        case .iphoneos, .iphonesimulator:
            return "ios"
        case .watchos, .watchsimulator:
            return "watchos"
        case .appletvos, .appletvsimulator:
            return "tvos"
        }
    }

    public func path() throws -> String {
        let shell = Process(arguments: ["/usr/bin/xcrun", "--sdk", name, "--show-sdk-path"])
        try! shell.launch()
        let result = try! shell.waitUntilExit()
        let output = try! result.utf8Output()
        switch result.exitStatus {
        case .terminated(let code) where code == 0:
            return output.trimmingCharacters(in: .whitespacesAndNewlines)
        default:
            let error = try! result.utf8stderrOutput()
            throw SwiftPowerAssertError.taskError(error)
        }
    }

    public func version() throws -> String {
        let shell = Process(arguments: ["defaults", "read", "\(try path())/SDKSettings.plist", "Version"])
        try! shell.launch()
        let result = try! shell.waitUntilExit()
        let output = try! result.utf8Output()
        switch result.exitStatus {
        case .terminated(let code) where code == 0:
            return output.trimmingCharacters(in: .whitespacesAndNewlines)
        default:
            let error = try! result.utf8stderrOutput()
            throw SwiftPowerAssertError.taskError(error)
        }
    }
}
