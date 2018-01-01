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

private class TestRunner {
    private lazy var temporaryDirectory = {
        return try! TemporaryDirectory(prefix: "com.kishikawakatsumi.swift-power-assert", removeTreeOnDeinit: true)
    }()
    private lazy var temporaryFile = {
        return try! TemporaryFile(dir: temporaryDirectory.path, prefix: "Tests", suffix: ".swift").path
    }()
    private lazy var sourceFilePath = {
        return temporaryFile.asString
    }()
    private lazy var utilitiesFilePath = {
        return temporaryDirectory.path.appending(component: "Utilities.swift").asString
    }()
    private lazy var mainFilePath = {
        return temporaryDirectory.path.appending(component: "main.swift").asString
    }()
    private lazy var executablePath = {
        return sourceFilePath + ".o"
    }()
    private lazy var options: BuildOptions = {
        let sdk = SDK.macosx
        let sdkPath = sdk.path()
        let sdkVersion = sdk.version()
        return BuildOptions(sdkName: sdk.name + sdkVersion, sdkRoot: sdkPath,
                            platformName: sdk.name, platformTargetPrefix: sdk.os,
                            arch: "x86_64", deploymentTarget: sdkVersion,
                            dependencies: [], buildDirectory: temporaryDirectory.path.asString)
    }()

    func run(source: String) -> String {
        prepare(source: source)
        compile()

        let result = execute()
        print(result)

        return result
    }

    private func prepare(source: String) {
        try! source.write(toFile: sourceFilePath, atomically: true, encoding: .utf8)
        let processor = SwiftPowerAssert(buildOptions: options)
        do {
            let transformed = try processor.processFile(input: URL(fileURLWithPath: sourceFilePath))
            try! transformed.write(toFile: sourceFilePath, atomically: true, encoding: .utf8)
        } catch {
            fatalError("failed to instrument assertions")
        }

        try! __DisplayWidth.myself.write(toFile: utilitiesFilePath, atomically: true, encoding: .utf8)
        let main = """
            Tests().testMethod()

            """
        try! main.write(toFile: mainFilePath, atomically: true, encoding: .utf8)
    }

    private func compile() {
        let arguments = [
            "/usr/bin/xcrun",
            "swiftc",
            "-O",
            "-whole-module-optimization",
            sourceFilePath,
            utilitiesFilePath,
            mainFilePath,
            "-o",
            executablePath,
            "-target",
            options.targetTriple,
            "-sdk",
            options.sdkRoot,
            "-F",
            "\(options.sdkRoot)/../../../Developer/Library/Frameworks",
            "-Xlinker",
            "-rpath",
            "-Xlinker",
            "\(options.sdkRoot)/../../../Developer/Library/Frameworks",
        ]

        let process = Process(arguments: arguments)
        try! process.launch()
        let result = try! process.waitUntilExit()
        if case .terminated(let code) = result.exitStatus, code != 0 {
            print(try! result.utf8stderrOutput())
            fatalError("failed to compile an instrumented file")
        }
    }

    private func execute() -> String {
        let process = Process(arguments: [executablePath])
        try! process.launch()

        let result = try! process.waitUntilExit()
        switch result.exitStatus {
        case .terminated(let code) where code != 0:
            print(try! result.utf8stderrOutput())
            fatalError("abort")
        case .signalled(_):
            print(try! result.utf8stderrOutput())
            fatalError("abort")
        default:
            break
        }

        return try! result.utf8Output()
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

        let result = TestRunner().run(source: source)
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

        let result = TestRunner().run(source: source)
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

            """

        let expected = """
            assert(array.index(of: zero) == two)
                   |     |         |     |  |
                   |     nil       0     |  2
                   [1, 2, 3]             false

            """

        let result = TestRunner().run(source: source)
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
                    assert(array.description.hasPrefix("[") == false && array.description.hasPrefix("Hello") == true)
                }
            }

            """

        let expected = """
            assert(array.description.hasPrefix("[") == false && array.description.hasPrefix("Hello") == true)
                   |     |           |         |    |  |     |  |     |           |         |        |  |
                   |     "[1, 2, 3]" true      "["  |  false |  |     "[1, 2, 3]" false     "Hello"  |  true
                   [1, 2, 3]                        false    |  [1, 2, 3]                            false
                                                             false

            """

        let result = TestRunner().run(source: source)
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

        let result = TestRunner().run(source: source)
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

            """

        let expected = """
            assert(array.distance(from: 2, to: 3) == 4)
                   |     |              |      |  |  |
                   |     1              2      3  |  4
                   [1, 2, 3]                      false

            """

        let result = TestRunner().run(source: source)
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

            """

        let expected = """
            assert([one, two, three].count == 10)
                   ||    |    |      |     |  |
                   |1    2    3      3     |  10
                   [1, 2, 3]               false

            """

        let result = TestRunner().run(source: source)
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

            """

        let expected = """
            assert((object.types[index] as! Person).name == bob.name)
                    |      |     |    |             |    |  |   |
                    |      |     7    |             |    |  |   "bob"
                    |      |          |             |    |  Person(name: "bob", age: 5)
                    |      |          |             |    false
                    |      |          |             "alice"
                    |      |          Person(name: "alice", age: 3)
                    |      [Optional("string"), Optional(98.599999999999994), Optional(true), Optional(false), nil, Optional(nan), Optional(inf), Optional(main.Person(name: "alice", age: 3))]
                    Object(types: [Optional("string"), Optional(98.599999999999994), Optional(true), Optional(false), nil, Optional(nan), Optional(inf), Optional(main.Person(name: "alice", age: 3))])

            """

        let result = TestRunner().run(source: source)
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

        let result = TestRunner().run(source: source)
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

        let result = TestRunner().run(source: source)
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
                        .hasPrefix(    "["
                        )
                        == false && array
                            .description
                            .hasPrefix    ("Hello"    ) ==
                        true)
                }
            }

            """

        let expected = """
            assert(array .description .hasPrefix(    "[" ) == false && array .description .hasPrefix    ("Hello"    ) == true)
                   |      |            |             |     |  |     |  |      |            |             |            |  |
                   |      "[1, 2, 3]"  true          "["   |  false |  |      "[1, 2, 3]"  false         "Hello"      |  true
                   [1, 2, 3]                               false    |  [1, 2, 3]                                      false
                                                                    false

            """

        let result = TestRunner().run(source: source)
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

        let result = TestRunner().run(source: source)
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

            """

        let expected = """
            assert(  array .distance( from: 2, to: 3) == 4)
                     |      |               |      |  |  |
                     |      1               2      3  |  4
                     [1, 2, 3]                        false

            """

        let result = TestRunner().run(source: source)
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

            """

        let expected = """
            assert([one, two , three] .count == 10)
                   ||    |     |       |     |  |
                   |1    2     3       3     |  10
                   [1, 2, 3]                 false

            """

        let result = TestRunner().run(source: source)
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
                    let landmark = Landmark(name: "Tokyo Tower",
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

            """

        let expected = """
            assert(try! JSONEncoder().encode(landmark) == "{ name: \\"Tokyo Tower\\" }".data(using: String.Encoding.utf8))
                        |             |      |         |  |                           |                           |
                        |             |      |         |  "{ name: "Tokyo Tower" }"   23 bytes                    Unicode (UTF-8)
                        |             |      |         false
                        |             |      Landmark(name: "Tokyo Tower", foundingYear: 1957, location: main.Coordinate(latitude: 35.658580999999998, longitude: 139.74543800000001))
                        |             99 bytes
                        Foundation.JSONEncoder
            assert(try! JSONEncoder().encode(landmark) == "{ name: \\"Tokyo Tower\\" }".data(using: .utf8))
                        |             |      |         |  |                           |            |
                        |             |      |         |  "{ name: "Tokyo Tower" }"   23 bytes     Unicode (UTF-8)
                        |             |      |         false
                        |             |      Landmark(name: "Tokyo Tower", foundingYear: 1957, location: main.Coordinate(latitude: 35.658580999999998, longitude: 139.74543800000001))
                        |             99 bytes
                        Foundation.JSONEncoder
            assert(try! "{ name: \\"Tokyo Tower\\" }".data(using: String.Encoding.utf8) == JSONEncoder().encode(landmark))
                        |                           |                           |     |  |             |      |
                        "{ name: "Tokyo Tower" }"   23 bytes                    |     |  |             |      Landmark(name: "Tokyo Tower", foundingYear: 1957, location: main.Coordinate(latitude: 35.658580999999998, longitude: 139.74543800000001))
                                                                                |     |  |             99 bytes
                                                                                |     |  Foundation.JSONEncoder
                                                                                |     false
                                                                                Unicode (UTF-8)

            """

        let result = TestRunner().run(source: source)
        XCTAssertEqual(expected, result)
    }

    func testNilLiteral() throws {
        let source = """
            import XCTest

            class Tests: XCTestCase {
                func testMethod() {
                    let string = "1234"
                    let number = Int(string)
                    assert(number != nil && number == 1111)
                }
            }

            """

        let expected = """
            assert(number != nil && number == 1111)
                   |      |  |   |  |      |  |
                   1234   |  nil |  1234   |  1111
                          true   false     false

            """

        let result = TestRunner().run(source: source)
        XCTAssertEqual(expected, result)
    }

    func testTernaryConditionalOperator() throws {
        let source = """
            import XCTest

            class Tests: XCTestCase {
                func testMethod() {
                    let string = "1234"
                    let number = Int(string)
                    let hello = "hello"
                    assert((number != nil ? string : "hello") == hello)
                }
            }

            """

        let expected = """
            assert((number != nil ? string : "hello") == hello)
                    |      |  |   | |        |        |  |
                    1234   |  nil | "1234"   "hello"  |  "hello"
                           true   "1234"              false

            """

        let result = TestRunner().run(source: source)
        XCTAssertEqual(expected, result)
    }

    func testArrayLiteralExpression() throws {
        let source = """
            import XCTest

            class Tests: XCTestCase {
                func testMethod() {
                    let zero = 0
                    let one = 1
                    let two = 2
                    let three = 3

                    assert([one, two, three].index(of: zero) == two)
                }
            }

            """

        let expected = """
            assert([one, two, three].index(of: zero) == two)
                   ||    |    |      |         |     |  |
                   |1    2    3      nil       0     |  2
                   [1, 2, 3]                         false

            """

        let result = TestRunner().run(source: source)
        XCTAssertEqual(expected, result)
    }

    func testDictionaryLiteralExpression() throws {
        let source = """
            import XCTest

            class Tests: XCTestCase {
                func testMethod() {
                    let zero = 0
                    let one = 1
                    let two = 2
                    let three = 3

                    assert([zero: one, two: three].count == three)
                }
            }

            """

        let expected = """
            assert([zero: one, two: three].count == three)
                   ||     |    |    |      |     |  |
                   |0     1    2    3      2     |  3
                   [2: 3, 0: 1]                  false

            """

        let result = TestRunner().run(source: source)
        XCTAssertEqual(expected, result)
    }

    func testMagicLiteralExpression() throws {
        let source = """
            import XCTest

            class Tests: XCTestCase {
                func testMethod() {
                    assert(#file == "*.swift" && #line == 1 && #column == 2 && #function == "function")
                    assert(#colorLiteral(red: 0.8078431487, green: 0.02745098062, blue: 0.3333333433, alpha: 1) == .blue &&
                           .blue == #colorLiteral(red: 0.8078431487, green: 0.02745098062, blue: 0.3333333433, alpha: 1))
                }
            }

            """
        // FIXME: `#line` shouldn't be changed due to instrument code
        let expected = """
            assert(#file == "*.swift" && #line == 1 && #column == 2 && #function == "function")
                   |     |  |         |  |     |  | |  |       |  | |  |         |  |
                   |     |  "*.swift" |  81    |  1 |  34      |  2 |  |         |  "function"
                   |     false        false    |    false      |    |  |         false
                   |                           false           |    |  "testMethod()"
                   |                                           |    false
                   |                                           false
                   "/var/folders/pk/pqq01lrx7qz335ft5_1xb7m40000gn/T/com.kishikawakatsumi.swift-power-assert.wJW1Qh/test.LaZw7q.swift"
            assert(#colorLiteral(red: 0.8078431487, green: 0.02745098062, blue: 0.3333333433, alpha: 1) == .blue && .blue == #colorLiteral(red: 0.8078431487, green: 0.02745098062, blue: 0.3333333433, alpha: 1))
                   |                  |                    |                    |                    |  |   |    |   |    |  |                  |                    |                    |                    |
                   |                  0                    0                    0                    1  |   |    |   |    |  |                  0                    0                    0                    1
                   NSCustomColorSpace sRGB IEC61966-2.1 colorspace 0.807843 0.027451 0.333333 1         |   |    |   |    |  NSCustomColorSpace sRGB IEC61966-2.1 colorspace 0.807843 0.027451 0.333333 1
                                                                                                        |   |    |   |    false
                                                                                                        |   |    |   NSCalibratedRGBColorSpace 0 0 1 1
                                                                                                        |   |    false
                                                                                                        |   NSCalibratedRGBColorSpace 0 0 1 1
                                                                                                        false

            """

        let result = TestRunner().run(source: source)
        XCTAssertEqual(expected.replacingOccurrences(of: "/.+\\.swift", with: "", options: .regularExpression),
                       result.replacingOccurrences(of: "/.+\\.swift", with: "", options: .regularExpression))
    }

    func testSelfExpression() throws {
        func toStr<T>(value: T?) -> String {
            switch value {
            case .some(let value):
                return "\(value)"
            case .none:
                return "nil"
            }
        }

        let source = """
            import XCTest

            class Tests: XCTestCase {
                let stringValue = "string"
                let intValue = 100
                let doubleValue = 999.9

                func testMethod() {
                    assert(self.stringValue == "string" && self.intValue == 100 && self.doubleValue == 0.1)
                    assert(super.continueAfterFailure == false)
                }
            }

            """

        let expected = """
            assert(self.stringValue == "string" && self.intValue == 100 && self.doubleValue == 0.1)
                   |    |           |  |        |  |    |        |  |   |  |    |           |  |
                   |    "string"    |  "string" |  |    100      |  100 |  |    999.9       |  0
                   -[Tests (null)]  true        |  |             true   |  -[Tests (null)]  false
                                                |  -[Tests (null)]      false
                                                true
            assert(super.continueAfterFailure == false)
                         |                    |  |
                         true                 |  false
                                              false

            """

        let result = TestRunner().run(source: source)
        XCTAssertEqual(expected, result)
    }

    func testImplicitMemberExpression() throws {
        let source = """
            import XCTest

            class Tests: XCTestCase {
                func testMethod() {
                    let i = 16
                    assert(i == .bitWidth && i == Double.Exponent.bitWidth)

                    let mask: CAAutoresizingMask = [.layerMaxXMargin, .layerMaxYMargin]
                    assert(mask != [.layerMaxXMargin, .layerMaxYMargin])
                }
            }

            """

        let expected = """
            assert(i == .bitWidth && i == Double.Exponent.bitWidth)
                   | |   |        |  | |                  |
                   | |   64       |  | false              64
                   | false        |  16
                   16             false
            assert(mask != [.layerMaxXMargin, .layerMaxYMargin])
                   |    |  | |                 |
                   |    |  | |                 CAAutoresizingMask(rawValue: 32)
                   |    |  | CAAutoresizingMask(rawValue: 4)
                   |    |  CAAutoresizingMask(rawValue: 36)
                   |    false
                   CAAutoresizingMask(rawValue: 36)

            """

        let result = TestRunner().run(source: source)
        XCTAssertEqual(expected, result)
    }

    func testTupleExpression() throws {
        let source = """
            import XCTest

            class Tests: XCTestCase {
                func testMethod() {
                    let dc1 = DateComponents(calendar: Calendar(identifier: .gregorian), timeZone: TimeZone(abbreviation: "JST")!, year: 1980, month: 10, day: 28)
                    let date1 = dc1.date!
                    let dc2 = DateComponents(calendar: Calendar(identifier: .gregorian), timeZone: TimeZone(abbreviation: "JST")!, year: 2000, month: 12, day: 31)
                    let date2 = dc2.date!

                    let tuple = (name: "Katsumi", age: 37, birthday: date1)

                    assert(tuple == (name: "Katsumi", age: 37, birthday: date2))
                    assert(tuple == ("Katsumi", 37, date2))
                    assert(tuple.name != ("Katsumi", 37, date2).0 || tuple.age != ("Katsumi", 37, date2).1)
                }
            }

            """

        let expected = """
            assert(tuple == (name: "Katsumi", age: 37, birthday: date2))
                   |     |         |               |             |
                   |     false     "Katsumi"       37            2000-12-30 15:00:00 +0000
                   (name: "Katsumi", age: 37, birthday: 1980-10-27 15:00:00 +0000)
            assert(tuple == ("Katsumi", 37, date2))
                   |     |   |          |   |
                   |     |   "Katsumi"  37  2000-12-30 15:00:00 +0000
                   |     false
                   (name: "Katsumi", age: 37, birthday: 1980-10-27 15:00:00 +0000)
            assert(tuple.name != ("Katsumi", 37, date2).0 || tuple.age != ("Katsumi", 37, date2).1)
                   |     |    |   |          |   |      | |  |     |   |   |          |   |      |
                   |     |    |   "Katsumi"  37  |      | |  |     37  |   "Katsumi"  37  |      37
                   |     |    false              |      | |  |         false              2000-12-30 15:00:00 +0000
                   |     "Katsumi"               |      | |  (name: "Katsumi", age: 37, birthday: 1980-10-27 15:00:00 +0000)
                   |                             |      | false
                   |                             |      "Katsumi"
                   |                             2000-12-30 15:00:00 +0000
                   (name: "Katsumi", age: 37, birthday: 1980-10-27 15:00:00 +0000)

            """

        let result = TestRunner().run(source: source)
        XCTAssertEqual(expected, result)
    }

    func testKeyPathExpression() throws {
        let source = """
            import XCTest

            struct SomeStructure {
                var someValue: Int

                func getValue(keyPath: KeyPath<SomeStructure, Int>) -> Int {
                    return self[keyPath: keyPath]
                }
            }

            struct OuterStructure {
                var outer: SomeStructure

                init(someValue: Int) {
                    self.outer = SomeStructure(someValue: someValue)
                }

                func getValue(keyPath: KeyPath<OuterStructure, Int>) -> Int {
                    return self[keyPath: keyPath]
                }
            }

            class Tests: XCTestCase {
                func testMethod() {
                    let s = SomeStructure(someValue: 12)
                    let pathToProperty = \\SomeStructure.someValue

                    assert(s[keyPath: pathToProperty] == 13)
                    assert(s[keyPath: \\SomeStructure.someValue] == 13)
                    assert(s.getValue(keyPath: \\.someValue) == 13)

                    let nested = OuterStructure(someValue: 24)
                    let nestedKeyPath = \\OuterStructure.outer.someValue

                    assert(nested[keyPath: nestedKeyPath] == 13)
                    assert(nested[keyPath: \\OuterStructure.outer.someValue] == 13)
                    assert(nested.getValue(keyPath: \\.outer.someValue) == 13)

                    let greetings = ["hello", "hola", "bonjour", "안녕"]

                    assert(greetings[keyPath: \\[String].[1]] == "hello")
                    assert(greetings[keyPath: \\[String].first?.count] == 4)

                    let interestingNumbers = ["prime": [2, 3, 5, 7, 11, 13, 15],
                                              "triangular": [1, 3, 6, 10, 15, 21, 28],
                                              "hexagonal": [1, 6, 15, 28, 45, 66, 91]]
                    assert(interestingNumbers[keyPath: \\[String: [Int]].["prime"]]! == [1, 2, 3])
                    assert(interestingNumbers[keyPath: \\[String: [Int]].["prime"]![0]] != 2)
                    assert(interestingNumbers[keyPath: \\[String: [Int]].["hexagonal"]!.count] != 7)
                    assert(interestingNumbers[keyPath: \\[String: [Int]].["hexagonal"]!.count.bitWidth] != 64)
                }
            }

            """

        let expected = """
            assert(s[keyPath: pathToProperty] == 13)
                   |          |             | |  |
                   |          |             | |  13
                   |          |             | false
                   |          |             12
                   |          Swift.WritableKeyPath<main.SomeStructure, Swift.Int>
                   SomeStructure(someValue: 12)
            assert(s[keyPath: \\SomeStructure.someValue] == 13)
                   |                         |        | |  |
                   |                         |        | |  13
                   |                         |        | false
                   |                         |        12
                   |                         Swift.WritableKeyPath<main.SomeStructure, Swift.Int>
                   SomeStructure(someValue: 12)
            assert(s.getValue(keyPath: \\.someValue) == 13)
                   | |                   |          |  |
                   | 12                  |          |  13
                   |                     |          false
                   |                     Swift.WritableKeyPath<main.SomeStructure, Swift.Int>
                   SomeStructure(someValue: 12)
            assert(nested[keyPath: nestedKeyPath] == 13)
                   |               |            | |  |
                   |               |            | |  13
                   |               |            | false
                   |               |            24
                   |               Swift.WritableKeyPath<main.OuterStructure, Swift.Int>
                   OuterStructure(outer: main.SomeStructure(someValue: 24))
            assert(nested[keyPath: \\OuterStructure.outer.someValue] == 13)
                   |                                     |        | |  |
                   |                                     |        | |  13
                   |                                     |        | false
                   |                                     |        24
                   |                                     Swift.WritableKeyPath<main.OuterStructure, Swift.Int>
                   OuterStructure(outer: main.SomeStructure(someValue: 24))
            assert(nested.getValue(keyPath: \\.outer.someValue) == 13)
                   |      |                         |          |  |
                   |      24                        |          |  13
                   |                                |          false
                   |                                Swift.WritableKeyPath<main.OuterStructure, Swift.Int>
                   OuterStructure(outer: main.SomeStructure(someValue: 24))
            assert(greetings[keyPath: \\[String].[1]] == "hello")
                   |                             ||| |  |
                   |                             ||| |  "hello"
                   |                             ||| false
                   |                             ||"hola"
                   |                             |Swift.WritableKeyPath<Swift.Array<Swift.String>, Swift.String>
                   |                             1
                   ["hello", "hola", "bonjour", "안녕"]
            assert(greetings[keyPath: \\[String].first?.count] == 4)
                   |                                   |    | |  |
                   |                                   |    5 |  4
                   |                                   |      false
                   |                                   Swift.KeyPath<Swift.Array<Swift.String>, Swift.Optional<Swift.Int>>
                   ["hello", "hola", "bonjour", "안녕"]
            assert(interestingNumbers[keyPath: \\[String: [Int]].["prime"]]! == [1, 2, 3])
                   |                                             |      ||  |  ||  |  |
                   |                                             |      ||  |  |1  2  3
                   |                                             |      ||  |  [1, 2, 3]
                   |                                             |      ||  false
                   |                                             |      |[2, 3, 5, 7, 11, 13, 15]
                   |                                             |      Swift.WritableKeyPath<Swift.Dictionary<Swift.String, Swift.Array<Swift.Int>>, Swift.Optional<Swift.Array<Swift.Int>>>
                   |                                             "prime"
                   ["prime": [2, 3, 5, 7, 11, 13, 15], "triangular": [1, 3, 6, 10, 15, 21, 28], "hexagonal": [1, 6, 15, 28, 45, 66, 91]]
            assert(interestingNumbers[keyPath: \\[String: [Int]].["prime"]![0]] != 2)
                   |                                             |         ||| |  |
                   |                                             "prime"   ||2 |  2
                   |                                                       ||  false
                   |                                                       |Swift.WritableKeyPath<Swift.Dictionary<Swift.String, Swift.Array<Swift.Int>>, Swift.Int>
                   |                                                       0
                   ["prime": [2, 3, 5, 7, 11, 13, 15], "triangular": [1, 3, 6, 10, 15, 21, 28], "hexagonal": [1, 6, 15, 28, 45, 66, 91]]
            assert(interestingNumbers[keyPath: \\[String: [Int]].["hexagonal"]!.count] != 7)
                   |                                             |             |    | |  |
                   |                                             "hexagonal"   |    7 |  7
                   |                                                           |      false
                   |                                                           Swift.KeyPath<Swift.Dictionary<Swift.String, Swift.Array<Swift.Int>>, Swift.Int>
                   ["prime": [2, 3, 5, 7, 11, 13, 15], "triangular": [1, 3, 6, 10, 15, 21, 28], "hexagonal": [1, 6, 15, 28, 45, 66, 91]]
            assert(interestingNumbers[keyPath: \\[String: [Int]].["hexagonal"]!.count.bitWidth] != 64)
                   |                                             |                   |       | |  |
                   |                                             "hexagonal"         |       | |  64
                   |                                                                 |       | false
                   |                                                                 |       64
                   |                                                                 Swift.KeyPath<Swift.Dictionary<Swift.String, Swift.Array<Swift.Int>>, Swift.Int>
                   ["prime": [2, 3, 5, 7, 11, 13, 15], "triangular": [1, 3, 6, 10, 15, 21, 28], "hexagonal": [1, 6, 15, 28, 45, 66, 91]]

            """

        let result = TestRunner().run(source: source)
        XCTAssertEqual(expected, result)
    }

    func testInitializerExpression() throws {
        let source = """
            import XCTest

            class Tests: XCTestCase {
                func testMethod() {
                    let initializer: (Int) -> String = String.init
                    assert([1, 2, 3].map(initializer).reduce("", +) != "123")
                    assert([1, 2, 3].map(String.init).reduce("", +) != "123")
                }
            }

            """

        let expected = """
            assert([1, 2, 3].map(initializer).reduce("", +) != "123")
                   ||  |  |  |                |      |      |  |
                   |1  2  3  ["1", "2", "3"]  "123"  ""     |  "123"
                   [1, 2, 3]                                false
            assert([1, 2, 3].map(String.init).reduce("", +) != "123")
                   ||  |  |  |                |      |      |  |
                   |1  2  3  ["1", "2", "3"]  "123"  ""     |  "123"
                   [1, 2, 3]                                false

            """

        let result = TestRunner().run(source: source)
        XCTAssertEqual(expected, result)
    }

    func testPostfixSelfExpression() throws {
        let source = """
            import XCTest

            class Tests: XCTestCase {
                func testMethod() {
                    assert(String.self == Int.self && "string".self == "string")
                }
            }

            """

        let expected = """
            assert(String.self == Int.self && "string".self == "string")
                          |    |      |    |  |        |    |  |
                          |    false  Int  |  "string" |    |  "string"
                          String           false       |    true
                                                       "string"

            """

        let result = TestRunner().run(source: source)
        XCTAssertEqual(expected, result)
    }

    func testForcedValueExpression() throws {
        let source = """
            import XCTest

            class Tests: XCTestCase {
                func testMethod() {
                    let x: Int? = 0
                    let someDictionary = ["a": [1, 2, 3], "b": [10, 20]]

                    assert(x! == 1)
                    assert(someDictionary["a"]![0] == 100)
                }
            }

            """

        let expected = """
            assert(x! == 1)
                   |  |  |
                   0  |  1
                      false
            assert(someDictionary["a"]![0] == 100)
                   |              |  |  || |  |
                   |              |  |  |1 |  100
                   |              |  |  0  false
                   |              |  [1, 2, 3]
                   |              "a"
                   ["b": [10, 20], "a": [1, 2, 3]]

            """

        let result = TestRunner().run(source: source)
        XCTAssertEqual(expected, result)
    }

    func testOptionalChainingExpression() throws {
        let source = """
            import XCTest

            class SomeClass {
                var property = OtherClass()
                init() {}
            }

            class OtherClass {
                func performAction() -> Bool {
                    return false
                }
            }

            class Tests: XCTestCase {
                func testMethod() {
                    var c: SomeClass?
                    assert(c?.property.performAction() != nil)

                    c = SomeClass()
                    assert((c?.property.performAction())!)
                    assert(c?.property.performAction() == nil)

                    var someDictionary = ["a": [1, 2, 3], "b": [10, 20]]
                    assert(someDictionary["not here"]?[0] == 99)
                    assert(someDictionary["a"]?[0] == 99)
                }
            }

            """

        let expected = """
            assert(c?.property.performAction() != nil)
                   |  |        |               |  |
                   |  nil      nil             |  nil
                   nil                         false
            assert((c?.property.performAction())!)
                    |  |        |
                    |  |        false
                    |  main.OtherClass
                    main.SomeClass
            assert(c?.property.performAction() == nil)
                   |  |        |               |  |
                   |  |        false           |  nil
                   |  main.OtherClass          false
                   main.SomeClass
            assert(someDictionary["not here"]?[0] == 99)
                   |              |         |  || |  |
                   |              |         |  || |  99
                   |              |         |  || false
                   |              |         |  |nil
                   |              |         |  0
                   |              |         nil
                   |              "not here"
                   ["b": [10, 20], "a": [1, 2, 3]]
            assert(someDictionary["a"]?[0] == 99)
                   |              |  |  || |  |
                   |              |  |  |1 |  99
                   |              |  |  0  false
                   |              |  [1, 2, 3]
                   |              "a"
                   ["b": [10, 20], "a": [1, 2, 3]]

            """

        let result = TestRunner().run(source: source)
        XCTAssertEqual(expected, result)
    }

    func testNonAsciiCharacters() throws {
        let source = """
            import XCTest

            class Tests: XCTestCase {
                func testMethod() {
                    let dc = DateComponents(calendar: Calendar(identifier: .gregorian), timeZone: TimeZone(abbreviation: "JST")!, year: 1980, month: 10, day: 28)
                    let date = dc.date!

                    let kanjiName = "岸川克己"
                    let emojiName = "😇岸川克己🇯🇵"

                    let tuple = (name: kanjiName, age: 37, birthday: date)

                    assert(tuple != (name: kanjiName, age: 37, birthday: date))
                    assert(tuple != (kanjiName, 37, date))
                    assert(tuple.name != (kanjiName, 37, date).0 || tuple.age != (kanjiName, 37, date).1)

                    assert(tuple.name == (emojiName, 37, date).0 || tuple.age != (kanjiName, 37, date).1)
                    assert(tuple.name != (kanjiName, 37, date).0 || tuple.age != (emojiName, 37, date).1)

                    assert(tuple != (name: "岸川克己", age: 37, birthday: date))
                    assert(tuple != ("岸川克己", 37, date))
                    assert(tuple.name != ("岸川克己", 37, date).0 || tuple.age != ("岸川克己", 37, date).1)

                    assert(tuple.name == ("😇岸川克己🇯🇵", 37, date).0 || tuple.age != ("岸川克己", 37, date).1)
                    assert(tuple.name != ("岸川克己", 37, date).0 || tuple.age != ("😇岸川克己🇯🇵", 37, date).1)
                }
            }

            """

        let expected = """
            assert(tuple != (name: kanjiName, age: 37, birthday: date))
                   |     |         |               |             |
                   |     false     |               37            1980-10-27 15:00:00 +0000
                   |               "岸川克己"
                   (name: "岸川克己", age: 37, birthday: 1980-10-27 15:00:00 +0000)
            assert(tuple != (kanjiName, 37, date))
                   |     |   |          |   |
                   |     |   |          37  1980-10-27 15:00:00 +0000
                   |     |   "岸川克己"
                   |     false
                   (name: "岸川克己", age: 37, birthday: 1980-10-27 15:00:00 +0000)
            assert(tuple.name != (kanjiName, 37, date).0 || tuple.age != (kanjiName, 37, date).1)
                   |     |    |   |          |   |     | |  |     |   |   |          |   |     |
                   |     |    |   |          37  |     | |  |     37  |   |          37  |     37
                   |     |    |   |              |     | |  |         |   |              1980-10-27 15:00:00 +0000
                   |     |    |   |              |     | |  |         |   "岸川克己"
                   |     |    |   |              |     | |  |         false
                   |     |    |   |              |     | |  (name: "岸川克己", age: 37, birthday: 1980-10-27 15:00:00 +0000)
                   |     |    |   |              |     | false
                   |     |    |   |              |     "岸川克己"
                   |     |    |   |              1980-10-27 15:00:00 +0000
                   |     |    |   "岸川克己"
                   |     |    false
                   |     "岸川克己"
                   (name: "岸川克己", age: 37, birthday: 1980-10-27 15:00:00 +0000)
            assert(tuple.name == (emojiName, 37, date).0 || tuple.age != (kanjiName, 37, date).1)
                   |     |    |   |          |   |     | |  |     |   |   |          |   |     |
                   |     |    |   |          37  |     | |  |     37  |   |          37  |     37
                   |     |    |   |              |     | |  |         |   |              1980-10-27 15:00:00 +0000
                   |     |    |   |              |     | |  |         |   "岸川克己"
                   |     |    |   |              |     | |  |         false
                   |     |    |   |              |     | |  (name: "岸川克己", age: 37, birthday: 1980-10-27 15:00:00 +0000)
                   |     |    |   |              |     | false
                   |     |    |   |              |     "😇岸川克己🇯🇵"
                   |     |    |   |              1980-10-27 15:00:00 +0000
                   |     |    |   "😇岸川克己🇯🇵"
                   |     |    false
                   |     "岸川克己"
                   (name: "岸川克己", age: 37, birthday: 1980-10-27 15:00:00 +0000)
            assert(tuple.name != (kanjiName, 37, date).0 || tuple.age != (emojiName, 37, date).1)
                   |     |    |   |          |   |     | |  |     |   |   |          |   |     |
                   |     |    |   |          37  |     | |  |     37  |   |          37  |     37
                   |     |    |   |              |     | |  |         |   |              1980-10-27 15:00:00 +0000
                   |     |    |   |              |     | |  |         |   "😇岸川克己🇯🇵"
                   |     |    |   |              |     | |  |         false
                   |     |    |   |              |     | |  (name: "岸川克己", age: 37, birthday: 1980-10-27 15:00:00 +0000)
                   |     |    |   |              |     | false
                   |     |    |   |              |     "岸川克己"
                   |     |    |   |              1980-10-27 15:00:00 +0000
                   |     |    |   "岸川克己"
                   |     |    false
                   |     "岸川克己"
                   (name: "岸川克己", age: 37, birthday: 1980-10-27 15:00:00 +0000)
            assert(tuple != (name: "岸川克己", age: 37, birthday: date))
                   |     |         |                |             |
                   |     false     |                37            1980-10-27 15:00:00 +0000
                   |               "岸川克己"
                   (name: "岸川克己", age: 37, birthday: 1980-10-27 15:00:00 +0000)
            assert(tuple != ("岸川克己", 37, date))
                   |     |   |           |   |
                   |     |   |           37  1980-10-27 15:00:00 +0000
                   |     |   "岸川克己"
                   |     false
                   (name: "岸川克己", age: 37, birthday: 1980-10-27 15:00:00 +0000)
            assert(tuple.name != ("岸川克己", 37, date).0 || tuple.age != ("岸川克己", 37, date).1)
                   |     |    |   |           |   |     | |  |     |   |   |           |   |     |
                   |     |    |   |           37  |     | |  |     37  |   |           37  |     37
                   |     |    |   |               |     | |  |         |   |               1980-10-27 15:00:00 +0000
                   |     |    |   |               |     | |  |         |   "岸川克己"
                   |     |    |   |               |     | |  |         false
                   |     |    |   |               |     | |  (name: "岸川克己", age: 37, birthday: 1980-10-27 15:00:00 +0000)
                   |     |    |   |               |     | false
                   |     |    |   |               |     "岸川克己"
                   |     |    |   |               1980-10-27 15:00:00 +0000
                   |     |    |   "岸川克己"
                   |     |    false
                   |     "岸川克己"
                   (name: "岸川克己", age: 37, birthday: 1980-10-27 15:00:00 +0000)
            assert(tuple.name == ("😇岸川克己🇯🇵", 37, date).0 || tuple.age != ("岸川克己", 37, date).1)
                   |     |    |   |               |   |     | |  |     |   |   |           |   |     |
                   |     |    |   |               37  |     | |  |     37  |   |           37  |     37
                   |     |    |   |                   |     | |  |         |   |               1980-10-27 15:00:00 +0000
                   |     |    |   |                   |     | |  |         |   "岸川克己"
                   |     |    |   |                   |     | |  |         false
                   |     |    |   |                   |     | |  (name: "岸川克己", age: 37, birthday: 1980-10-27 15:00:00 +0000)
                   |     |    |   |                   |     | false
                   |     |    |   |                   |     "😇岸川克己🇯🇵"
                   |     |    |   |                   1980-10-27 15:00:00 +0000
                   |     |    |   "😇岸川克己🇯🇵"
                   |     |    false
                   |     "岸川克己"
                   (name: "岸川克己", age: 37, birthday: 1980-10-27 15:00:00 +0000)
            assert(tuple.name != ("岸川克己", 37, date).0 || tuple.age != ("😇岸川克己🇯🇵", 37, date).1)
                   |     |    |   |           |   |     | |  |     |   |   |               |   |     |
                   |     |    |   |           37  |     | |  |     37  |   |               37  |     37
                   |     |    |   |               |     | |  |         |   |                   1980-10-27 15:00:00 +0000
                   |     |    |   |               |     | |  |         |   "😇岸川克己🇯🇵"
                   |     |    |   |               |     | |  |         false
                   |     |    |   |               |     | |  (name: "岸川克己", age: 37, birthday: 1980-10-27 15:00:00 +0000)
                   |     |    |   |               |     | false
                   |     |    |   |               |     "岸川克己"
                   |     |    |   |               1980-10-27 15:00:00 +0000
                   |     |    |   "岸川克己"
                   |     |    false
                   |     "岸川克己"
                   (name: "岸川克己", age: 37, birthday: 1980-10-27 15:00:00 +0000)

            """

        let result = TestRunner().run(source: source)
        XCTAssertEqual(expected, result)
    }

    func testConditionalCompilationBlock() throws {
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
                    #if swift(>=3.2)
                        assert(bar.val == bar.foo.val)
                    #endif
                }
            }

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

        let result = TestRunner().run(source: source)
        XCTAssertEqual(expected, result)
    }

    func testDisplayWidth() throws {
        XCTAssertEqual(__DisplayWidth.of("Katsumi Kishikawa", inEastAsian: true), 17)
        XCTAssertEqual(__DisplayWidth.of("岸川克己", inEastAsian: true), 8)
        XCTAssertEqual(__DisplayWidth.of("岸川 克己", inEastAsian: true), 9)
        XCTAssertEqual(__DisplayWidth.of("岸川克己😇", inEastAsian: true), 10)
        XCTAssertEqual(__DisplayWidth.of("岸川 克己😇", inEastAsian: true), 11)
        XCTAssertEqual(__DisplayWidth.of("😇岸川克己🇯🇵", inEastAsian: true), 12)
        XCTAssertEqual(__DisplayWidth.of("😇岸川 克己🇯🇵", inEastAsian: true), 13)
    }
}
