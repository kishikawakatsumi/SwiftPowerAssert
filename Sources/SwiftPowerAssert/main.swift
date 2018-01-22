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
import Utility
import POSIX
import PowerAssertCore

do {
    let tool = SwiftPowerAssertTool(arguments: Array(CommandLine.arguments.dropFirst()))
    let options = tool.options

    switch options.subcommand {
    case "test":
        let command = SwiftTestTool()
        try command.run(arguments: options.swiftTestOptions, verbose: options.verbose)
    case "xctest":
        let command = XCTestTool()
        try command.run(arguments: options.xcodebuildOptions, verbose: options.verbose)
    case "transform":
        let command = TransformTool()
        try command.run(source: URL(fileURLWithPath: options.source), options: options.swiftcOptions, verbose: options.verbose)
    case "version":
        print("0.1.0")
    default:
        tool.parser.printUsage(on: stdoutStream)
    }
} catch {
    print("\(error)")
}
