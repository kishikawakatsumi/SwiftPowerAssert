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
    private lazy var options: BuildOptions = {
        let sdk = SDK.macosx
        let sdkPath = sdk.path()
        let sdkVersion = sdk.version()
        return BuildOptions(sdkName: sdk.name + sdkVersion, sdkRoot: sdkPath,
                            platformName: sdk.name, platformTargetPrefix: sdk.os,
                            arch: "x86_64", deploymentTarget: sdkVersion,
                            dependencies: [], builtProductsDirectory: temporaryDirectory.path.asString)
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
        let processor = SwiftPowerAssert(buildOptions: options)
        do {
            let transformed = try processor.processFile(input: URL(fileURLWithPath: sourceFilePath))
            try! transformed.write(toFile: sourceFilePath, atomically: true, encoding: .utf8)
        } catch {
            fatalError("failed to instrument assertions")
        }

        try! __DisplayWidth.myself.write(toFile: utilitiesFilePath, atomically: true, encoding: .utf8)
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
            options.targetTriple,
            "-sdk",
            options.sdkRoot,
            "-F",
            "\(options.sdkRoot)/../../../Developer/Library/Frameworks",
            "-Xlinker",
            "-rpath",
            "-Xlinker",
            "\(options.sdkRoot)/../../../Developer/Library/Frameworks",
        ]

        let process = Process(arguments: arguments)
        try! process.launch()
        let result = try! process.waitUntilExit()
        if case .terminated(let code) = result.exitStatus, code != 0 {
            print(try! result.utf8stderrOutput())
            fatalError("failed to compile an instrumented file")
        }
    }

    private func execute() -> String {
        let process = Process(arguments: [executablePath])
        try! process.launch()

        let result = try! process.waitUntilExit()
        if case .terminated(let code) = result.exitStatus, code != 0 {
            print(try! result.utf8stderrOutput())
            fatalError("failed to run an instrumented code")
        }

        return try! result.utf8Output()
    }
}
