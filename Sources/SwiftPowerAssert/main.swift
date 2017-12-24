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

import SwiftPowerAssertCore
import Commander

struct CommanderArguments {
    static let sources = Argument<String>("sources", description: "file or directory")
}

struct CommanderOptions {
    static let output = Option("output", default: "", description: "file or directory")
}

let generate = command(
    CommanderArguments.sources,
    CommanderOptions.output
) { sources, output in
    let runner: SwiftPowerAssert
    if output.isEmpty {
        runner = SwiftPowerAssert(sources: sources)
    } else {
        runner = SwiftPowerAssert(sources: sources, output: output)
    }
    try runner.run()
}

let group = Group()
group.addCommand("instrument", "Instrument power-assert feature into the code.", generate)
group.run()
