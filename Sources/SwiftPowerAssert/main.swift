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
import SwiftPowerAssertCore

do {
    let parser = ArgumentParser(commandName: "swift-power-assert", usage: "SUBCOMMAND", overview: "SwiftPowerAssert, provide diagrammed assertions in Swift")

    let test = parser.add(subparser: "test", overview: "Run XCTest with power assertion enabled.")
    let verbose = test.add(option: "--verbose", kind: Bool.self, usage: "Show more debugging information")
    let xcargs = test.add(option: "--xcargs", shortName: "-x", kind: [String].self, strategy: .remaining, usage: "swift-power-assert test --xcargs -workspace <workspacename> -scheme <schemeName> [<buildaction>]...")

    let arguments = Array(CommandLine.arguments.dropFirst())
    let result = try parser.parse(arguments)

    switch result.subparser(parser) {
    case let subcommand? where subcommand == "test":
        if let xcodeArguments = result.get(xcargs) {
            let command = TestCommand()
            try command.run(xcarguments: xcodeArguments, verbose: result.get(verbose) ?? false)
        } else {
            test.printUsage(on: stdoutStream)
        }
    default:
        parser.printUsage(on: stdoutStream)
    }
    exit(0)
} catch ArgumentParserError.unknownOption(let option) {
    print("swift-power-assert: error: unknown option \(option); use --help to list available options")
} catch ArgumentParserError.invalidValue(let argument, let error) {
    print("swift-power-assert: error: \(error) for argument \(argument); use --help to print usage")
} catch ArgumentParserError.expectedValue(let option) {
    print("swift-power-assert: error: option \(option) requires a value; provide a value using '\(option) <value>'")
} catch ArgumentParserError.unexpectedArgument(let argument) {
    print("swift-power-assert: error: unexpected argument \(argument); use --help to list available arguments")
} catch ArgumentParserError.expectedArguments(_, let arguments) {
    print("swift-power-assert: error: available actions are: \(arguments.joined(separator: ", "))")
} catch SwiftPowerAssertError.invalidArgument(let description) {
    print("swift-power-assert: error: \(description)")
} catch SwiftPowerAssertError.noUnitTestBundle {
    print("swift-power-assert: error: no unit test bundle found")
} catch SwiftPowerAssertError.buildFailed(let description) {
    print("swift-power-assert: error: \(description)")
} catch SwiftPowerAssertError.taskError(let description) {
    print("swift-power-assert: error: \(description)")
} catch SwiftPowerAssertError.writeFailed(let description, let error) {
    print("swift-power-assert: error: \(description): \(error.localizedDescription)")
} catch SwiftPowerAssertError.internalError(let description, let error) {
    print("swift-power-assert: error: \(description): \(error.localizedDescription)")
}
exit(1)
