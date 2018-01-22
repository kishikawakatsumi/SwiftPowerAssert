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
import Utility
import POSIX

struct SwiftPowerAssertTool {
    let parser: ArgumentParser
    let options: Options

    init(arguments: [String]) {
        parser = ArgumentParser(commandName: "swift-power-assert", usage: "[options] subcommand [options]", overview: "Provide diagrammed assertions")

        let binder = ArgumentBinder<Options>()
        binder.bind(parser: parser) { $0.subcommand = $1 }
        binder.bind(option: parser.add(option: "--verbose", kind: Bool.self, usage: "Show more debugging information")) { $0.verbose = $1 }

        let test = parser.add(subparser: "test", overview: "Run swift test with power assertion")
        binder.bindArray(option: test.add(option: "-Xswift", kind: [String].self, strategy: .remaining, usage: "Arguments to pass to 'swift test' command")) { $0.swiftTestOptions = $1 }

        let xctest = parser.add(subparser: "xctest", overview: "Run XCTest with power assertion.")
        binder.bindArray(option: xctest.add(option: "-Xxcodebuild", kind: [String].self, strategy: .remaining, usage: "Arguments to pass to 'xcodebuild' command")) { $0.xcodebuildOptions = $1 }

        let transform = parser.add(subparser: "transform", overview: "")
        binder.bind(parser: transform) { $0.subcommand = $1 }
        binder.bind(positional: transform.add(positional: "source", kind: String.self), to: { $0.source = $1 })
        binder.bindArray(option: transform.add(option: "--swiftc-options", kind: [String].self, strategy: .remaining)) { $0.swiftcOptions = $1 }

        do {
            let result = try parser.parse(arguments)
            var options = Options()
            binder.fill(result, into: &options)
            self.options = options
        } catch {
            handle(error: error)
            POSIX.exit(1)
        }
    }
}

struct Options {
    var verbose = false
    var subcommand = ""

    var swiftTestOptions = [String]()
    var xcodebuildOptions = [String]()

    var source = ""
    var swiftcOptions = [String]()
}
