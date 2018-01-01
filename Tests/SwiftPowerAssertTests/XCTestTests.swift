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

class XCTestTests: XCTestCase {
    func testBooleanAssertions() throws {
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

    func testEqualityAssertions() throws {
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

    func testComparableAssertions() throws {
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
}
