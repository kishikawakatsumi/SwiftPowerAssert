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
import SwiftPowerAssertCore

do {
    let parser = ArgumentParser(commandName: "swift-power-assert", usage: "filename [--input naughty_words.txt]", overview: "Swearcheck checks a file of code for swearing, because let's face it: you were angry coding last night.")
    let instrument = parser.add(subparser: "instrument", overview: "Instrument test files.")
    let sources = instrument.add(positional: "sources", kind: String.self, optional: false, usage: "file or directory")
    let output = instrument.add(option: "--output", shortName: "-o", kind: String.self, usage: "A filename containing naughty words in your language")

    let args = Array(CommandLine.arguments.dropFirst())
    let result = try parser.parse(args)

    guard let input = result.get(sources) else {
        throw ArgumentParserError.expectedArguments(parser, ["sources"])
    }

    let runner: SwiftPowerAssert
    if let output = result.get(output) {
        runner = SwiftPowerAssert(sources: input, output: output)
    } else {
        runner = SwiftPowerAssert(sources: input)
    }
    try runner.run()
} catch ArgumentParserError.expectedValue(let value) {
    print("Missing value for argument \(value).")
} catch ArgumentParserError.expectedArguments(_, let stringArray) {
    print("Missing arguments: \(stringArray.joined()).")
} catch {
    print(error.localizedDescription)
}

