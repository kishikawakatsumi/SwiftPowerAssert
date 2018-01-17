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

import XCTest
import Basic
@testable import PowerAssertCore

class ParserTests: XCTestCase {
    func testParser() {
        let env = TestEnvironments()

        let source = """
            import class Foundation.NSArray
            import class Foundation.NSDictionary
            import XCTest

            protocol Testable {}
            extension Testable {
                func testInt() {
                    let i = 0
                    let j = 1
                    let k = 2
                    XCTAssertEqual(i, j)
                }
                func testInt32() {
                    let i = 0
                    let j = 1
                    let k = 2
                    XCTAssertEqual(i, j)
                }
                func testInt64() {
                    let i = 0
                    let j = 1
                    let k = 2
                    XCTAssertEqual(i, j)
                }
            }

            private extension XCTestCase: Testable {
                let a = "a"
                let b = "b"
                let c = "c"

                private func testString() {
                    let d = "d"
                    let f = "f"
                    XCTAssertEqual(a, b)
                    XCTAssertEqual(c, d)
                }
            }

            private struct Helper<T>: Testable {
                func generateData() -> [String] {
                    return ["a", "b", "c"]
                }
            }

            public class Tests: XCTestCase, Testable {
                func test1() {
                    let a = "a"
                    let b = "b"
                    let c = "c"
                    let d = "d"
                    XCTAssertEqual(a, b)
                    XCTAssertEqual(c, d)
                }
                func test2() {
                    let a = "a"
                    let b = "b"
                    XCTAssertEqual(a, b)
                }
            }

            func test() {}

            enum TestSuite {
                case target(String)
                case bundle

                func test() {
                    let a = "a"
                    let b = "b"
                    let c = "c"
                    let d = "d"
                    XCTAssertEqual(a, b)
                    XCTAssertEqual(c, d)
                }
            }

            """

        try! source.write(toFile: env.sourceFilePath, atomically: true, encoding: .utf8)

        let arguments = [
            "/usr/bin/xcrun",
            "swift",
            "-frontend",
            "-parse-as-library",
            "-dump-ast"
        ] + env.parseOptions + ["-primary-file", env.sourceFilePath]

        let process = Process(arguments: arguments)
        try! process.launch()
        let result = try! process.waitUntilExit()
        let rawAST = try! result.utf8stderrOutput()

        let tokenizer = ASTTokenizer()
        let tokens = tokenizer.tokenize(source: rawAST)

        let lexer = ASTLexer()
        let node = lexer.lex(tokens: tokens)

        let parser = ASTParser()
        let root = parser.parse(root: node)

        if case .import(let declaration) = root.declarations[0] {
            XCTAssertEqual(declaration.importKind, "class")
            XCTAssertEqual(declaration.importPath, "Foundation.NSArray")
        } else {
            XCTFail()
        }
        if case .import(let declaration) = root.declarations[1] {
            XCTAssertEqual(declaration.importKind, "class")
            XCTAssertEqual(declaration.importPath, "Foundation.NSDictionary")
        } else {
            XCTFail()
        }
        if case .import(let declaration) = root.declarations[2] {
            XCTAssertNil(declaration.importKind)
            XCTAssertEqual(declaration.importPath, "XCTest")
        } else {
            XCTFail()
        }

        if case .extension(let declaration) = root.declarations[3] {
            XCTAssertEqual(declaration.accessLevel, "internal")
            XCTAssertEqual(declaration.name, "Testable")
            XCTAssertNil(declaration.typeInheritance)

            XCTAssertEqual(declaration.members.count, 3)
            if case .declaration(let declaration) = declaration.members[0] {
                if case .function(let declaration) = declaration {
                    XCTAssertEqual(declaration.accessLevel, "internal")
                    XCTAssertEqual(declaration.name, "testInt()")
                } else {
                    XCTFail()
                }
            } else {
                XCTFail()
            }
            if case .declaration(let declaration) = declaration.members[1] {
                if case .function(let declaration) = declaration {
                    XCTAssertEqual(declaration.accessLevel, "internal")
                    XCTAssertEqual(declaration.name, "testInt32()")
                } else {
                    XCTFail()
                }
            } else {
                XCTFail()
            }
            if case .declaration(let declaration) = declaration.members[2] {
                if case .function(let declaration) = declaration {
                    XCTAssertEqual(declaration.accessLevel, "internal")
                    XCTAssertEqual(declaration.name, "testInt64()")
                } else {
                    XCTFail()
                }
            } else {
                XCTFail()
            }
        } else {
            XCTFail()
        }

        if case .extension(let declaration) = root.declarations[4] {
            XCTAssertEqual(declaration.accessLevel, "internal")
            XCTAssertEqual(declaration.name, "XCTestCase")
            XCTAssertEqual(declaration.typeInheritance, "Testable")

            XCTAssertEqual(declaration.members.count, 1)
            if case .declaration(let declaration) = declaration.members[0] {
                if case .function(let declaration) = declaration {
                    XCTAssertEqual(declaration.accessLevel, "private")
                    XCTAssertEqual(declaration.name, "testString()")
                } else {
                    XCTFail()
                }
            } else {
                XCTFail()
            }
        } else {
            XCTFail()
        }

        if case .struct(let declaration) = root.declarations[5] {
            XCTAssertEqual(declaration.accessLevel, "private")
            XCTAssertEqual(declaration.name, "Helper")
            XCTAssertEqual(declaration.typeInheritance, "Testable")

            XCTAssertEqual(declaration.members.count, 1)
            if case .declaration(let declaration) = declaration.members[0] {
                if case .function(let declaration) = declaration {
                    XCTAssertEqual(declaration.accessLevel, "internal")
                    XCTAssertEqual(declaration.name, "generateData()")
                } else {
                    XCTFail()
                }
            } else {
                XCTFail()
            }
        } else {
            XCTFail()
        }

        if case .class(let declaration) = root.declarations[6] {
            XCTAssertEqual(declaration.accessLevel, "public")
            XCTAssertEqual(declaration.name, "Tests")
            XCTAssertEqual(declaration.typeInheritance, "XCTestCase, Testable")

            XCTAssertEqual(declaration.members.count, 2)
            if case .declaration(let declaration) = declaration.members[0] {
                if case .function(let declaration) = declaration {
                    XCTAssertEqual(declaration.accessLevel, "internal")
                    XCTAssertEqual(declaration.name, "test1()")
                } else {
                    XCTFail()
                }
            } else {
                XCTFail()
            }
            if case .declaration(let declaration) = declaration.members[1] {
                if case .function(let declaration) = declaration {
                    XCTAssertEqual(declaration.accessLevel, "internal")
                    XCTAssertEqual(declaration.name, "test2()")
                } else {
                    XCTFail()
                }
            } else {
                XCTFail()
            }
        } else {
            XCTFail()
        }

        if case .function(let declaration) = root.declarations[7] {
            XCTAssertEqual(declaration.accessLevel, "internal")
            XCTAssertEqual(declaration.name, "test()")
        } else {
            XCTFail()
        }

        if case .enum(let declaration) = root.declarations[8] {
            XCTAssertEqual(declaration.accessLevel, "internal")
            XCTAssertEqual(declaration.name, "TestSuite")
            XCTAssertNil(declaration.typeInheritance)

            XCTAssertEqual(declaration.members.count, 1)
            if case .declaration(let declaration) = declaration.members[0] {
                if case .function(let declaration) = declaration {
                    XCTAssertEqual(declaration.accessLevel, "internal")
                    XCTAssertEqual(declaration.name, "test()")
                } else {
                    XCTFail()
                }
            } else {
                XCTFail()
            }
        } else {
            XCTFail()
        }
    }
}
