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
import SwiftPowerAssertCore

struct TestRunner {
    func run(source: String, identifier: String = #function) throws -> String {
        let temporaryDirectory = NSTemporaryDirectory()
        let sourceFilePath = (temporaryDirectory as NSString).appendingPathComponent("SwiftPowerAssertTests-\(identifier).swift")
        let executablePath = (sourceFilePath as NSString).deletingPathExtension + "o"

        try source.write(toFile: sourceFilePath, atomically: true, encoding: .utf8)

        let runner = SwiftPowerAssert(sources: sourceFilePath, output: temporaryDirectory, testable: true)
        try runner.run()

        let compile = Process()
        compile.launchPath = "/usr/bin/xcrun"
        compile.arguments = [
            "swiftc",
            "-O",
            "-whole-module-optimization",
            "-F/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/Library/Frameworks",
            "-Xlinker",
            "-rpath",
            "-Xlinker",
            "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/Library/Frameworks",
            sourceFilePath,
            "-o",
            executablePath
        ]
        compile.launch()
        compile.waitUntilExit()

        let exec = Process()
        exec.launchPath = executablePath
        let pipe = Pipe()
        exec.standardOutput = pipe
        exec.launch()

        let result = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)!
        print(result)

        return result
    }
}

class SwiftPowerAssertTests: XCTestCase {
    func testBinaryExpression1() throws {
        let source = """
            import XCTest

            struct Bar {
                var foo: Foo
                var val: Int
            }

            struct Foo {
                var val: Int
            }

            class Tests: XCTestCase {
                func testMethod() {
                    let bar = Bar(foo: Foo(val: 2), val: 3)
                    assert(bar.val == bar.foo.val)
                }
            }

            Tests().testMethod()
            """

        let expected = """
            assert(bar.val == bar.foo.val)
                   |   |   |  |   |   |
                   |   3   |  |   |   2
                   |       |  |   Foo(val: 2)
                   |       |  Bar(foo: main.Foo(val: 2), val: 3)
                   |       false
                   Bar(foo: main.Foo(val: 2), val: 3)

            """

        let result = try TestRunner().run(source: source)
        XCTAssertEqual(expected, result)
    }

    func testBinaryExpression2() throws {
        let source = """
            import XCTest

            struct Bar {
                var foo: Foo
                var val: Int
            }

            struct Foo {
                var val: Int
            }

            class Tests: XCTestCase {
                func testMethod() {
                    let bar = Bar(foo: Foo(val: 2), val: 3)
                    assert(bar.val < bar.foo.val)
                }
            }

            Tests().testMethod()
            """

        let expected = """
            assert(bar.val < bar.foo.val)
                   |   |   | |   |   |
                   |   3   | |   |   2
                   |       | |   Foo(val: 2)
                   |       | Bar(foo: main.Foo(val: 2), val: 3)
                   |       false
                   Bar(foo: main.Foo(val: 2), val: 3)

            """

        let result = try TestRunner().run(source: source)
        XCTAssertEqual(expected, result)
    }

    func testBinaryExpression3() throws {
        let source = """
            import XCTest

            class Tests: XCTestCase {
                func testMethod() {
                    let zero = 0
                    let one = 1
                    let two = 2
                    let three = 3

                    let array = [one, two, three]
                    assert(array.index(of: zero) == two)
                }
            }

            Tests().testMethod()
            """

        let expected = """
            assert(array.index(of: zero) == two)
                   |     |         |     |  |
                   |     nil       0     |  2
                   [1, 2, 3]             false

            """

        let result = try TestRunner().run(source: source)
        XCTAssertEqual(expected, result)
    }

    func testBinaryExpression4() throws {
        let source = """
            import XCTest

            class Tests: XCTestCase {
                func testMethod() {
                    let zero = 0
                    let one = 1
                    let two = 2
                    let three = 3

                    let array = [one, two, three]
                    assert(array.description.hasPrefix(\"[\") == false && array.description.hasPrefix(\"Hello\") == true)
                }
            }

            Tests().testMethod()
            """

        let expected = """
            assert(array.description.hasPrefix("[") == false && array.description.hasPrefix("Hello") == true)
                   |     |           |         |    |  |     |  |     |           |         |        |  |
                   |     [1, 2, 3]   true      [    |  false |  |     [1, 2, 3]   false     Hello    |  true
                   [1, 2, 3]                        false    |  [1, 2, 3]                            false
                                                             false

            """

        let result = try TestRunner().run(source: source)
        XCTAssertEqual(expected, result)
    }

    func testBinaryExpression5() throws {
        let source = """
            import XCTest

            struct Bar {
                var foo: Foo
                var val: Int
            }

            struct Foo {
                var val: Int
            }

            class Tests: XCTestCase {
                func testMethod() {
                    let zero = 0
                    let one = 1
                    let two = 2
                    let three = 3

                    let array = [one, two, three]

                    let bar = Bar(foo: Foo(val: 2), val: 3)
                    assert(array.index(of: zero) == two && bar.val == bar.foo.val)
                }
            }

            Tests().testMethod()
            """

        let expected = """
            assert(array.index(of: zero) == two && bar.val == bar.foo.val)
                   |     |         |     |  |   |  |   |   |  |   |   |
                   |     nil       0     |  2   |  |   3   |  |   |   2
                   [1, 2, 3]             false  |  |       |  |   Foo(val: 2)
                                                |  |       |  Bar(foo: main.Foo(val: 2), val: 3)
                                                |  |       false
                                                |  Bar(foo: main.Foo(val: 2), val: 3)
                                                false

            """

        let result = try TestRunner().run(source: source)
        XCTAssertEqual(expected, result)
    }

    func testBinaryExpression6() throws {
        let source = """
            import XCTest

            class Tests: XCTestCase {
                func testMethod() {
                    let zero = 0
                    let one = 1
                    let two = 2
                    let three = 3

                    let array = [one, two, three]
                    assert(array.distance(from: 2, to: 3) == 4)
                }
            }

            Tests().testMethod()
            """

        let expected = """
            assert(array.distance(from: 2, to: 3) == 4)
                   |     |              |      |  |  |
                   |     1              2      3  |  4
                   [1, 2, 3]                      false

            """

        let result = try TestRunner().run(source: source)
        XCTAssertEqual(expected, result)
    }

    func testBinaryExpression7() throws {
        let source = """
            import XCTest

            class Tests: XCTestCase {
                func testMethod() {
                    let zero = 0
                    let one = 1
                    let two = 2
                    let three = 3

                    let index = 1

                    let array = [one, two, three]
                    assert([one, two, three].count == 10)
                }
            }

            Tests().testMethod()
            """

        let expected = """
            assert([one, two, three].count == 10)
                    |    |    |      |     |  |
                    1    2    3      3     |  10
                                           false

            """

        let result = try TestRunner().run(source: source)
        XCTAssertEqual(expected, result)
    }

    func testBinaryExpression8() throws {
        let source = """
            import XCTest

            struct Object {
                let types: [Any?]
            }

            struct Person {
                let name: String
                let age: Int
            }

            class Tests: XCTestCase {
                func testMethod() {
                    let alice = Person(name: "alice", age: 3)
                    let bob = Person(name: "bob", age: 5)
                    let index = 7

                    let types: [Any?] = ["string", 98.6, true, false, nil, Double.nan, Double.infinity, alice]

                    let object = Object(types: types)

                    assert((object.types[index] as! Person).name == bob.name)
                }
            }

            Tests().testMethod()
            """

        let expected = """
            assert((object.types[index] as! Person).name == bob.name)
                    |      |     |                | |    |  |   |
                    |      |     7                | |    |  |   bob
                    |      |                      | |    |  Person(name: "bob", age: 5)
                    |      |                      | |    false
                    |      |                      | alice
                    |      |                      Person(name: "alice", age: 3)
                    |      Person(name: "alice", age: 3)
                    Object(types: [Optional("string"), Optional(98.599999999999994), Optional(true), Optional(false), nil, Optional(nan), Optional(inf), Optional(main.Person(name: "alice", age: 3))])

            """

        let result = try TestRunner().run(source: source)
        XCTAssertEqual(expected, result)
    }

    func testMultilineAssert() throws {
        let source = """
            import XCTest

            class Tests: XCTestCase {
                func testMethod() {
                    let zero = 0
                    let one = 1
                    let two = 2
                    let three = 3

                    let array = [one, two, three]
                    assert(array.distance(from: 2, to: 3)
                           == 4)
                }
            }

            Tests().testMethod()
            """

        let expected = """
            assert(array.distance(from: 2, to: 3) == 4)
                   |     |              |      |  |  |
                   |     1              2      3  |  4
                   [1, 2, 3]                      false

            """

        let result = try TestRunner().run(source: source)
        XCTAssertEqual(expected, result)
    }
}
