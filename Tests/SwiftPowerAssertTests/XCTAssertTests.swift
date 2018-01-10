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

            """

        let result = TestRunner().run(source: source)
        XCTAssertEqual(expected, result)
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
}
