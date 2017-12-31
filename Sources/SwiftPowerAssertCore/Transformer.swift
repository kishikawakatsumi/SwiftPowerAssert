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

struct Transformer {
    let target: String
    let sdkRoot: String

    init(target: String, sdkRoot: String) {
        self.target = target
        self.sdkRoot = sdkRoot
    }

    func transform(sourceFile: URL, dependencies: [URL], buildDirectory: String) throws -> String {
        let arguments = buildArguments(source: sourceFile, dependencies: dependencies, buildDirectory: buildDirectory)
        let rawAST = try dumpAST(arguments: arguments)
        let tokens = tokenize(rawAST: rawAST)
        let node = lex(tokens: tokens)
        let root = parse(node: node)

        let sourceText = try String(contentsOf: sourceFile)
        let transformed = instrument(source: sourceText, root: root)

        return transformed
    }

    private func buildArguments(source: URL, dependencies: [URL], buildDirectory: String) -> [String] {
        let arguments = [
            "/usr/bin/xcrun",
            "swift",
            "-frontend",
            "-target",
            target,
            "-sdk",
            sdkRoot,
            "-F",
            "\(sdkRoot)/../../../Developer/Library/Frameworks",
            "-F",
            buildDirectory,
            "-dump-ast"
        ]
        return arguments + ["-primary-file", source.path] + dependencies.filter { $0 != source }.map { $0.path }
    }

    private func dumpAST(arguments: [String]) throws -> String {
        let process = Process(arguments: arguments)
        try process.launch()
        let result = try process.waitUntilExit()
        let output = try result.utf8stderrOutput()
        if case .terminated(let code) = result.exitStatus, code != 0 {
            throw SwiftPowerAsserrError.buildFailed(output)
        }
        return output
    }

    private func tokenize(rawAST: String) -> [Token] {
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

        let tokenizer = Tokenizer()
        return tokenizer.tokenize(source: lines.joined(separator: "\n"))
    }

    private func lex(tokens: [Token]) -> Node<[Token]> {
        let lexer = Lexer()
        return lexer.lex(tokens: tokens)
    }

    private func parse(node: Node<[Token]>) -> AST {
        let parser = Parser()
        return parser.parse(root: node)
    }

    private func instrument(source: String, root: AST) -> String {
        let instrumentor = Instrumentor(source: source)
        return instrumentor.instrument(node: root)
    }
}
