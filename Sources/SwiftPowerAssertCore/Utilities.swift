//===----------------------------------------------------------------------===//
// Automatically Generated From Tools/generate-utils
//===----------------------------------------------------------------------===//

import Foundation
#if os(macOS)
import AppKit
#else
import UIKit
#endif

public struct __Util {}
extension __Util {
    #if os(macOS)
    static let font = NSFont(name: "Osaka-Mono", size: 26)!
    static let size = NSSize(width: Int.max, height: Int.max)
    #else
    static let font = UIFont(name: "Osaka-Mono", size: 26)!
    static let size = CGSize(width: Int.max, height: Int.max)
    #endif
    static let attributes = [NSAttributedStringKey.font : font]
    static let xWidth = NSString(string: "x").boundingRect(with: size, options: [], attributes: attributes).width
    public static func displayWidth(of s: String) -> Int {
        return Int(NSString(string: s).boundingRect(with: size, options: [], attributes: attributes).width / xWidth)
    }
}
extension __Util {
    public static var source: String {
        let source = """
            //===----------------------------------------------------------------------===//
            // Automatically Generated From Tools/generate-utils
            //===----------------------------------------------------------------------===//
            import Foundation
            #if os(macOS)
            import AppKit
            #else
            import UIKit
            #endif
            public struct __Util {}
            import XCTest
            extension __Util {
                #if os(macOS)
                static let font = NSFont(name: "Osaka-Mono", size: 26)!
                static let size = NSSize(width: Int.max, height: Int.max)
                #else
                static let font = UIFont(name: "Osaka-Mono", size: 26)!
                static let size = CGSize(width: Int.max, height: Int.max)
                #endif
                static let attributes = [NSAttributedStringKey.font : font]
                static let xWidth = NSString(string: "x").boundingRect(with: size, options: [], attributes: attributes).width
                public static func displayWidth(of s: String) -> Int {
                    return Int(NSString(string: s).boundingRect(with: size, options: [], attributes: attributes).width / xWidth)
                }
            }
            extension __Util {
                static func escapeString(_ s: String) -> String {
                    return s
                        .replacingOccurrences(of: "\\"", with: "\\\\\\"")
                        .replacingOccurrences(of: "\\t", with: "\\\\t")
                        .replacingOccurrences(of: "\\r", with: "\\\\r")
                        .replacingOccurrences(of: "\\n", with: "\\\\n")
                        .replacingOccurrences(of: "\\0", with: "\\\\0")
                }
                static func valueToString<T>(_ value: T?) -> String {
                    switch value {
                    case .some(let v) where v is String || v is Selector: return "\\"\\(__Util.escapeString("\\(v)"))\\""
                    case .some(let v): return "\\(v)".replacingOccurrences(of: "\\n", with: " ")
                    case .none: return "nil"
                    }
                }
                static func align(_ message: inout String, current: inout Int, column: Int, string: String) {
                    while current < column - 1 {
                        message += " "
                        current += 1
                    }
                    message += string
                    current += __Util.displayWidth(of: string)
                }
            }
            class __ValueRecorder {
                let assertion: String
                let lineNumber: UInt
                let verbose: Bool
                let inUnitTests: Bool
                var result = true
                var originalMessage = ""
                var values = [__Value]()
                var errors = [Swift.Error]()
                init(assertion: String, lineNumber: UInt, verbose: Bool = false, inUnitTests: Bool = false) {
                    self.assertion = assertion
                    self.lineNumber = lineNumber
                    self.verbose = verbose
                    self.inUnitTests = inUnitTests
                }
                func assertBoolean(_ expression: @autoclosure () throws -> Bool, _ message: @autoclosure () -> String = "", file: StaticString = #file, line: UInt = #line, op: (Bool, Bool) -> Bool) -> __ValueRecorder {
                    do {
                        let value = try expression()
                        result = op(value, true)
                    } catch {
                        errors.append(error)
                    }
                    return self
                }
                func assertEquality<T>(_ expression1: @autoclosure () throws -> T, _ expression2: @autoclosure () throws -> T, _ message: @autoclosure () -> String = "", file: StaticString = #file, line: UInt = #line, op: (Bool, Bool) -> Bool) -> __ValueRecorder where T: Equatable {
                    do {
                        let (lhs, rhs) = (try expression1(), try expression2())
                        result = op(lhs == rhs, true)
                    } catch {
                        errors.append(error)
                    }
                    return self
                }
                func assertEquality<T>(_ expression1: @autoclosure () throws -> T?, _ expression2: @autoclosure () throws -> T?, _ message: @autoclosure () -> String = "", file: StaticString = #file, line: UInt = #line, op: (Bool, Bool) -> Bool) -> __ValueRecorder where T: Equatable {
                    do {
                        let (lhs, rhs) = (try expression1(), try expression2())
                        result = op(lhs == rhs, true)
                    } catch {
                        errors.append(error)
                    }
                    return self
                }
                func assertEquality<T>(_ expression1: @autoclosure () throws -> [T], _ expression2: @autoclosure () throws -> [T], _ message: @autoclosure () -> String = "", file: StaticString = #file, line: UInt = #line, op: (Bool, Bool) -> Bool) -> __ValueRecorder where T: Equatable {
                    do {
                        let (lhs, rhs) = (try expression1(), try expression2())
                        result = op(lhs == rhs, true)
                    } catch {
                        errors.append(error)
                    }
                    return self
                }
                func assertEquality<T>(_ expression1: @autoclosure () throws -> ArraySlice<T>, _ expression2: @autoclosure () throws -> ArraySlice<T>, _ message: @autoclosure () -> String = "", file: StaticString = #file, line: UInt = #line, op: (Bool, Bool) -> Bool) -> __ValueRecorder where T: Equatable {
                    do {
                        let (lhs, rhs) = (try expression1(), try expression2())
                        result = op(lhs == rhs, true)
                    } catch {
                        errors.append(error)
                    }
                    return self
                }
                func assertEquality<T>(_ expression1: @autoclosure () throws -> ContiguousArray<T>, _ expression2: @autoclosure () throws -> ContiguousArray<T>, _ message: @autoclosure () -> String = "", file: StaticString = #file, line: UInt = #line, op: (Bool, Bool) -> Bool) -> __ValueRecorder where T: Equatable {
                    do {
                        let (lhs, rhs) = (try expression1(), try expression2())
                        result = op(lhs == rhs, true)
                    } catch {
                        errors.append(error)
                    }
                    return self
                }
                func assertEquality<T, U>(_ expression1: @autoclosure () throws -> [T: U], _ expression2: @autoclosure () throws -> [T: U], _ message: @autoclosure () -> String = "", file: StaticString = #file, line: UInt = #line, op: (Bool, Bool) -> Bool) -> __ValueRecorder where U : Equatable {
                    do {
                        let (lhs, rhs) = (try expression1(), try expression2())
                        result = op(lhs == rhs, true)
                    } catch {
                        errors.append(error)
                    }
                    return self
                }
                func assertComparable<T>(_ expression1: @autoclosure () throws -> T, _ expression2: @autoclosure () throws -> T, _ message: @autoclosure () -> String = "", file: StaticString = #file, line: UInt = #line, op: (T, T) -> Bool) -> __ValueRecorder where T: Comparable {
                    do {
                        let (lhs, rhs) = (try expression1(), try expression2())
                        result = op(lhs, rhs)
                    } catch {
                        errors.append(error)
                    }
                    return self
                }
                func assertNil(_ expression: @autoclosure () throws -> Any?, _ message: @autoclosure () -> String = "", file: StaticString = #file, line: UInt = #line, op: (Bool, Bool) -> Bool) -> __ValueRecorder {
                    do {
                        let value = try expression()
                        result = op(value == nil, true)
                    } catch {
                        errors.append(error)
                    }
                    return self
                }
                func record<T>(expression: @autoclosure () throws -> T?, column: Int) -> __ValueRecorder {
                    do {
                        values.append(__Value(value: __Util.valueToString(try expression()), column: column))
                    } catch {
                        errors.append(error)
                    }
                    return self
                }
                func render() {
                    if !result || verbose {
                        var message = ""
                        message += "\\(assertion)\\n"
                        values.sort()
                        var current = 0
                        for value in values {
                            __Util.align(&message, current: &current, column: value.column, string: "|")
                        }
                        message += "\\n"
                        while !values.isEmpty {
                            var current = 0
                            var index = 0
                            while index < values.count {
                                if index == values.count - 1 || ((values[index].column + values[index].value.count < values[index + 1].column) && values[index].value.unicodeScalars.filter({ !$0.isASCII }).isEmpty) {
                                    __Util.align(&message, current: &current, column: values[index].column, string: values[index].value)
                                    values.remove(at: index)
                                } else {
                                    __Util.align(&message, current: &current, column: values[index].column, string: "|")
                                    index += 1
                                }
                            }
                            message += "\\n"
                        }
                        if verbose || inUnitTests {
                            print(message, terminator: "")
                        }
                        if !result && !inUnitTests {
                            XCTFail("\\(originalMessage)\\n" + message, line: lineNumber)
                        }
                    }
                }
            }
            struct __Value {
                let value: String
                let column: Int
            }
            extension __Value: Comparable {
                static func <(lhs: __Value, rhs: __Value) -> Bool {
                    return lhs.column < rhs.column
                }
                static func ==(lhs: __Value, rhs: __Value) -> Bool {
                    return lhs.column == rhs.column
                }
            }
            """
        return source
    }
}
