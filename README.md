# SwiftPowerAssert

Power Assert in Swift. Provides descriptive assertion messages through standard assert interface.

[![Build Status](https://www.bitrise.io/app/05d5545de36d77a7/status.svg?token=2KUMgdXPKlzEiMPBRZzugg&branch=master)](https://www.bitrise.io/app/05d5545de36d77a7)
[![codecov](https://codecov.io/gh/kishikawakatsumi/SwiftPowerAssert/branch/master/graph/badge.svg)](https://codecov.io/gh/kishikawakatsumi/SwiftPowerAssert)

Description
---------------------------------------

What is `SwiftPowerAssert`?

 * is an implementation of "Power Assert" concept in Swift.
 * provides descriptive assertion messages through simple interface.
 * With `SwiftPowerAssert`, __you don't need to learn many assertion library APIs__ (in most cases, all you need to remember is just an `assert(any_expression)` function)
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

Installation
---------------------------------------

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

Copy the file (`.build/x86_64-apple-macosx10.10/release/swift-power-assert`) to your binary location.

Getting Started
---------------------------------------

Replace `xcodebuild test...` command with `swift-power-assert test`

Note: SwiftPowerAssert injects instrument code into the `XCTAssert()` methods during tests. SwiftPowerAssert back up the source files before executing tests and restore automatically when the tests finished. However, the original files may not be restored due to an unexpected crash or something wrong. Please use it for the project under Git.

Usage
---------------------------------------

If you are using `xcodebuild test` command, add `swift-power-assert xctest -X` before like the following.

```shell
/path/to/swift-power-assert xctest -Xxcodebuild test -workspace <workspacename> -scheme <schemeName> -sdk iphonesimulator -destination "name=iPhone X,OS=11.2"
```

If you are using `swift test`, like the following.

```shell
/path/to/swift-power-assert test -Xswift test
```

```shell
/path/to/swift-power-assert test -Xswift test -c release
```

Nothing happens? If the test succeeds, nothing is output. If you always want to see rich ASCII art, enable the `--verbose` option. always output a diagram regardless of the success or failure of assertions.

```shell
/path/to/swift-power-assert --verbose xctest -Xxcodebuild test -workspace <workspacename> -scheme <schemeName> -sdk iphonesimulator -destination "name=iPhone X,OS=11.2"
```

```shell
/path/to/swift-power-assert --verbose test -Xswift test
```

Author
---------------------------------------
Kishikawa Katsumi, kishikawakatsumi@mac.com

License
---------------------------------------
SwiftPowerAssert is available under the Apache 2.0 license. See the LICENSE file for more info.
