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
import SwiftSyntax

public final class SwiftPowerAssert {
    private let sources: String
    private let output: String?
    private let internalTest: Bool

    public init(sources: String, output: String? = nil, internalTest: Bool = false) {
        self.sources = sources
        self.output = output
        self.internalTest = internalTest
    }

    public func run() throws {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: sources, isDirectory: &isDirectory) else {
            print("No such file or directory")
            throw Error.noSuchFileOrDirectory
        }

        let testFileURLs: [URL]
        if isDirectory.boolValue {
            guard let enumerator = FileManager.default.enumerator(at: URL(fileURLWithPath: sources), includingPropertiesForKeys: nil) else {
                // No file to be processed
                return
            }
            testFileURLs = enumerator.allObjects.flatMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
        } else {
            testFileURLs = [URL(fileURLWithPath: sources)]
        }

        for testFileURL in testFileURLs {
            try processFile(fileURL: testFileURL)
        }
    }

    private func processFile(fileURL: URL) throws {
        let file = try Syntax.parse(fileURL)

        let instrumentor = Instrumentor()
        _ = instrumentor.visit(file)

        let expressions = instrumentor.expressions
        var instruments = [SourceFileSyntax]()
        for expression in expressions {
            var os = ""
            print("", to: &os)
            print("do {", to: &os)
            let toStringFunc = """
                    func toString<T>(_ value: T?) -> String {
                        switch value {
                        case .some(let v): return \"\\(v)\"
                        case .none: return \"nil\"
                        }
                    }
                    """
            print(toStringFunc, to: &os)

            let recorder = ValueRecorder(tokens: expression.tokens)
            let expressionList = "\(expression.tokens.map { "\($0)"}.joined() )"

            let recordValues = """
            var values = [(Int, String)]()
            let condition = { () -> Bool in
            \(recorder.parse())
            return \(expressionList)
            }()
            """
            print(recordValues, to: &os)

            print("", to: &os)

            let alignFunc = """
                    func align(current: inout Int, column: Int, string: String) {
                        while current < column {
                            print(\" \", terminator: \"\")
                            current += 1
                        }
                        print(string, terminator: \"\")
                        current += string.count
                    }
                    """
            print("if !condition {", to: &os)
            print(alignFunc, to: &os)
            print("", to: &os)
            print("print(\"assert(\(expressionList.replacingOccurrences(of: "\"", with: "\\\"")))\")", to: &os)
            print("", to: &os)
            print("values.sort { $0.0 < $1.0 }", to: &os)
            print("", to: &os)
            print("var current = 0", to: &os)
            print("for value in values {", to: &os)
            print("    align(current: &current, column: value.0, string: \"|\")", to: &os)
            print("}", to: &os)
            print("    print()", to: &os)
            print("", to: &os)
            let printValuesStatement = """
                    while !values.isEmpty {
                        var current = 0
                        var index = 0
                        while index < values.count {
                            if index == values.count - 1 ||
                                values[index].0 + values[index].1.count < values[index + 1].0 {
                                align(current: &current, column: values[index].0, string: values[index].1)
                                values.remove(at: index)
                            } else {
                                align(current: &current, column: values[index].0, string: \"|\")
                                index += 1
                            }
                        }
                        print()
                    }
                    """
            print(printValuesStatement, to: &os)
            print("", to: &os)
            if !internalTest {
                print("XCTFail(\"'\" + \"assertion failed: \" + \"\(expressionList)\" + \"'\")", to: &os)
            }
            print("}", to: &os)
            print("}", to: &os)
            print("", to: &os)

            let tempDir = NSTemporaryDirectory() as NSString
            let tempFileUrl = URL(fileURLWithPath: tempDir.appendingPathComponent("swift-power-assert-\(UUID().uuidString).swift"))
            try os.write(to: tempFileUrl, atomically: true, encoding: .utf8)

            let instrument = try Syntax.parse(tempFileUrl)
            instruments.append(instrument)
        }

        let instrumeted = Injector(instruments: instruments).visit(file)

        var isDirectory: ObjCBool = false
        if let output = output, FileManager.default.fileExists(atPath: output, isDirectory: &isDirectory) && isDirectory.boolValue {
            try "\(instrumeted)".write(to: URL(fileURLWithPath: output).appendingPathComponent(fileURL.lastPathComponent), atomically: true, encoding: .utf8)
        } else {
            try "\(instrumeted)".write(to: fileURL, atomically: true, encoding: .utf8)
        }
    }
}

public extension SwiftPowerAssert {
    enum Error: Swift.Error {
        case missingFileName
        case noSuchFileOrDirectory
    }
}
