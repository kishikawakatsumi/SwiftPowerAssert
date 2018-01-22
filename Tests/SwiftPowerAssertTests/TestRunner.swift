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

class TestRunner {
    let env = TestEnvironments()

    func run(source: String) -> String {
        prepare(source: source)
        compile()

        let result = execute()
        print(result)

        return result
    }

    private func prepare(source: String) {
        try! source.write(toFile: env.sourceFilePath, atomically: true, encoding: .utf8)
        let processor = SwiftPowerAssert(buildOptions: env.parseOptions, dependencies: [])
        let transformed = try! processor.processFile(input: URL(fileURLWithPath: env.sourceFilePath))

        try! transformed.write(toFile: env.sourceFilePath, atomically: true, encoding: .utf8)
        try! __Util.source.write(toFile: env.utilitiesFilePath, atomically: true, encoding: .utf8)
        let main = """
            #if os(macOS)
            Tests().testMethod()
            #else
            Tests(name: "Tests", testClosure: { _ in }).testMethod()
            #endif
            """
        try! main.write(toFile: env.mainFilePath, atomically: true, encoding: .utf8)
    }

    private func compile() {
        let process = Process(arguments: env.execOptions)
        try! process.launch()
        ProcessManager.default.add(process: process)
        let result = try! process.waitUntilExit()
        if case .terminated(let code) = result.exitStatus, code != 0 {
            fatalError(try! result.utf8stderrOutput())
        }
    }

    private func execute() -> String {
        let process = Process(arguments: [env.executablePath])
        try! process.launch()
        ProcessManager.default.add(process: process)
        let result = try! process.waitUntilExit()
        if case .terminated(let code) = result.exitStatus, code != 0 {
            fatalError(try! result.utf8stderrOutput())
        }
        return try! result.utf8Output()
    }
}
