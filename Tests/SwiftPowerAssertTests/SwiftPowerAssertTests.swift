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
import SwiftPowerAssertCore

struct TestRunner {
    func run(source: String, options: Options = Options(), identifier: String = #function) throws -> String {
        let temporaryDirectory = try TemporaryDirectory(prefix: "com.kishikawakatsumi.swift-power-assert", removeTreeOnDeinit: true)
        let temporaryFile = try TemporaryFile(dir: temporaryDirectory.path, prefix: "test", suffix: ".swift")

        let sourceFilePath = temporaryFile.path.asString
        let executablePath = sourceFilePath + ".o"

        try source.write(toFile: sourceFilePath, atomically: true, encoding: .utf8)

        let runner = SwiftPowerAssert(sources: sourceFilePath, output: temporaryDirectory.path.asString, options: options)
        try runner.run()

        let sdk = options.sdk
        let sdkPath = sdk.path
        let target = "\(options.arch)-apple-\(options.sdk)\(options.deploymentTarget)"

        let compile = Process()
        compile.launchPath = "/usr/bin/xcrun"
        compile.arguments = [
            "swiftc",
            "-O",
            "-whole-module-optimization",
            sourceFilePath,
            "-o",
            executablePath,
            "-target",
            target,
            "-sdk",
            sdkPath,
            "-F",
            "\(sdkPath)/../../../Developer/Library/Frameworks",
            "-Xlinker",
            "-rpath",
            "-Xlinker",
            "\(sdkPath)/../../../Developer/Library/Frameworks",
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
                let foo: Foo
                var val: Int
            }

            struct Foo {
                var val: Int
            }

            class Tests: XCTestCase {
                @objc dynamic func testMethod() {
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
                    |      |     |    |             |    |  |   |
                    |      |     7    |             |    |  |   bob
                    |      |          |             |    |  Person(name: "bob", age: 5)
                    |      |          |             |    false
                    |      |          |             alice
                    |      |          Person(name: "alice", age: 3)
                    |      [Optional("string"), Optional(98.599999999999994), Optional(true), Optional(false), nil, Optional(nan), Optional(inf), Optional(main.Person(name: "alice", age: 3))]
                    Object(types: [Optional("string"), Optional(98.599999999999994), Optional(true), Optional(false), nil, Optional(nan), Optional(inf), Optional(main.Person(name: "alice", age: 3))])

            """

        let result = try TestRunner().run(source: source)
        XCTAssertEqual(expected, result)
    }

    func testMultilineExpression1() throws {
        let source = """
            import XCTest

            struct Bar {
                let foo: Foo
                var val: Int
            }

            struct Foo {
                var val: Int
            }

            class Tests: XCTestCase {
                @objc dynamic func testMethod() {
                    let bar = Bar(foo: Foo(val: 2), val: 3)
                    assert(bar.val == bar.foo.val)
                    assert(bar
                        .val ==
                        bar.foo.val)
                    assert(bar
                        .val ==
                        bar
                            .foo        .val)
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
            assert(bar .val == bar.foo.val)
                   |    |   |  |   |   |
                   |    3   |  |   |   2
                   |        |  |   Foo(val: 2)
                   |        |  Bar(foo: main.Foo(val: 2), val: 3)
                   |        false
                   Bar(foo: main.Foo(val: 2), val: 3)
            assert(bar .val == bar .foo        .val)
                   |    |   |  |    |           |
                   |    3   |  |    Foo(val: 2) 2
                   |        |  Bar(foo: main.Foo(val: 2), val: 3)
                   |        false
                   Bar(foo: main.Foo(val: 2), val: 3)

            """

        let result = try TestRunner().run(source: source)
        XCTAssertEqual(expected, result)
    }

    func testMultilineExpression2() throws {
        let source = """
            import XCTest

            class Tests: XCTestCase {
                @objc dynamic func testMethod() {
                    let zero = 0
                    let one = 1
                    let two = 2
                    let three = 3
                    let array = [one, two, three]

                    assert(array    .        index(
                        of:    zero)
                        == two
                    )

                    assert(array
                        .
                        index(

                            of:
                            zero)
                        == two
                    )

                    assert(array
                        .index(
                            of:
                            zero)
                        == two
                    )
                }
            }

            Tests().testMethod()
            """

        let expected = """
            assert(array    .        index( of:    zero) == two )
                   |                 |             |     |  |
                   [1, 2, 3]         nil           0     |  2
                                                         false
            assert(array . index(  of: zero) == two )
                   |       |           |     |  |
                   |       nil         0     |  2
                   [1, 2, 3]                 false
            assert(array .index( of: zero) == two )
                   |      |          |     |  |
                   |      nil        0     |  2
                   [1, 2, 3]               false

            """

        let result = try TestRunner().run(source: source)
        XCTAssertEqual(expected, result)
    }

    func testMultilineExpression3() throws {
        let source = """
            import XCTest

            class Tests: XCTestCase {
                func testMethod() {
                    let zero = 0
                    let one = 1
                    let two = 2
                    let three = 3

                    let array = [one, two, three]
                    assert(array
                        .description
                        .hasPrefix(    \"[\"
                        )
                        == false && array
                            .description
                            .hasPrefix    (\"Hello\"    ) ==
                        true)
                }
            }

            Tests().testMethod()
            """

        let expected = """
            assert(array .description .hasPrefix(    "[" ) == false && array .description .hasPrefix    ("Hello"    ) == true)
                   |      |            |             |     |  |     |  |      |            |             |            |  |
                   |      [1, 2, 3]    true          [     |  false |  |      [1, 2, 3]    false         Hello        |  true
                   [1, 2, 3]                               false    |  [1, 2, 3]                                      false
                                                                    false

            """

        let result = try TestRunner().run(source: source)
        XCTAssertEqual(expected, result)
    }

    func testMultilineExpression4() throws {
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

                    assert(

                        array.index(
                            of: zero
                            )
                            ==
                            two
                            &&
                            bar
                                .val
                            == bar
                                .foo
                                .val
                    )
                }
            }

            Tests().testMethod()
            """

        let expected = """
            assert(  array.index( of: zero ) == two && bar .val == bar .foo .val )
                     |     |          |      |  |   |  |    |   |  |    |    |
                     |     nil        0      |  2   |  |    3   |  |    |    2
                     [1, 2, 3]               false  |  |        |  |    Foo(val: 2)
                                                    |  |        |  Bar(foo: main.Foo(val: 2), val: 3)
                                                    |  |        false
                                                    |  Bar(foo: main.Foo(val: 2), val: 3)
                                                    false

            """

        let result = try TestRunner().run(source: source)
        XCTAssertEqual(expected, result)
    }

    func testMultilineExpression5() throws {
        let source = """
            import XCTest

            class Tests: XCTestCase {
                func testMethod() {
                    let zero = 0
                    let one = 1
                    let two = 2
                    let three = 3

                    let array = [one, two, three]
                    assert(

                        array
                            .distance(
                                from: 2,
                                to: 3)
                            == 4)
                }
            }

            Tests().testMethod()
            """

        let expected = """
            assert(  array .distance( from: 2, to: 3) == 4)
                     |      |               |      |  |  |
                     |      1               2      3  |  4
                     [1, 2, 3]                        false

            """

        let result = try TestRunner().run(source: source)
        XCTAssertEqual(expected, result)
    }

    func testMultilineExpression6() throws {
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

                    assert([one,
                            two
                        , three]
                        .count
                        == 10)
                }
            }

            Tests().testMethod()
            """

        let expected = """
            assert([one, two , three] .count == 10)
                    |    |     |       |     |  |
                    1    2     3       3     |  10
                                             false

            """

        let result = try TestRunner().run(source: source)
        XCTAssertEqual(expected, result)
    }

    func testTryExpression() throws {
        let source = """
            import XCTest

            struct Coordinate: Codable {
                var latitude: Double
                var longitude: Double
            }

            struct Landmark: Codable {
                var name: String
                var foundingYear: Int
                var location: Coordinate
            }

            class Tests: XCTestCase {
                @objc dynamic func testMethod() {
                    let landmark = Landmark(name: \"Tokyo Tower\",
                                            foundingYear: 1957,
                                            location: Coordinate(latitude: 35.658581, longitude: 139.745438))
                    assert(try! JSONEncoder().encode(landmark) ==
                        "{ name: \\"Tokyo Tower\\" }".data(using: String.Encoding.utf8))
                    assert(try! JSONEncoder().encode(landmark) ==
                        "{ name: \\"Tokyo Tower\\" }".data(using: .utf8))
                    assert(try! "{ name: \\"Tokyo Tower\\" }".data(using: String.Encoding.utf8) ==
                        JSONEncoder().encode(landmark))
                }
            }

            Tests().testMethod()
            """

        let expected = """
            assert(try! JSONEncoder().encode(landmark) == "{ name: \\"Tokyo Tower\\" }".data(using: String.Encoding.utf8))
                        |             |      |         |  |                           |                           |
                        |             |      |         |  { name: "Tokyo Tower" }     23 bytes                    Unicode (UTF-8)
                        |             |      |         false
                        |             |      Landmark(name: "Tokyo Tower", foundingYear: 1957, location: main.Coordinate(latitude: 35.658580999999998, longitude: 139.74543800000001))
                        |             99 bytes
                        Foundation.JSONEncoder
            assert(try! JSONEncoder().encode(landmark) == "{ name: \\"Tokyo Tower\\" }".data(using: .utf8))
                        |             |      |         |  |                           |            |
                        |             |      |         |  { name: "Tokyo Tower" }     23 bytes     Unicode (UTF-8)
                        |             |      |         false
                        |             |      Landmark(name: "Tokyo Tower", foundingYear: 1957, location: main.Coordinate(latitude: 35.658580999999998, longitude: 139.74543800000001))
                        |             99 bytes
                        Foundation.JSONEncoder
            assert(try! "{ name: \\"Tokyo Tower\\" }".data(using: String.Encoding.utf8) == JSONEncoder().encode(landmark))
                        |                           |                           |     |  |             |      |
                        { name: "Tokyo Tower" }     23 bytes                    |     |  |             |      Landmark(name: "Tokyo Tower", foundingYear: 1957, location: main.Coordinate(latitude: 35.658580999999998, longitude: 139.74543800000001))
                                                                                |     |  |             99 bytes
                                                                                |     |  Foundation.JSONEncoder
                                                                                |     false
                                                                                Unicode (UTF-8)

            """

        let result = try TestRunner().run(source: source)
        XCTAssertEqual(expected, result)
    }
}
