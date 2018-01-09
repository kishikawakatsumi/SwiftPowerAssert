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
import SwiftPowerAssertCore

class TestRunner {
    private lazy var temporaryDirectory = {
        return try! TemporaryDirectory(prefix: "com.kishikawakatsumi.swift-power-assert", removeTreeOnDeinit: true)
    }()
    private lazy var temporaryFile = {
        return try! TemporaryFile(dir: temporaryDirectory.path, prefix: "Tests", suffix: ".swift").path
    }()
    private lazy var sourceFilePath = {
        return temporaryFile.asString
    }()
    private lazy var utilitiesFilePath = {
        return temporaryDirectory.path.appending(component: "Utilities.swift").asString
    }()
    private lazy var mainFilePath = {
        return temporaryDirectory.path.appending(component: "main.swift").asString
    }()
    private lazy var executablePath = {
        return sourceFilePath + ".o"
    }()
    private lazy var sdk = {
        return try! SDK.macosx.path()
    }()
    private var targetTriple: String {
        return "x86_64-apple-macosx10.10"
    }
    private lazy var options: [String] = {
        let targetTriple = "x86_64-apple-macosx10.10"
        let buildDirectory = temporaryDirectory.path.asString
        return [
            "-sdk",
            sdk,
            "-target",
            targetTriple,
            "-F",
            sdk + "/../../../Developer/Library/Frameworks",
            "-F",
            buildDirectory,
            "-I",
            buildDirectory
        ]
    }()

    func run(source: String) -> String {
        prepare(source: source)
        compile()

        let result = execute()
        print(result)

        return result
    }

    private func prepare(source: String) {
        try! source.write(toFile: sourceFilePath, atomically: true, encoding: .utf8)
        let processor = SwiftPowerAssert(buildOptions: options, dependencies: [])
        do {
            let transformed = try processor.processFile(input: URL(fileURLWithPath: sourceFilePath))
            try! transformed.write(toFile: sourceFilePath, atomically: true, encoding: .utf8)
        } catch SwiftPowerAssertError.buildFailed(let description) {
            fatalError(description)
        } catch {
            fatalError(error.localizedDescription)
        }

        try! __Util.source.write(toFile: utilitiesFilePath, atomically: true, encoding: .utf8)
        let main = """
            Tests().testMethod()
            """
        try! main.write(toFile: mainFilePath, atomically: true, encoding: .utf8)
    }

    private func compile() {
        let arguments = [
            "/usr/bin/xcrun",
            "swiftc",
            "-O",
            "-whole-module-optimization",
            sourceFilePath,
            utilitiesFilePath,
            mainFilePath,
            "-o",
            executablePath,
            "-target",
            targetTriple,
            "-sdk",
            sdk,
            "-F",
            "\(sdk)/../../../Developer/Library/Frameworks",
            "-Xlinker",
            "-rpath",
            "-Xlinker",
            "\(sdk)/../../../Developer/Library/Frameworks",
        ]

        let process = Process(arguments: arguments)
        try! process.launch()
        let result = try! process.waitUntilExit()
        if case .terminated(let code) = result.exitStatus, code != 0 {
            fatalError(try! result.utf8stderrOutput())
        }
    }

    private func execute() -> String {
        let process = Process(arguments: [executablePath])
        try! process.launch()

        let result = try! process.waitUntilExit()
        if case .terminated(let code) = result.exitStatus, code != 0 {
            fatalError(try! result.utf8stderrOutput())
        }

        return try! result.utf8Output()
    }
}
