# Power Assertions for Swift

[![Build Status](https://www.bitrise.io/app/05d5545de36d77a7/status.svg?token=2KUMgdXPKlzEiMPBRZzugg&branch=master)](https://www.bitrise.io/app/05d5545de36d77a7)
[![codecov](https://codecov.io/gh/kishikawakatsumi/SwiftPowerAssert/branch/master/graph/badge.svg)](https://codecov.io/gh/kishikawakatsumi/SwiftPowerAssert)

Power assertions (a.k.a. diagrammed assertions) augment your assertion failures with information about values produced during the evaluation of a condition, and presents them in an easily digestible form.
Power assertions are a popular feature of [Spock](https://github.com/spockframework/spock) (and later the whole [Groovy](https://github.com/apache/groovy) language independently of Spock),
[ScalaTest](http://www.scalatest.org/), and [Expecty](https://github.com/pniederw/expecty).

Power assertions provide descriptive assertion messages for your tests, like this.

    XCTAssert(max(a, b) == c)
              |   |  |  |  |
              7   4  7  |  12
                        false

    XCTAssert(xs.contains(4))
              |  |        |
              |  false    4
              [1, 2, 3]

    XCTAssert("hello".hasPrefix("h") && "goodbye".hasSuffix("y"))
              |       |         |    |  |         |         |
              "hello" true      "h"  |  "goodbye" false     "y"
                                     false

Online Playground
---------------------------------------

Live demo for SwiftPowerAssert

https://swift-power-assert.kishikawakatsumi.com/

<img width="1289" alt="screen shot 2018-01-23 at 0 13 28" src="https://user-images.githubusercontent.com/40610/35227801-677a0b20-ffd2-11e7-80bf-fe8acf56ecd7.png">


Installation
---------------------------------------

```shell
git clone https://github.com/kishikawakatsumi/SwiftPowerAssert
```

```shell
cd SwiftPowerAssert
```

```shell
swift build -c release
```

Copy the file (`.build/release/swift-power-assert`) to your binary location.

Getting Started
---------------------------------------

### For XCTest

Replace `xcodebuild test...` command with `swift-power-assert xctest -Xxcodebuild test ...`

```shell
/path/to/swift-power-assert xctest -Xxcodebuild test -scheme Atlas-Package
```

### For swift test

Replace `swift test...` command with `swift-power-assert test -Xswift test ...`

```shell
/path/to/swift-power-assert test -Xswift test
```

Note: SwiftPowerAssert injects instrument code into the family of `XCTAssert()` methods during tests. SwiftPowerAssert back up the source files before executing tests and restore automatically when the tests finished. However, the original files may not be restored due to an unexpected crash or something wrong. Please use it for the project under Git.

Usage
---------------------------------------

```
USAGE: swift-power-assert [options] subcommand [options]

OPTIONS:
  --verbose   Show more debugging information
  --help      Display available options

SUBCOMMANDS:
  test        Run swift test with power assertion
  xctest      Run XCTest with power assertion.
```

You can pass any `xcodebuild` or `swift` options after `-Xxcodebuild` or `-Xswift`.

```shell
/path/to/swift-power-assert xctest -Xxcodebuild test -project Atlas.xcodeproj -scheme Atlas-Package \
 -sdk iphonesimulator -destination "name=iPhone X,OS=11.2"
```

```shell
/path/to/swift-power-assert test -Xswift test -c release -Xswiftc -enable-testing
```

Nothing happens? If the test succeeds, nothing is output. If you always want to see rich ASCII art, enable the `--verbose` option. always output a diagram regardless of the success or failure of assertions.

```shell
/path/to/swift-power-assert --verbose xctest -Xxcodebuild test -project Atlas.xcodeproj -scheme Atlas-Package
```

```shell
/path/to/swift-power-assert --verbose test -Xswift test
```

Examples
---------------------------------------

```swift
let a = 10
let b = 9
XCTAssert(a * b == 91)

// Output:
// XCTAssert(a * b == 91)
//           | | | |  |
//           | | 9 |  91
//           | 90  false
//           10
```

```swift
let xs = [1, 2, 3]
XCTAssert(xs.contains(4))

// Output:
// XCTAssert(xs.contains(4))
//           |  |        |
//           |  false    4
//           [1, 2, 3]
```

```swift
XCTAssert("hello".hasPrefix("h") && "goodbye".hasSuffix("y"))

// Output:
// XCTAssert("hello".hasPrefix("h") && "goodbye".hasSuffix("y"))
//           |       |         |    |  |         |         |
//           "hello" true      "h"  |  "goodbye" false     "y"
//                                  false
```

```swift
let d = 4
let e = 7
let f = 12

XCTAssert(max(d, e) == f)
XCTAssert(d + e > f)

// Output:
// XCTAssert(max(d, e) == f)
//           |   |  |  |  |
//           7   4  7  |  12
//                     false
// XCTAssert(d + e > f)
//           | | | | |
//           4 | 7 | 12
//             11  false
```

```swift
struct Person {
  let name: String
  let age: Int

  var isTeenager: Bool {
    return age <= 12 && age >= 20
  }
}

let john = Person(name: "John", age: 42)
let mike = Person(name: "Mike", age: 13)

XCTAssert(john.isTeenager)
XCTAssert(mike.isTeenager && john.age < mike.age)

// Output:
// XCTAssert(john.isTeenager)
//           |    |
//           |    false
//           Person(name: "John", age: 42)
// XCTAssert(mike.isTeenager && john.age < mike.age)
//           |    |          |  |    |   | |    |
//           |    false      |  |    42  | |    13
//           |               |  |        | Person(name: "Mike", age: 13)
//           |               |  |        false
//           |               |  Person(name: "John", age: 42)
//           |               false
//           Person(name: "Mike", age: 13)
```

Author
---------------------------------------
Kishikawa Katsumi, kishikawakatsumi@mac.com

License
---------------------------------------
SwiftPowerAssert is available under the Apache 2.0 license. See the LICENSE file for more info.
