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

class XCTAssertTests: XCTestCase {
    func testBooleanAssertions() {
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
                func testMethod() {
                    let bar = Bar(foo: Foo(val: 2), val: 3)
                    XCTAssert(bar.val == bar.foo.val)
                    XCTAssertTrue(bar.val == bar.foo.val)
                    XCTAssertFalse(bar.val != bar.foo.val)
                }
            }
            """

        let expected = """
            XCTAssert(bar.val == bar.foo.val)
                      |   |   |  |   |   |
                      |   3   |  |   |   2
                      |       |  |   Foo(val: 2)
                      |       |  Bar(foo: main.Foo(val: 2), val: 3)
                      |       false
                      Bar(foo: main.Foo(val: 2), val: 3)
            XCTAssertTrue(bar.val == bar.foo.val)
                          |   |   |  |   |   |
                          |   3   |  |   |   2
                          |       |  |   Foo(val: 2)
                          |       |  Bar(foo: main.Foo(val: 2), val: 3)
                          |       false
                          Bar(foo: main.Foo(val: 2), val: 3)
            XCTAssertFalse(bar.val != bar.foo.val)
                           |   |   |  |   |   |
                           |   3   |  |   |   2
                           |       |  |   Foo(val: 2)
                           |       |  Bar(foo: main.Foo(val: 2), val: 3)
                           |       true
                           Bar(foo: main.Foo(val: 2), val: 3)

            """

        let result = TestRunner().run(source: source)
        XCTAssertEqual(expected, result)
    }

    func testEqualityAssertions() {
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
                func testMethod() {
                    let bar = Bar(foo: Foo(val: 2), val: 3)
                    XCTAssertEqual(bar.val, bar.foo.val)
                    XCTAssertNotEqual(bar.val, bar.foo.val + 1)
                }
            }
            """

        let expected = """
            XCTAssertEqual(bar.val, bar.foo.val)
                           |   |    |   |   |
                           |   3    |   |   2
                           |        |   Foo(val: 2)
                           |        Bar(foo: main.Foo(val: 2), val: 3)
                           Bar(foo: main.Foo(val: 2), val: 3)
            XCTAssertNotEqual(bar.val, bar.foo.val + 1)
                              |   |    |   |   |   | |
                              |   3    |   |   2   3 1
                              |        |   Foo(val: 2)
                              |        Bar(foo: main.Foo(val: 2), val: 3)
                              Bar(foo: main.Foo(val: 2), val: 3)

            """

        let result = TestRunner().run(source: source)
        XCTAssertEqual(expected, result)
    }

    func testComparableAssertions() {
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
                func testMethod() {
                    let bar = Bar(foo: Foo(val: 2), val: 3)
                    XCTAssertGreaterThan(bar.foo.val, bar.val)
                    XCTAssertGreaterThan(bar.foo.val + 1, bar.val)
                    XCTAssertGreaterThan(bar.foo.val + 2, bar.val)
                    XCTAssertGreaterThanOrEqual(bar.foo.val, bar.val)
                    XCTAssertGreaterThanOrEqual(bar.foo.val + 1, bar.val)
                    XCTAssertLessThanOrEqual(bar.val, bar.foo.val)
                    XCTAssertLessThanOrEqual(bar.val - 1, bar.foo.val)
                    XCTAssertLessThan(bar.val, bar.foo.val)
                    XCTAssertLessThan(bar.val - 1, bar.foo.val)
                    XCTAssertLessThan(bar.val - 2, bar.foo.val)
                }
            }
            """

        let expected = """
            XCTAssertGreaterThan(bar.foo.val, bar.val)
                                 |   |   |    |   |
                                 |   |   2    |   3
                                 |   |        Bar(foo: main.Foo(val: 2), val: 3)
                                 |   Foo(val: 2)
                                 Bar(foo: main.Foo(val: 2), val: 3)
            XCTAssertGreaterThan(bar.foo.val + 1, bar.val)
                                 |   |   |   | |  |   |
                                 |   |   2   3 1  |   3
                                 |   Foo(val: 2)  Bar(foo: main.Foo(val: 2), val: 3)
                                 Bar(foo: main.Foo(val: 2), val: 3)
            XCTAssertGreaterThanOrEqual(bar.foo.val, bar.val)
                                        |   |   |    |   |
                                        |   |   2    |   3
                                        |   |        Bar(foo: main.Foo(val: 2), val: 3)
                                        |   Foo(val: 2)
                                        Bar(foo: main.Foo(val: 2), val: 3)
            XCTAssertLessThanOrEqual(bar.val, bar.foo.val)
                                     |   |    |   |   |
                                     |   3    |   |   2
                                     |        |   Foo(val: 2)
                                     |        Bar(foo: main.Foo(val: 2), val: 3)
                                     Bar(foo: main.Foo(val: 2), val: 3)
            XCTAssertLessThan(bar.val, bar.foo.val)
                              |   |    |   |   |
                              |   3    |   |   2
                              |        |   Foo(val: 2)
                              |        Bar(foo: main.Foo(val: 2), val: 3)
                              Bar(foo: main.Foo(val: 2), val: 3)
            XCTAssertLessThan(bar.val - 1, bar.foo.val)
                              |   |   | |  |   |   |
                              |   3   2 1  |   |   2
                              |            |   Foo(val: 2)
                              |            Bar(foo: main.Foo(val: 2), val: 3)
                              Bar(foo: main.Foo(val: 2), val: 3)

            """

        let result = TestRunner().run(source: source)
        XCTAssertEqual(expected, result)
    }

    func testNilAssertions() {
        let source = """
            import XCTest

            class Tests: XCTestCase {
                func testMethod() {
                    struct Test {
                        let value: Value
                        init?(rawValue: Int) {
                            if let value = Value(rawValue: rawValue) {
                                self.value = value
                            } else {
                                return nil
                            }
                        }
                    }

                    enum Value: Int {
                        case first = 1
                    }

                    let test1 = Test(rawValue: 1)
                    XCTAssertNil(test1)
                    XCTAssertNil(test1?.value)

                    let test2 = Test(rawValue: 5)
                    XCTAssertNotNil(test2)
                    XCTAssertNotNil(test2?.value)
                }
            }
            """

        let expected = """
            XCTAssertNil(test1)
                         |
                         Test #1(value: Value #1 in main.Tests.testMethod() -> ().first)
            XCTAssertNil(test1?.value)
                         |      |
                         |      first
                         Test #1(value: Value #1 in main.Tests.testMethod() -> ().first)
            XCTAssertNotNil(test2)
                            |
                            nil
            XCTAssertNotNil(test2?.value)
                            |      |
                            nil    nil

            """

        let result = TestRunner().run(source: source)
        XCTAssertEqual(expected, result)
    }

    func testExtraParameters() {
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
                func testMethod() {
                    let bar = Bar(foo: Foo(val: 2), val: 3)
                    XCTAssertEqual(bar.val, bar.foo.val, "should equal")
                    XCTAssertNotEqual(bar.val, bar.foo.val + 1, "should not equal")

                    XCTAssertEqual(bar.val, bar.foo.val, "should equal", file: "dummy.swift", line: 999)
                    XCTAssertNotEqual(bar.val, bar.foo.val + 1, "should not equal", file: "dummy.swift", line: 999)
                }
            }
            """

        let expected = """
            XCTAssertEqual(bar.val, bar.foo.val, "should equal")
                           |   |    |   |   |
                           |   3    |   |   2
                           |        |   Foo(val: 2)
                           |        Bar(foo: main.Foo(val: 2), val: 3)
                           Bar(foo: main.Foo(val: 2), val: 3)
            XCTAssertNotEqual(bar.val, bar.foo.val + 1, "should not equal")
                              |   |    |   |   |   | |
                              |   3    |   |   2   3 1
                              |        |   Foo(val: 2)
                              |        Bar(foo: main.Foo(val: 2), val: 3)
                              Bar(foo: main.Foo(val: 2), val: 3)
            XCTAssertEqual(bar.val, bar.foo.val, "should equal", file: "dummy.swift", line: 999)
                           |   |    |   |   |
                           |   3    |   |   2
                           |        |   Foo(val: 2)
                           |        Bar(foo: main.Foo(val: 2), val: 3)
                           Bar(foo: main.Foo(val: 2), val: 3)
            XCTAssertNotEqual(bar.val, bar.foo.val + 1, "should not equal", file: "dummy.swift", line: 999)
                              |   |    |   |   |   | |
                              |   3    |   |   2   3 1
                              |        |   Foo(val: 2)
                              |        Bar(foo: main.Foo(val: 2), val: 3)
                              Bar(foo: main.Foo(val: 2), val: 3)

            """

        let result = TestRunner().run(source: source)
        XCTAssertEqual(expected, result, "should not equal")
    }

    func testRawRepresentableString() {
        let source = """
            import XCTest

            class Tests: XCTestCase {
                func testMethod() {
                    struct Test {
                        let suit: Suits
                        init(suit: String) {
                            self.suit = Suits(rawValue: suit)!
                        }
                    }

                    enum Suits: String {
                        case hearts = "hearts"
                    }

                    let test = Test(suit: "hearts")
                    XCTAssertTrue(test.suit != .hearts)
                }
            }
            """

        let expected = """
            XCTAssertTrue(test.suit != .hearts)
                          |    |    |   |
                          |    |    |   hearts
                          |    |    false
                          |    hearts
                          Test #1(suit: Suits #1 in main.Tests.testMethod() -> ().hearts)

            """

        let result = TestRunner().run(source: source)
        XCTAssertEqual(expected, result)
    }

    func testRawRepresentableNumber() {
        let source = """
            import XCTest

            class Tests: XCTestCase {
                func testMethod() {
                    struct Test {
                        let value: Value
                        init?(rawValue: Int) {
                            if let value = Value(rawValue: rawValue) {
                                self.value = value
                            } else {
                                return nil
                            }
                        }
                    }

                    enum Value: Int {
                        case first = 1
                    }

                    let test1 = Test(rawValue: 1)
                    XCTAssertTrue(test1?.value != .first)

                    let test2 = Test(rawValue: 5)
                    XCTAssertTrue(test2?.value == .first)
                }
            }
            """

        let expected = """
            XCTAssertTrue(test1?.value != .first)
                          |      |     |   |
                          |      first |   first
                          |            false
                          Test #1(value: Value #1 in main.Tests.testMethod() -> ().first)
            XCTAssertTrue(test2?.value == .first)
                          |      |     |   |
                          nil    nil   |   first
                                       false

            """

        let result = TestRunner().run(source: source)
        XCTAssertEqual(expected, result)
    }

    func testNoOutputWhenSucceeded() {
        let source = """
            import XCTest

            struct Bar {
                let foo: Foo
                var val: Int
            }

            struct Foo {
                var val: Int
            }

            struct Test {
                let value: Value
                init?(rawValue: Int) {
                    if let value = Value(rawValue: rawValue) {
                        self.value = value
                    } else {
                        return nil
                    }
                }
            }

            enum Value: Int {
                case first = 1
            }

            class Tests: XCTestCase {
                func testMethod() {
                    let bar = Bar(foo: Foo(val: 2), val: 3)
                    XCTAssert(bar.val != bar.foo.val)
                    XCTAssert(bar.val == bar.foo.val + 1)
                    XCTAssertTrue(bar.val != bar.foo.val)
                    XCTAssertFalse(bar.val == bar.foo.val)

                    XCTAssertEqual(bar.val, bar.foo.val + 1)
                    XCTAssertNotEqual(bar.val, bar.foo.val)

                    XCTAssertGreaterThan(bar.val, bar.foo.val)
                    XCTAssertGreaterThanOrEqual(bar.val, bar.foo.val)
                    XCTAssertGreaterThanOrEqual(bar.val, bar.foo.val + 1)
                    XCTAssertLessThanOrEqual(bar.foo.val, bar.val)
                    XCTAssertLessThanOrEqual(bar.foo.val + 1, bar.val)
                    XCTAssertLessThan(bar.foo.val, bar.val)

                    let test1 = Test(rawValue: 5)
                    XCTAssertNil(test1)
                    XCTAssertNil(test1?.value)

                    let test2 = Test(rawValue: 1)
                    XCTAssertNotNil(test2)
                    XCTAssertNotNil(test2?.value)
                }
            }
            """

        let expected = """

            """

        let result = TestRunner().run(source: source)
        XCTAssertEqual(expected, result)
    }

    func testThrowsFunction() {
        let source = """
            import XCTest

            class YamlParser {
                static func parse(_ string: String, env: [String: String]) throws -> [String] {
                    return ["1", "2", "3"]
                }
            }

            class Tests: XCTestCase {
                func RuleWithLevelsMock(configuration: String) throws -> String {
                    return ""
                }

                func testMethod() {
                    let rules = ["rule"]
                    let ruleConfiguration = "config"
                    XCTAssertTrue(rules == [try RuleWithLevelsMock(configuration: ruleConfiguration)])

                    XCTAssertEqual((try YamlParser.parse("", env: [:])).count, 0,
                                   "Parsing empty YAML string should succeed")
                    XCTAssertEqual(try YamlParser.parse("a: 1\\nb: 2", env: [:]).count, 2,
                                   "Parsing valid YAML string should succeed")
                }
            }
            """

        let expected = """
            XCTAssertTrue(rules == [try RuleWithLevelsMock(configuration: ruleConfiguration)])
                          |     |  |    |                                 |
                          |     |  [""] ""                                "config"
                          |     false
                          ["rule"]
            XCTAssertEqual((try YamlParser.parse("", env: [:])).count, 0, "Parsing empty YAML string should succeed")
                                           |     |        |     |      |
                                           |     ""       [:]   3      0
                                           ["1", "2", "3"]
            XCTAssertEqual(try YamlParser.parse("a: 1\\nb: 2", env: [:]).count, 2, "Parsing valid YAML string should succeed")
                                          |     |                  |    |      |
                                          |     "a: 1\\nb: 2"       [:]  3      2
                                          ["1", "2", "3"]

            """

        let result = TestRunner().run(source: source)
        XCTAssertEqual(expected, result)
    }

    func testFunctionsInExtension() {
        let source = """
            import XCTest

            struct Bar {
                let foo: Foo
                var val: Int
            }

            struct Foo {
                var val: Int
            }

            class Tests: XCTestCase {}

            extension Tests {
                func testMethod() {
                    let bar = Bar(foo: Foo(val: 2), val: 3)
                    XCTAssert(bar.val == bar.foo.val)
                    XCTAssertTrue(bar.val == bar.foo.val)
                    XCTAssertFalse(bar.val != bar.foo.val)
                }
            }

            extension Sequence where Iterator.Element == Int {
                var sum: Int {
                    return reduce(0, +)
                }
            }
            """

        let expected = """
            XCTAssert(bar.val == bar.foo.val)
                      |   |   |  |   |   |
                      |   3   |  |   |   2
                      |       |  |   Foo(val: 2)
                      |       |  Bar(foo: main.Foo(val: 2), val: 3)
                      |       false
                      Bar(foo: main.Foo(val: 2), val: 3)
            XCTAssertTrue(bar.val == bar.foo.val)
                          |   |   |  |   |   |
                          |   3   |  |   |   2
                          |       |  |   Foo(val: 2)
                          |       |  Bar(foo: main.Foo(val: 2), val: 3)
                          |       false
                          Bar(foo: main.Foo(val: 2), val: 3)
            XCTAssertFalse(bar.val != bar.foo.val)
                           |   |   |  |   |   |
                           |   3   |  |   |   2
                           |       |  |   Foo(val: 2)
                           |       |  Bar(foo: main.Foo(val: 2), val: 3)
                           |       true
                           Bar(foo: main.Foo(val: 2), val: 3)

            """

        let result = TestRunner().run(source: source)
        XCTAssertEqual(expected, result)
    }

    func testStringInterpolation() {
        let source = """
            import XCTest

            struct Client {
                let isAuthenticated = false
                let sessionKey = "session"
            }

            class Tests: XCTestCase {
                func testMethod() {
                    runClientTest(username: "bouke", password: "test")
                    runClientTest(username: "alice", password: "password123")
                    runClientTest(username: "bõūkę", password: "tėšt")
                    runClientTest(username: "bõūkę", password: "😅")
                }

                func runClientTest(username: String, password: String, file: StaticString = #file, line: UInt = #line) {
                    let debugInfo: () -> String = {
                        let infos: [String] = [
                            "username: \\(username)",
                            "password: \\(password)"
                        ]
                        return infos.joined(separator: "\\n")
                    }

                    let additionalDebug = "additionalDebug"

                    let client = Client()
                    let serverSessionKey = "serverSessionKey"

                    let intValue = 0

                    XCTAssert(client.isAuthenticated)
                    XCTAssertEqual(serverSessionKey, client.sessionKey, "Session keys not equal -- \\(debugInfo())abcdefg\\(additionalDebug)abc==\\(intValue)=abc{}()[].;:xyz", file: file, line: line)
                    XCTAssertEqual(serverSessionKey, "Session keys not equal -- \\(debugInfo())abcdefg\\(additionalDebug)abc==\\(intValue)=abc{}()[].;:xyz")
                }
            }
            """

        let expected = """
            XCTAssert(client.isAuthenticated)
                      |      |
                      |      false
                      Client(isAuthenticated: false, sessionKey: "session")
            XCTAssertEqual(serverSessionKey, client.sessionKey, "Session keys not equal -- \\(debugInfo())abcdefg\\(additionalDebug)abc==\\(intValue)=abc{}()[].;:xyz", file: file, line: line)
                           |                 |      |
                           |                 |      "session"
                           |                 Client(isAuthenticated: false, sessionKey: "session")
                           "serverSessionKey"
            XCTAssertEqual(serverSessionKey, "Session keys not equal -- \\(debugInfo())abcdefg\\(additionalDebug)abc==\\(intValue)=abc{}()[].;:xyz")
                           |                 |                            |                    |                      |
                           |                 |                            |                    "additionalDebug"      0
                           |                 |                            "username: bouke\\npassword: test"
                           |                 "Session keys not equal -- username: bouke\\npassword: testabcdefgadditionalDebugabc==0=abc{}()[].;:xyz"
                           "serverSessionKey"
            XCTAssert(client.isAuthenticated)
                      |      |
                      |      false
                      Client(isAuthenticated: false, sessionKey: "session")
            XCTAssertEqual(serverSessionKey, client.sessionKey, "Session keys not equal -- \\(debugInfo())abcdefg\\(additionalDebug)abc==\\(intValue)=abc{}()[].;:xyz", file: file, line: line)
                           |                 |      |
                           |                 |      "session"
                           |                 Client(isAuthenticated: false, sessionKey: "session")
                           "serverSessionKey"
            XCTAssertEqual(serverSessionKey, "Session keys not equal -- \\(debugInfo())abcdefg\\(additionalDebug)abc==\\(intValue)=abc{}()[].;:xyz")
                           |                 |                            |                    |                      |
                           |                 |                            |                    "additionalDebug"      0
                           |                 |                            "username: alice\\npassword: password123"
                           |                 "Session keys not equal -- username: alice\\npassword: password123abcdefgadditionalDebugabc==0=abc{}()[].;:xyz"
                           "serverSessionKey"
            XCTAssert(client.isAuthenticated)
                      |      |
                      |      false
                      Client(isAuthenticated: false, sessionKey: "session")
            XCTAssertEqual(serverSessionKey, client.sessionKey, "Session keys not equal -- \\(debugInfo())abcdefg\\(additionalDebug)abc==\\(intValue)=abc{}()[].;:xyz", file: file, line: line)
                           |                 |      |
                           |                 |      "session"
                           |                 Client(isAuthenticated: false, sessionKey: "session")
                           "serverSessionKey"
            XCTAssertEqual(serverSessionKey, "Session keys not equal -- \\(debugInfo())abcdefg\\(additionalDebug)abc==\\(intValue)=abc{}()[].;:xyz")
                           |                 |                            |                    |                      |
                           |                 |                            |                    "additionalDebug"      0
                           |                 |                            "username: bõūkę\\npassword: tėšt"
                           |                 "Session keys not equal -- username: bõūkę\\npassword: tėštabcdefgadditionalDebugabc==0=abc{}()[].;:xyz"
                           "serverSessionKey"
            XCTAssert(client.isAuthenticated)
                      |      |
                      |      false
                      Client(isAuthenticated: false, sessionKey: "session")
            XCTAssertEqual(serverSessionKey, client.sessionKey, "Session keys not equal -- \\(debugInfo())abcdefg\\(additionalDebug)abc==\\(intValue)=abc{}()[].;:xyz", file: file, line: line)
                           |                 |      |
                           |                 |      "session"
                           |                 Client(isAuthenticated: false, sessionKey: "session")
                           "serverSessionKey"
            XCTAssertEqual(serverSessionKey, "Session keys not equal -- \\(debugInfo())abcdefg\\(additionalDebug)abc==\\(intValue)=abc{}()[].;:xyz")
                           |                 |                            |                    |                      |
                           |                 |                            |                    "additionalDebug"      0
                           |                 |                            "username: bõūkę\\npassword: 😅"
                           |                 "Session keys not equal -- username: bõūkę\\npassword: 😅abcdefgadditionalDebugabc==0=abc{}()[].;:xyz"
                           "serverSessionKey"

            """

        let result = TestRunner().run(source: source)
        XCTAssertEqual(expected, result)
    }

    func testArrayEquatable() {
        let source = """
        import XCTest

        class Tests: XCTestCase {
            func testMethod() {
                let contents: [String] = ["foo", "bar"]
                let tmpDir = "/var/tmp"
                XCTAssertEqual(contents, ["\\(tmpDir)/bar", "\\(tmpDir)/baz"])
            }
        }
        """

        let expected = """
            XCTAssertEqual(contents, ["\\(tmpDir)/bar", "\\(tmpDir)/baz"])
                           |         ||  |             |  |
                           |         ||  "/var/tmp"    |  "/var/tmp"
                           |         |"/var/tmp/bar"   "/var/tmp/baz"
                           |         ["/var/tmp/bar", "/var/tmp/baz"]
                           ["foo", "bar"]

            """

        let result = TestRunner().run(source: source)
        XCTAssertEqual(expected, result)
    }

    func testDoStatement() {
        let source = """
        import XCTest

        class Tests: XCTestCase {
            enum CustomError: Error {
                case systemError
            }

            func testMethod() {
                do {
                    let expectedError = NSError(domain: "test", code: -999, userInfo: nil)
                    let error = CustomError.systemError as NSError
                    XCTAssertEqual(expectedError, error as NSError, "Expected the given error.")
                    XCTAssertTrue(expectedError === error as NSError, "Expected the same error, not just an equal error.")
                }
            }
        }
        """

        let expected = """
            XCTAssertEqual(expectedError, error as NSError, "Expected the given error.")
                           |              |
                           |              Error Domain=main.Tests.CustomError Code=0 "(null)"
                           Error Domain=test Code=-999 "(null)"
            XCTAssertTrue(expectedError === error as NSError, "Expected the same error, not just an equal error.")
                          |             |   |
                          |             |   Error Domain=main.Tests.CustomError Code=0 "(null)"
                          |             false
                          Error Domain=test Code=-999 "(null)"

            """

        let result = TestRunner().run(source: source)
        XCTAssertEqual(expected, result)
    }

    func testTryAssert1() {
        let source = """
            import XCTest

            class Tests: XCTestCase {
                func testMethod() {
                    try XCTAssertEqual(String(contentsOf: URL(string: "https://httpbin.org/robots.txt")!, encoding: .utf8), "test")
                }
            }
            """

        let expected = """
            XCTAssertEqual(String(contentsOf: URL(string: "https://httpbin.org/robots.txt")!, encoding: .utf8), "test")
                           |                  |           |                                              |      |
                           |                  |           "https://httpbin.org/robots.txt"               |      "test"
                           |                  https://httpbin.org/robots.txt                             Unicode (UTF-8)
                           "User-agent: *\\nDisallow: /deny\\n"

            """

        let result = TestRunner().run(source: source)
        XCTAssertEqual(expected, result)
    }

    func testTryAssert2() throws {
        let source = """
            import XCTest

            struct Row {
                static func fetchCursor(_ db: String, _ query: String) throws -> Row {
                    return Row()
                }

                func next() -> [Bool]? {
                    return [false, false]
                }
            }

            class Tests: XCTestCase {
                func testMethod() {
                    let db = "test"
                    XCTAssertNil(try Row.fetchCursor(db, "SELECT textAffinity FROM `values`").next()![0] as Bool)
                }
            }
            """

        let expected = """
            XCTAssertNil(try Row.fetchCursor(db, "SELECT textAffinity FROM `values`").next()![0] as Bool)
                                 |           |   |                                    |       ||
                                 Row()       |   "SELECT textAffinity FROM `values`"  |       |false
                                             "test"                                   |       0
                                                                                      [false, false]

            """

        let result = TestRunner().run(source: source)
        XCTAssertEqual(expected, result)
    }

    func testRemovingUnexpectedLValueInType() {
        let source = """
            import XCTest

            open class Record {}
            private class Person : Record {
                var id: Int64?
                let name: String
                let email: String?
                let bookCount: Int?

                init(id: Int64? = nil, name: String, email: String? = nil) {
                    self.id = id
                    self.name = name
                    self.email = email
                    self.bookCount = nil
                }
            }
            extension Person: CustomStringConvertible {
                var description: String {
                    return "{ id: \\(id.flatMap { "\\($0)" } ?? "nil"), name: \\(name), email: \\(email ?? "nil"), bookCount: \\(bookCount.flatMap { "\\($0)" } ?? "nil") }"
                }
            }
            private class ChangesRecorder<Record> {
                var changes: [(record: Record, change: Int)] = []
            }
            extension ChangesRecorder: CustomStringConvertible {
                var description: String {
                    return "ChangesRecorder<Record>"
                }
            }

            class Tests: XCTestCase {
                func testMethod() {
                    let recorder = ChangesRecorder<Person>()
                    recorder.changes.append((Person(name: "test"), 0))
                    recorder.changes.append((Person(name: "test"), 0))

                    XCTAssertEqual(recorder.changes.count, 1)
                    XCTAssertEqual(recorder.changes[0].record.id, 1)
                    XCTAssertEqual(recorder.changes[0].record.name, "Arthur")
                }
            }
            """

        let expected = """
            XCTAssertEqual(recorder.changes.count, 1)
                           |        |       |      |
                           |        |       2      1
                           |        [(record: { id: nil, name: test, email: nil, bookCount: nil }, change: 0), (record: { id: nil, name: test, email: nil, bookCount: nil }, change: 0)]
                           ChangesRecorder<Record>
            XCTAssertEqual(recorder.changes[0].record.id, 1)
                           |        |       || |      |   |
                           |        |       || |      nil 1
                           |        |       || { id: nil, name: test, email: nil, bookCount: nil }
                           |        |       |(record: { id: nil, name: test, email: nil, bookCount: nil }, change: 0)
                           |        |       0
                           |        [(record: { id: nil, name: test, email: nil, bookCount: nil }, change: 0), (record: { id: nil, name: test, email: nil, bookCount: nil }, change: 0)]
                           ChangesRecorder<Record>
            XCTAssertEqual(recorder.changes[0].record.name, "Arthur")
                           |        |       || |      |     |
                           |        |       || |      |     "Arthur"
                           |        |       || |      "test"
                           |        |       || { id: nil, name: test, email: nil, bookCount: nil }
                           |        |       |(record: { id: nil, name: test, email: nil, bookCount: nil }, change: 0)
                           |        |       0
                           |        [(record: { id: nil, name: test, email: nil, bookCount: nil }, change: 0), (record: { id: nil, name: test, email: nil, bookCount: nil }, change: 0)]
                           ChangesRecorder<Record>

            """

        let result = TestRunner().run(source: source)
        XCTAssertEqual(expected, result)
    }

    func testOptionalChaining1() {
        let source = """
            import XCTest

            protocol FetchedResultsSectionInfo {
                var name: String { get }
                var indexTitle: String? { get }
                var numberOfObjects: Int { get }
                var objects: [Any]? { get }
            }

            struct SectionInfo: FetchedResultsSectionInfo {
                var name: String
                var indexTitle: String?
                var numberOfObjects: Int
                var objects: [Any]?
            }

            class Tests: XCTestCase {
                func testMethod() {
                    var userInfo: [String: Any]? = [String: Any]()
                    userInfo?["sectionInfo"] = SectionInfo(name: "test", indexTitle: nil, numberOfObjects: 10, objects: nil)
                    let sectionInfo = userInfo?["sectionInfo"] as? FetchedResultsSectionInfo

                    XCTAssertNil(sectionInfo)
                    XCTAssertEqual(sectionInfo?.name, "0")
                    XCTAssertEqual(sectionInfo!.name, "0")
                }
            }
            """
        // FIXME: Should print values of `sectionInfo?.name` and `sectionInfo!.name`
        let expected = """
            XCTAssertNil(sectionInfo)
                         |
                         SectionInfo(name: "test", indexTitle: nil, numberOfObjects: 10, objects: nil)
            XCTAssertEqual(sectionInfo?.name, "0")
                           |                  |
                           |                  "0"
                           SectionInfo(name: "test", indexTitle: nil, numberOfObjects: 10, objects: nil)
            XCTAssertEqual(sectionInfo!.name, "0")
                           |                  |
                           |                  "0"
                           SectionInfo(name: "test", indexTitle: nil, numberOfObjects: 10, objects: nil)

            """

        let result = TestRunner().run(source: source)
        XCTAssertEqual(expected, result)
    }

    func testOptionalChaining2() {
        let source = """
            import XCTest

            class DataStore {
                func fetchSource() -> Context? {
                    return Context()
                }
            }
            class Context {
                func unsafeContext() -> Context? {
                    return Context()
                }
            }
            class Transaction {
                let context = Context()
            }
            extension Context: Equatable {
                static func ==(lhs: Context, rhs: Context) -> Bool {
                    return false
                }
            }

            class Tests: XCTestCase {
                func testMethod() {
                    let object = DataStore()
                    let transaction = Transaction()
                    XCTAssertEqual(object.fetchSource()?.unsafeContext(), transaction.context)
                }
            }
            """
        
        let expected = """
            XCTAssertEqual(object.fetchSource()?.unsafeContext(), transaction.context)
                           |      |              |                |           |
                           |      main.Context   main.Context     |           main.Context
                           main.DataStore                         main.Transaction

            """

        let result = TestRunner().run(source: source)
        XCTAssertEqual(expected, result)
    }

    func testBinaryExpression() {
        let source = """
            import XCTest

            class Entity {
                var entityClass: AnyClass {
                    return Entity.self
                }
                var managedObjectClassName: String {
                    return "Entity"
                }
            }
            class Request {
                var entity: Entity? {
                    return Entity()
                }
            }

            class Tests: XCTestCase {
                func testMethod() {
                    let from = Entity()
                    let request = Request()
                    XCTAssert(from.entityClass == NSClassFromString(request.entity!.managedObjectClassName))
                }
            }
            """

        let expected = """
            XCTAssert(from.entityClass == NSClassFromString(request.entity!.managedObjectClassName))
                      |    |           |  |                 |       |       |
                      |    Entity      |  nil               |       |       "Entity"
                      main.Entity      false                |       main.Entity
                                                            main.Request

            """

        let result = TestRunner().run(source: source)
        XCTAssertEqual(expected, result)
    }

    func testDictionaryLiteral() {
        let source = """
            import XCTest

            class TestEntity1: NSManagedObject {
                @NSManaged var testEntityID: NSNumber?
                @NSManaged var testString: String?
                @NSManaged var testNumber: NSNumber?
                @NSManaged var testDate: Date?
                @NSManaged var testBoolean: NSNumber?
                @NSManaged var testDecimal: NSDecimalNumber?
                @NSManaged var testData: Data?
                @NSManaged var testNil: String?
            }

            class Tests: XCTestCase {
                func testMethod() {
                    let dateFormatter = DateFormatter()
                    dateFormatter.locale = Locale(identifier: "en_US_POSIX")
                    dateFormatter.timeZone = TimeZone(identifier: "UTC")
                    dateFormatter.calendar = Calendar(identifier: Calendar.Identifier.gregorian)
                    dateFormatter.dateFormat = "yyyy'-'MM'-'dd'T'HH':'mm':'ssZ"

                    let values = [[String: AnyObject]]()

                    XCTAssertEqual(
                        values as Any as! [NSDictionary],
                        [
                            [
                                #keyPath(TestEntity1.testBoolean): NSNumber(value: false),
                                #keyPath(TestEntity1.testNumber): NSNumber(value: 4),
                                #keyPath(TestEntity1.testDecimal): NSDecimalNumber(string: "4"),
                                #keyPath(TestEntity1.testString): "nil:TestEntity1:4",
                                #keyPath(TestEntity1.testData): ("nil:TestEntity1:4" as NSString).data(using: String.Encoding.utf8.rawValue)!,
                                #keyPath(TestEntity1.testDate): dateFormatter.date(from: "2000-01-04T00:00:00Z")!
                            ],
                            [
                                #keyPath(TestEntity1.testBoolean): NSNumber(value: true),
                                #keyPath(TestEntity1.testNumber): NSNumber(value: 5),
                                #keyPath(TestEntity1.testDecimal): NSDecimalNumber(string: "5"),
                                #keyPath(TestEntity1.testString): "nil:TestEntity1:5",
                                #keyPath(TestEntity1.testData): ("nil:TestEntity1:5" as NSString).data(using: String.Encoding.utf8.rawValue)!,
                                #keyPath(TestEntity1.testDate): dateFormatter.date(from: "2000-01-05T00:00:00Z")!
                            ]
                        ] as [NSDictionary]
                    )
                }
            }
            """

        let expected = """
            XCTAssertEqual( values as Any as! [NSDictionary], [ [ #keyPath(TestEntity1.testBoolean): NSNumber(value: false), #keyPath(TestEntity1.testNumber): NSNumber(value: 4), #keyPath(TestEntity1.testDecimal): NSDecimalNumber(string: "4"), #keyPath(TestEntity1.testString): "nil:TestEntity1:4", #keyPath(TestEntity1.testData): ("nil:TestEntity1:4" as NSString).data(using: String.Encoding.utf8.rawValue)!, #keyPath(TestEntity1.testDate): dateFormatter.date(from: "2000-01-04T00:00:00Z")! ], [ #keyPath(TestEntity1.testBoolean): NSNumber(value: true), #keyPath(TestEntity1.testNumber): NSNumber(value: 5), #keyPath(TestEntity1.testDecimal): NSDecimalNumber(string: "5"), #keyPath(TestEntity1.testString): "nil:TestEntity1:5", #keyPath(TestEntity1.testData): ("nil:TestEntity1:5" as NSString).data(using: String.Encoding.utf8.rawValue)!, #keyPath(TestEntity1.testDate): dateFormatter.date(from: "2000-01-05T00:00:00Z")! ] ] as [NSDictionary] )
                            |                                 | |                                 |  |               |                                      |  |               |                                   |  |                       |                                    |  |                                                 |   |                                |                           |    |                                        |  |             |          |                           |                                 |  |               |                                     |  |               |                                   |  |                       |                                    |  |                                                 |   |                                |                           |    |                                        |  |             |          |
                            []                                | |                                 |  0               false                                  |  4               4                                   |  4                       "4"                                  |  "nil:TestEntity1:4"                               |   "nil:TestEntity1:4"              17 bytes                    |    4                                        |  |             |          "2000-01-04T00:00:00Z"      |                                 |  1               true                                  |  5               5                                   |  5                       "5"                                  |  "nil:TestEntity1:5"                               |   "nil:TestEntity1:5"              17 bytes                    |    4                                        |  |             |          "2000-01-05T00:00:00Z"
                                                              | |                                 "testBoolean"                                             "testNumber"                                           "testDecimal"                                                   "testString"                                         "testData"                                                       Unicode (UTF-8)                               |  |             2000-01-04 00:00:00 +0000              |                                 "testBoolean"                                            "testNumber"                                           "testDecimal"                                                   "testString"                                         "testData"                                                       Unicode (UTF-8)                               |  |             2000-01-05 00:00:00 +0000
                                                              | {     testBoolean = 0;     testData = <6e696c3a 54657374 456e7469 7479313a 34>;     testDate = "2000-01-04 00:00:00 +0000";     testDecimal = 4;     testNumber = 4;     testString = "nil:TestEntity1:4"; }                                                                                                                                                                           |  <NSDateFormatter: 0x101300110>                       {     testBoolean = 1;     testData = <6e696c3a 54657374 456e7469 7479313a 35>;     testDate = "2000-01-05 00:00:00 +0000";     testDecimal = 5;     testNumber = 5;     testString = "nil:TestEntity1:5"; }                                                                                                                                                                          |  <NSDateFormatter: 0x101300110>
                                                              |                                                                                                                                                                                                                                                                                                                                                                                        "testDate"                                                                                                                                                                                                                                                                                                                                                                                                                                    "testDate"
                                                              [{     testBoolean = 0;     testData = <6e696c3a 54657374 456e7469 7479313a 34>;     testDate = "2000-01-04 00:00:00 +0000";     testDecimal = 4;     testNumber = 4;     testString = "nil:TestEntity1:4"; }, {     testBoolean = 1;     testData = <6e696c3a 54657374 456e7469 7479313a 35>;     testDate = "2000-01-05 00:00:00 +0000";     testDecimal = 5;     testNumber = 5;     testString = "nil:TestEntity1:5"; }]

            """

        let result = TestRunner().run(source: source)
        XCTAssertEqual(expected.replacingOccurrences(of: "<NSDateFormatter: 0x.+>", with: "", options: .regularExpression),
                       result.replacingOccurrences(of: "<NSDateFormatter: 0x.+>", with: "", options: .regularExpression))
    }

    func testAssertInClosure() {
        let source = """
            import XCTest

            class Tests: XCTestCase {
                func request(_ path: String, callback: (_ error: Error?) -> ()) {
                    callback(NSError(domain: "test", code: 0, userInfo: nil))
                }

                func testMethod() {
                    request("/api/users") { (error) in
                        XCTAssertNil(error)
                    }
                }
            }
            """

        let expected = """
            XCTAssertNil(error)
                         |
                         Error Domain=test Code=0 "(null)"

            """

        let result = TestRunner().run(source: source)
        XCTAssertEqual(expected, result)
    }

    func testNoWhitespaces() {
        let source = """
            import XCTest

            class Tests: XCTestCase {
                func testMethod() {
                    XCTAssert(false&&"hello".appending("a")=="")
                }
            }
            """

        let expected = """
            XCTAssert(false&&"hello".appending("a")=="")
                      |    | |       |         |   | |
                      |    | "hello" "helloa"  "a" | ""
                      |    false                   false
                      false

            """

        let result = TestRunner().run(source: source)
        XCTAssertEqual(expected, result)
    }

    func testCallExpression() {
        let source = """
            import XCTest

            class Tests: XCTestCase {
                func testMethod() {
                    let i = 9
                    XCTAssert((i * 2).distance(to: 4) == 5)
                }
            }
            """

        let expected = """
            XCTAssert((i * 2).distance(to: 4) == 5)
                       | | |  |            |  |  |
                       9 | 2  -14          4  |  5
                         18                   false

            """

        let result = TestRunner().run(source: source)
        XCTAssertEqual(expected, result)
    }

    func testFunctionInArrayLiteral() {
        let source = """
            import XCTest

            struct Data {
                static func fetchOne(_ db: String, _ sql: String, arguments: [Data]) throws -> Data? {
                    return Data()
                }
            }
            extension Data: Equatable {
                static func ==(lhs: Data, rhs: Data) -> Bool {
                    return false
                }
            }

            class Tests: XCTestCase {
                func testMethod() {
                    let db = "db"
                    XCTAssertEqual(try Data.fetchOne(db, "SELECT f(?)", arguments: [Data()])!, Data())
                }
            }
            """

        let expected = """
            XCTAssertEqual(try Data.fetchOne(db, "SELECT f(?)", arguments: [Data()])!, Data())
                                    |        |   |                         ||          |
                                    Data()   |   "SELECT f(?)"             |Data()     Data()
                                             "db"                          [main.Data()]

            """

        let result = TestRunner().run(source: source)
        XCTAssertEqual(expected, result)
    }

    func testMethodChaining() {
        let source = """
            import XCTest

            class Database {
                var schemaCache: DatabaseSchemaCache

                init() {
                    schemaCache = DatabaseSchemaCache()
                }
            }

            class DatabaseSchemaCache {
                func primaryKey(_ key: String) -> String? {
                    return ""
                }
            }

            class Tests: XCTestCase {
                func testMethod() {
                    let db = Database()
                    XCTAssertTrue(db.schemaCache.primaryKey("items") == nil)
                }
            }
            """

        let expected = """
            XCTAssertTrue(db.schemaCache.primaryKey("items") == nil)
                          |  |           |          |        |  |
                          |  |           ""         "items"  |  nil
                          |  main.DatabaseSchemaCache        false
                          main.Database

            """

        let result = TestRunner().run(source: source)
        XCTAssertEqual(expected, result)
    }

    func testCustomNilCoalescingOperator() {
        let source = """
            import XCTest

            protocol SQLExpressible: Expressible {}
            protocol SQLExpression: SQLExpressible {}
            protocol Expressible {}
            protocol Value: SQLExpressible {}
            extension Int: Value {}
            struct Expression<Datatype>: Expressible {}

            class Request {
                func filter(_ predicate: SQLExpressible) -> Bool {
                    return false
                }
            }

            public struct Column {
                public static let rowID = Column("rowid")
                public let name: String
                public init(_ name: String) {
                    self.name = name
                }
            }
            extension Column: SQLExpression {}

            struct Col {
                static let id = Column("id")
                static let name = Column("name")
                static let age = Column("age")
                static let readerId = Column("readerId")
            }

            func ??<V: Value>(optional: Expression<V?>, defaultValue: V) -> Expression<V> {
                return Expression<V>()
            }

            class Tests: XCTestCase {
                func testMethod() {
                    let tableRequest = Request()
                    let optInt: Int? = nil
                    XCTAssert(tableRequest.filter(optInt ?? Col.age))
                }
            }
            """

        let expected = """
            XCTAssert(tableRequest.filter(optInt ?? Col.age))
                      |            |      |      |      |
                      main.Request false  nil    |      Column(name: "age")
                                                 Column(name: "age")

            """

        let result = TestRunner().run(source: source)
        XCTAssertEqual(expected, result)
    }
}
