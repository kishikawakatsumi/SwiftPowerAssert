# SwiftPowerAssert

Power Assert in Swift. Provides descriptive assertion messages through standard assert interface. No API is the best API.

Description
---------------------------------------

What is `SwiftPowerAssert`?

 * is an implementation of "Power Assert" concept in Swift.
 * provides descriptive assertion messages through simple interface.
 * __No API is the best API__. With `SwiftPowerAssert`, __you don't need to learn many assertion library APIs__ (in most cases, all you need to remember is just an `assert(any_expression)` function)
 * __Stop memorizing tons of assertion APIs. Just create expressions that return a truthy value or not__ and power-assert will show it to you right on the screen as part of your failure message without you having to type in a message at all.
 * pull-requests, issue reports and patches are always welcomed.


`power-assert` provides descriptive assertion messages for your tests, like this.

        assert(bar.val == bar.foo.val)
               |   |      |   |   |
               |   3      |   |   2
               |          |   Foo(val: 2)
               |          Bar(foo: main.Foo(val: 2), val: 3)
               Bar(foo: main.Foo(val: 2), val: 3)

### A Work In Progress
SwiftPowerAssert is still in active development. Many expressions are unsupported and very unstable.

Requirements
---------------------------------------
SwiftPowerAssert requires [Swift 4.1 toolchains](https://swift.org/download/#snapshots).

Installation
---------------------------------------
Download and install [the latest trunk Swift development toolchain](https://swift.org/download/#snapshots).

```shell
git clone https://github.com/kishikawakatsumi/SwiftPowerAssert
```

```shell
cd SwiftPowerAssert
```

```shell
~/Library/Developer/Toolchains/swift-latest.xctoolchain/usr/bin/swift package update
```

```shell
~/Library/Developer/Toolchains/swift-latest.xctoolchain/usr/bin/swift build -c release
```

Copy the file (`.build/x86_64-apple-macosx10.10/release/SwiftPowerAssert`) to your binary location.

Getting Started
---------------------------------------

SwiftPowerAssert injects instrument code into the `assert()` methods. There is no automatic mechanism to hook the compiler in Xcode unfortunately, so setup it manually using "Run Script Phase."

<img src='https://user-images.githubusercontent.com/40610/33810940-3b62ae9c-de4f-11e7-9c0d-43fa9d705fcc.png' alt='Pre/Post build actions'>

Instrument the source code with `SwiftPowerAssert instrument ...` command.

Note: Back up the source files to a temporary directory to restore after compilation.

```shell
cp -R "${SRCROOT%/}/Tests" $TMPDIR

/path/to/SwiftPowerAssert instrument "${SRCROOT%/}/Tests"
```

Restore the original source files from backup after compilation.

```shell
cp -R "${TMPDIR%/}/Tests" "$SRCROOT"
```

Usage
---------------------------------------
Inject an instrument code into the `*.swift` files in the specified directory.

```shell
/path/to/SwiftPowerAssert instrument file_or_directory
```

Replace `XCTAsertXXX()` methods with `assert()`.

| XCTest        | SwiftPowerAssert|
| ------------- |-------------|
| `XCTAssertEqual(username, "kishikawakatsumi")` |`assert(username == "kishikawakatsumi")` |
| `XCTAssertEqual(bar.val, bar.foo.val)`         |`assert(bar.val == bar.foo.val)`         |
| `XCTAssertNil(error)`                          |`assert(error == nil)`                   |

Author
---------------------------------------
Kishikawa Katsumi, kishikawakatsumi@mac.com

License
---------------------------------------
SwiftPowerAssert is available under the Apache 2.0 license. See the LICENSE file for more info.
