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

class AssertTests: XCTestCase {
    func testBinaryExpression1() {
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

    func testBinaryExpression2() {
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

    func testBinaryExpression3() {
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

    func testBinaryExpression4() {
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

    func testBinaryExpression5() {
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

    func testBinaryExpression6() {
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

    func testBinaryExpression7() {
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

    func testBinaryExpression8() {
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

    func testMultilineExpression1() {
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

    func testMultilineExpression2() {
        let source = """
            import XCTest

            class Tests: XCTestCase {
                func testMethod() {
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

    func testMultilineExpression3() {
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

    func testMultilineExpression4() {
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

    func testMultilineExpression5() {
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

    func testMultilineExpression6() {
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

    func testTryExpression() {
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
                func testMethod() {
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
                        |             |      |         |  "{ name: \\"Tokyo Tower\\" }" 23 bytes                    Unicode (UTF-8)
                        |             |      |         false
                        |             |      Landmark(name: "Tokyo Tower", foundingYear: 1957, location: main.Coordinate(latitude: 35.658580999999998, longitude: 139.74543800000001))
                        |             99 bytes
                        Foundation.JSONEncoder
            assert(try! JSONEncoder().encode(landmark) == "{ name: \\"Tokyo Tower\\" }".data(using: .utf8))
                        |             |      |         |  |                           |            |
                        |             |      |         |  "{ name: \\"Tokyo Tower\\" }" 23 bytes     Unicode (UTF-8)
                        |             |      |         false
                        |             |      Landmark(name: "Tokyo Tower", foundingYear: 1957, location: main.Coordinate(latitude: 35.658580999999998, longitude: 139.74543800000001))
                        |             99 bytes
                        Foundation.JSONEncoder
            assert(try! "{ name: \\"Tokyo Tower\\" }".data(using: String.Encoding.utf8) == JSONEncoder().encode(landmark))
                        |                           |                           |     |  |             |      |
                        "{ name: \\"Tokyo Tower\\" }" 23 bytes                    |     |  |             |      Landmark(name: "Tokyo Tower", foundingYear: 1957, location: main.Coordinate(latitude: 35.658580999999998, longitude: 139.74543800000001))
                                                                                |     |  |             99 bytes
                                                                                |     |  Foundation.JSONEncoder
                                                                                |     false
                                                                                Unicode (UTF-8)

            """

        let result = TestRunner().run(source: source)
        XCTAssertEqual(expected, result)
    }

    func testNilLiteral() {
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

    func testTernaryConditionalOperator() {
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

    func testArrayLiteralExpression() {
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

    func testDictionaryLiteralExpression() {
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

    func testMagicLiteralExpression() {
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
        
        let expected = """
            assert(#file == "*.swift" && #line == 1 && #column == 2 && #function == "function")
                   |     |  |         |  |     |  | |  |       |  | |  |         |  |
                   |     |  "*.swift" |  5     |  1 |  52      |  2 |  |         |  "function"
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

    func testSelfExpression() {
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

    func testImplicitMemberExpression() {
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

    func testTupleExpression() {
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

    func testKeyPathExpression() {
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

            """

        let result = TestRunner().run(source: source)
        XCTAssertEqual(expected, result)
    }

    #if swift(>=4.0.3)
    func testSubscriptKeyPathExpression() {
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
    #endif

    func testInitializerExpression() {
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

    func testPostfixSelfExpression() {
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

    func testForcedValueExpression() {
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

    func testOptionalChainingExpression() {
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

    func testNonAsciiCharacters() {
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

    func testConditionalCompilationBlock() {
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

    func testSelectorExpression() {
        let source = """
            import XCTest

            class SomeClass: NSObject {
                @objc let property: String
                @objc(doSomethingWithInt:)
                func doSomething(_ x: Int) {}

                init(property: String) {
                    self.property = property
                }
            }

            class Tests: XCTestCase {
                func testMethod() {
                    assert(#selector(SomeClass.doSomething(_:)) == #selector(getter: NSObjectProtocol.description))
                    assert(#selector(getter: SomeClass.property) == #selector(getter: NSObjectProtocol.description))
                }
            }
            """

        let expected = """
            assert(#selector(SomeClass.doSomething(_:)) == #selector(getter: NSObjectProtocol.description))
                                                      | |                                                |
                                                      | false                                            "description"
                                                      "doSomethingWithInt:"
            assert(#selector(getter: SomeClass.property) == #selector(getter: NSObjectProtocol.description))
                                                       | |                                                |
                                                       | false                                            "description"
                                                       "property"

            """

        let result = TestRunner().run(source: source)
        XCTAssertEqual(expected, result)
    }

    func testExplicitMemberExpression() {
        let source = """
            import XCTest

            class Tests: XCTestCase {
                func testMethod() {
                    let arr = [1, 2, 3]
                    assert(
                        [10, 3, 20, 15, 4]
                            .sorted()
                            .filter { $0 > 5 }
                            .map { $0 * 100 } == arr
                    )
                }
            }
            """

        let expected = """
            assert( [10, 3, 20, 15, 4] .sorted() .filter { $0 > 5 } .map { $0 * 100 } == arr )
                    ||   |  |   |   |   |         |                  |                |  |
                    |10  3  20  15  4   |         [10, 15, 20]       |                |  [1, 2, 3]
                    [10, 3, 20, 15, 4]  [3, 4, 10, 15, 20]           |                false
                                                                     [1000, 1500, 2000]

            """

        let result = TestRunner().run(source: source)
        XCTAssertEqual(expected, result)
    }

    func testMultipleStatementInClosure() {
        let source = """
            import XCTest

            class Tests: XCTestCase {
                func testMethod() {
                    let a = 5
                    let b = 10

                    assert(
                        { (a: Int, b: Int) -> Bool in
                            let c = a + b
                            let d = a - b
                            if c != d {
                                _ = c.distance(to: d)
                                _ = d.distance(to: c)
                            }
                            return c == d
                        }(a, b)
                    )
                }
            }
            """

        let expected = """
            assert( { (a: Int, b: Int) -> Bool in let c = a + b;let d = a - b;if c != d { _ = c.distance(to: d);_ = d.distance(to: c) };return c == d }(a, b) )
                    |                                                                                                                                   |  |
                    false                                                                                                                               5  10

            """

        let result = TestRunner().run(source: source)
        XCTAssertEqual(expected, result)
    }

    func testMessageParameters() {
        let source = """
            import XCTest

            class Tests: XCTestCase {
                func testMethod() {
                    let zero = 0
                    let one = 1
                    let two = 2
                    let three = 3

                    let array = [one, two, three]
                    assert(array.description.hasPrefix("[") == false && array.description.hasPrefix("Hello") == true, "message")
                }
            }
            """

        let expected = """
            assert(array.description.hasPrefix("[") == false && array.description.hasPrefix("Hello") == true, "message")
                   |     |           |         |    |  |     |  |     |           |         |        |  |
                   |     "[1, 2, 3]" true      "["  |  false |  |     "[1, 2, 3]" false     "Hello"  |  true
                   [1, 2, 3]                        false    |  [1, 2, 3]                            false
                                                             false

            """

        let result = TestRunner().run(source: source)
        XCTAssertEqual(expected, result)
    }

    func testStringContainsNewlines() {
        let source = """
            import XCTest

            class Tests: XCTestCase {
                func testMethod() {
                    let loremIpsum = "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua."
                    assert(loremIpsum ==
                        "Lorem ipsum dolor sit amet,\\nconsectetur adipiscing elit,")
                }
            }
            """

        let expected = """
            assert(loremIpsum == "Lorem ipsum dolor sit amet,\\nconsectetur adipiscing elit,")
                   |          |  |
                   |          |  "Lorem ipsum dolor sit amet,\\nconsectetur adipiscing elit,"
                   |          false
                   "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua."

            """

        let result = TestRunner().run(source: source)
        XCTAssertEqual(expected, result)
    }

    func testStringContainsEscapeSequences() {
        let source = """
            import XCTest

            class Tests: XCTestCase {
                func testMethod() {
                    let lyric1 = "Feet, don't fail me now."
                    assert(lyric1 != "Feet, don't fail me now.")
                    assert(lyric1 != "Feet, don\\'t fail me now.")

                    let lyric2 = "Feet, don\\'t fail me now."
                    assert(lyric2 != "Feet, don't fail me now.")
                    assert(lyric2 != "Feet, don\\'t fail me now.")

                    let nestedQuote1 = "My mother said, \\"The baby started talking today. The baby said, 'Mama.'\\""
                    assert(nestedQuote1 != "My mother said, \\"The baby started talking today. The baby said, 'Mama.'\\"")
                    assert(nestedQuote1 != "My mother said, \\"The baby started talking today. The baby said, \\'Mama.\\'\\"")

                    let nestedQuote2 = "My mother said, \\"The baby started talking today. The baby said, \\'Mama.\\'\\""
                    assert(nestedQuote2 != "My mother said, \\"The baby started talking today. The baby said, 'Mama.'\\"")
                    assert(nestedQuote2 != "My mother said, \\"The baby started talking today. The baby said, \\'Mama.\\'\\"")

                    let helpText = "OPTIONS:\\n  --build-path\\t\\tSpecify build/cache directory [default: ./.build]"
                    assert(helpText != "OPTIONS:\\n  --build-path\\t\\tSpecify build/cache directory [default: ./.build]")

                    let nullCharacter = "Null character\\0Null character"
                    assert(nullCharacter != "Null character\\0Null character")

                    let lineFeed = "Line feed\\nLine feed"
                    assert(lineFeed != "Line feed\\nLine feed")

                    let carriageReturn = "Carriage Return\\rCarriage Return"
                    assert(carriageReturn != "Carriage Return\\rCarriage Return")

                    let backslash = "Backslash\\\\Backslash"
                    assert(backslash != "Backslash\\\\Backslash")

                    let wiseWords = "\\"Imagination is more important than knowledge\\" - Einstein"
                    let dollarSign = "\\u{24}"        // $,  Unicode scalar U+0024
                    let blackHeart = "\\u{2665}"      // ♥,  Unicode scalar U+2665
                    let sparklingHeart = "\\u{1F496}" // 💖, Unicode scalar U+1F496
                    assert(wiseWords != "\\"Imagination is more important than knowledge\\" - Einstein")
                    assert(dollarSign != "\\u{24}" )
                    assert(blackHeart != "\\u{2665}")
                    assert(sparklingHeart != "\\u{1F496}")
                }
            }
            """

        let expected = """
            assert(lyric1 != "Feet, don't fail me now.")
                   |      |  |
                   |      |  "Feet, don't fail me now."
                   |      false
                   "Feet, don't fail me now."
            assert(lyric1 != "Feet, don't fail me now.")
                   |      |  |
                   |      |  "Feet, don't fail me now."
                   |      false
                   "Feet, don't fail me now."
            assert(lyric2 != "Feet, don't fail me now.")
                   |      |  |
                   |      |  "Feet, don't fail me now."
                   |      false
                   "Feet, don't fail me now."
            assert(lyric2 != "Feet, don't fail me now.")
                   |      |  |
                   |      |  "Feet, don't fail me now."
                   |      false
                   "Feet, don't fail me now."
            assert(nestedQuote1 != "My mother said, \\"The baby started talking today. The baby said, 'Mama.'\\"")
                   |            |  |
                   |            |  "My mother said, \\"The baby started talking today. The baby said, 'Mama.'\\""
                   |            false
                   "My mother said, \\"The baby started talking today. The baby said, 'Mama.'\\""
            assert(nestedQuote1 != "My mother said, \\"The baby started talking today. The baby said, 'Mama.'\\"")
                   |            |  |
                   |            |  "My mother said, \\"The baby started talking today. The baby said, 'Mama.'\\""
                   |            false
                   "My mother said, \\"The baby started talking today. The baby said, 'Mama.'\\""
            assert(nestedQuote2 != "My mother said, \\"The baby started talking today. The baby said, 'Mama.'\\"")
                   |            |  |
                   |            |  "My mother said, \\"The baby started talking today. The baby said, 'Mama.'\\""
                   |            false
                   "My mother said, \\"The baby started talking today. The baby said, 'Mama.'\\""
            assert(nestedQuote2 != "My mother said, \\"The baby started talking today. The baby said, 'Mama.'\\"")
                   |            |  |
                   |            |  "My mother said, \\"The baby started talking today. The baby said, 'Mama.'\\""
                   |            false
                   "My mother said, \\"The baby started talking today. The baby said, 'Mama.'\\""
            assert(helpText != "OPTIONS:\\n  --build-path\\t\\tSpecify build/cache directory [default: ./.build]")
                   |        |  |
                   |        |  "OPTIONS:\\n  --build-path\\t\\tSpecify build/cache directory [default: ./.build]"
                   |        false
                   "OPTIONS:\\n  --build-path\\t\\tSpecify build/cache directory [default: ./.build]"
            assert(nullCharacter != "Null character\\0Null character")
                   |             |  |
                   |             |  "Null character\\0Null character"
                   |             false
                   "Null character\\0Null character"
            assert(lineFeed != "Line feed\\nLine feed")
                   |        |  |
                   |        |  "Line feed\\nLine feed"
                   |        false
                   "Line feed\\nLine feed"
            assert(carriageReturn != "Carriage Return\\rCarriage Return")
                   |              |  |
                   |              |  "Carriage Return\\rCarriage Return"
                   |              false
                   "Carriage Return\\rCarriage Return"
            assert(backslash != "Backslash\\Backslash")
                   |         |  |
                   |         |  "Backslash\\Backslash"
                   |         false
                   "Backslash\\Backslash"
            assert(wiseWords != "\\"Imagination is more important than knowledge\\" - Einstein")
                   |         |  |
                   |         |  "\\"Imagination is more important than knowledge\\" - Einstein"
                   |         false
                   "\\"Imagination is more important than knowledge\\" - Einstein"
            assert(dollarSign != "$" )
                   |          |  |
                   "$"        |  "$"
                              false
            assert(blackHeart != "♥")
                   |          |  |
                   |          |  "♥"
                   |          false
                   "♥"
            assert(sparklingHeart != "💖")
                   |              |  |
                   |              |  "💖"
                   |              false
                   "💖"

            """

        let result = TestRunner().run(source: source)
        XCTAssertEqual(expected, result)
    }

    func testMultilineStringLiterals() {
        let source = """
            import XCTest

            class Tests: XCTestCase {
                func testMethod() {
                    let multilineLiteral = \"""
                        Lorem ipsum dolor sit amet, consectetur adipiscing elit,
                        sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.
                        \"""
                    assert(multilineLiteral != \"""
                        Lorem ipsum dolor sit amet, consectetur adipiscing elit,
                        sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.
                        \""")
                    assert(multilineLiteral != multilineLiteral)

                    let threeDoubleQuotationMarks = \"""
                        Escaping the first quotation mark \\\"""
                        Escaping all three quotation marks \\\"\\\"\\\"
                        \"""
                    assert(threeDoubleQuotationMarks != \"""
                        Escaping the first quotation mark \\\"""
                        Escaping all three quotation marks \\\"\\\"\\\"
                        \""")
                }
            }
            """

        let expected = """
            assert(multilineLiteral != "Lorem ipsum dolor sit amet, consectetur adipiscing elit,\\nsed do eiusmod tempor incididunt ut labore et dolore magna aliqua.")
                   |                |  |
                   |                |  "Lorem ipsum dolor sit amet, consectetur adipiscing elit,\\nsed do eiusmod tempor incididunt ut labore et dolore magna aliqua."
                   |                false
                   "Lorem ipsum dolor sit amet, consectetur adipiscing elit,\\nsed do eiusmod tempor incididunt ut labore et dolore magna aliqua."
            assert(multilineLiteral != multilineLiteral)
                   |                |  |
                   |                |  "Lorem ipsum dolor sit amet, consectetur adipiscing elit,\\nsed do eiusmod tempor incididunt ut labore et dolore magna aliqua."
                   |                false
                   "Lorem ipsum dolor sit amet, consectetur adipiscing elit,\\nsed do eiusmod tempor incididunt ut labore et dolore magna aliqua."
            assert(threeDoubleQuotationMarks != "Escaping the first quotation mark \\"\\"\\"\\nEscaping all three quotation marks \\"\\"\\"")
                   |                         |  |
                   |                         |  "Escaping the first quotation mark \\"\\"\\"\\nEscaping all three quotation marks \\"\\"\\""
                   |                         false
                   "Escaping the first quotation mark \\"\\"\\"\\nEscaping all three quotation marks \\"\\"\\""

            """

        let result = TestRunner().run(source: source)
        XCTAssertEqual(expected, result)
    }

    func testCustomOperator() {
        let source = """
            import XCTest

            infix operator ×: MultiplicationPrecedence
            func ×(left: Double, right: Double) -> Double {
                return left * right
            }

            prefix operator √
            prefix func √(number: Double) -> Double {
                return sqrt(number)
            }

            prefix operator √√
            prefix func √√(number: Double) -> Double {
                return sqrt(sqrt(number))
            }

            class Tests: XCTestCase {
                func testMethod() {
                    let number1 = 100.0
                    let number2 = 200.0
                    assert(number1 × number2 == 200.0)
                    assert(√number2 == 200.0)
                    assert(√√number2 == 200.0)
                    assert(200.0 == √√number2)
                    assert(√number2 == √√number2)
                }
            }
            """

        let expected = """
            assert(number1 × number2 == 200.0)
                   |       | |       |  |
                   100.0   | 200.0   |  200
                           20000.0   false
            assert(√number2 == 200.0)
                   ||       |  |
                   |200.0   |  200
                   |        false
                   14.142135623731
            assert(√√number2 == 200.0)
                   | |       |  |
                   | 200.0   |  200
                   |         false
                   3.76060309308639
            assert(200.0 == √√number2)
                   |     |  | |
                   200   |  | 200.0
                         |  3.76060309308639
                         false
            assert(√number2 == √√number2)
                   ||       |  | |
                   |200.0   |  | 200.0
                   |        |  3.76060309308639
                   |        false
                   14.142135623731

            """

        let result = TestRunner().run(source: source)
        XCTAssertEqual(expected, result)
    }

    func testNoWhitespaces() {
        let source = """
            import XCTest

            infix operator ×: MultiplicationPrecedence
            func ×(left: Double, right: Double) -> Double {
                return left * right
            }

            prefix operator √
            prefix func √(number: Double) -> Double {
                return sqrt(number)
            }

            prefix operator √√
            prefix func √√(number: Double) -> Double {
                return sqrt(sqrt(number))
            }

            class Tests: XCTestCase {
                func testMethod() {
                    let b1=false
                    let i1=0
                    let i2=1
                    let d1=4.0
                    let d2=6.0
                    assert(i2==4)
                    assert(b1==true&&i1>i2||true==b1&&i2==4)
                    assert(b1==true&&i1>i2||true==b1&&i2==4||d1×d2==1)
                }
            }
            """

        let expected = """
            assert(i2==4)
                   | | |
                   1 | 4
                     false
            assert(b1==true&&i1>i2||true==b1&&i2==4)
                   | | |   | | || | |   | | | | | |
                   | | |   | 0 |1 | |   | | | 1 | 4
                   | | |   |   |  | |   | | |   false
                   | | |   |   |  | |   | | false
                   | | |   |   |  | |   | false
                   | | |   |   |  | |   false
                   | | |   |   |  | true
                   | | |   |   |  false
                   | | |   |   false
                   | | |   false
                   | | true
                   | false
                   false
            assert(b1==true&&i1>i2||true==b1&&i2==4||d1×d2==1)
                   | | |   | | || | |   | | | | | || | || | |
                   | | |   | 0 |1 | |   | | | 1 | || | || | 1
                   | | |   |   |  | |   | | |   | || | || false
                   | | |   |   |  | |   | | |   | || | |6.0
                   | | |   |   |  | |   | | |   | || | 24.0
                   | | |   |   |  | |   | | |   | || 4.0
                   | | |   |   |  | |   | | |   | |false
                   | | |   |   |  | |   | | |   | 4
                   | | |   |   |  | |   | | |   false
                   | | |   |   |  | |   | | false
                   | | |   |   |  | |   | false
                   | | |   |   |  | |   false
                   | | |   |   |  | true
                   | | |   |   |  false
                   | | |   |   false
                   | | |   false
                   | | true
                   | false
                   false

            """

        let result = TestRunner().run(source: source)
        XCTAssertEqual(expected, result)
    }

    func testHigerOrderFunction() {
        let source = """
            import XCTest

            class Tests: XCTestCase {
                func testA(_ i: Int) -> Int {
                    return i + 1
                }

                func testB(_ i: Int) -> Int {
                    return i + 1
                }

                func testMethod() {
                    let array = [0, 1, 2]
                    assert(array.map { testA($0) } == [3, 4])
                    assert(array.map(testB) == [3, 4])
                }
            }
            """

        let expected = """
            assert(array.map { testA($0) } == [3, 4])
                   |     |                 |  ||  |
                   |     [1, 2, 3]         |  |3  4
                   [0, 1, 2]               |  [3, 4]
                                           false
            assert(array.map(testB) == [3, 4])
                   |     |   |      |  ||  |
                   |     |   |      |  |3  4
                   |     |   |      |  [3, 4]
                   |     |   |      false
                   |     |   (Function)
                   |     [1, 2, 3]
                   [0, 1, 2]

            """

        let result = TestRunner().run(source: source)
        XCTAssertEqual(expected, result)
    }
}
