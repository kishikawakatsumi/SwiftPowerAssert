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
    private let buildOptions: BuildOptions

    public init(buildOptions: BuildOptions) {
        self.buildOptions = buildOptions
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
            "-target",
            buildOptions.targetTriple,
            "-sdk",
            buildOptions.sdkRoot,
            "-F",
            "\(buildOptions.sdkRoot)/../../../Developer/Library/Frameworks",
            "-F",
            buildOptions.builtProductsDirectory,
            "-I",
            buildOptions.builtProductsDirectory,
            "-dump-ast"
        ]
        return arguments + ["-primary-file", source.path] + buildOptions.dependencies.filter { $0 != source }.map { $0.path }
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
