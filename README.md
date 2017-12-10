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

Getting Started
---------------------------------------

Usage
---------------------------------------

Author
---------------------------------------
Kishikawa Katsumi, kishikawakatsumi@mac.com

License
---------------------------------------
SwiftPowerAssert is available under the Apache 2.0 license. See the LICENSE file for more info.
