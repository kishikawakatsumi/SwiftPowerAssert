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

func handle(error: Any) {
    switch error {
    case let anyError as AnyError:
        handle(error: anyError.underlyingError)
    default:
        handle(error)
    }
}

private func handle(_ error: Any) {
    switch error {
    case ArgumentParserError.expectedArguments(let parser, _):
        print(error: error)
        parser.printUsage(on: stderrStream)
    default:
        print(error: error)
    }
}

private func print(error: Any) {
    let writer = InteractiveWriter.stderr
    writer.write("error: ", inColor: .red, bold: true)
    writer.write("\(error)")
    writer.write("\n")
}

final class InteractiveWriter {
    static let stderr = InteractiveWriter(stream: stderrStream)

    let term: TerminalController?
    let stream: OutputByteStream

    init(stream: OutputByteStream) {
        self.term = (stream as? LocalFileOutputByteStream).flatMap(TerminalController.init(stream:))
        self.stream = stream
    }

    func write(_ string: String, inColor color: TerminalController.Color = .noColor, bold: Bool = false) {
        if let term = term {
            term.write(string, inColor: color, bold: bold)
        } else {
            stream <<< string
            stream.flush()
        }
    }
}
