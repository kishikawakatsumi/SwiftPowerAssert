#!/usr/bin/env xcrun swift

import Foundation

var cases = ""

let data = try! String(contentsOf: URL(string: "https://www.unicode.org/Public/UNIDATA/EastAsianWidth.txt")!)
data.enumerateLines { (line, stop) in
    let commentRemoved = line.replacingOccurrences(of: "\\#.*", with: "", options: .regularExpression)

    let regex = try! NSRegularExpression(pattern: "([0-9a-fA-F]+)\\.\\.([0-9a-fA-F]+);([a-zA-Z]+)")
    let result = regex.firstMatch(in: commentRemoved, range: NSRange(commentRemoved.startIndex..., in: commentRemoved))
    if let result = result {
        let from = String(commentRemoved[Range(result.range(at: 1), in: commentRemoved)!])
        let to = String(commentRemoved[Range(result.range(at: 2), in: commentRemoved)!])
        let property = String(commentRemoved[Range(result.range(at: 3), in: commentRemoved)!])

        switch property {
        case "F", "W": cases += "        case 0x\(from)...0x\(to): return 2\n"
        case "A": cases += "        case 0x\(from)...0x\(to): return inEastAsian ? 2 : 1\n"
        default: break
        }
    } else {
        let regex = try! NSRegularExpression(pattern: "([0-9a-fA-F]+);([a-zA-Z]+)")
        let result = regex.firstMatch(in: commentRemoved, range: NSRange(commentRemoved.startIndex..., in: commentRemoved))
        if let result = result {
            let codePoint = String(commentRemoved[Range(result.range(at: 1), in: commentRemoved)!])
            let property = String(commentRemoved[Range(result.range(at: 2), in: commentRemoved)!])

            switch property {
            case "F", "W": cases += "        case 0x\(codePoint): return 2\n"
            case "A": cases += "        case 0x\(codePoint): return inEastAsian ? 2 : 1\n"
            default: break
            }
        }
    }
}

var header = """
    //===----------------------------------------------------------------------===//
    // Automatically Generated From Tools/GenerateUtilities.swift
    //===----------------------------------------------------------------------===//

    import Foundation

    public struct __Util {}

    """

var displayWidth = """
    extension __Util {
        public static func displayWidth(of s: String, inEastAsian: Bool = false) -> Int {
            return s.unicodeScalars.reduce(0) { $0 + displayWidth(of: $1, inEastAsian: inEastAsian) }
        }
        private static func displayWidth(of s: UnicodeScalar, inEastAsian: Bool) -> Int {
            switch s.value {
    \(cases)        default: return 1
            }
        }
    }

    """

var helperFunctions = """
    extension __Util {
        static func equal(_ parameters: (Bool)) -> Bool {
            return parameters
        }
        static func equal(_ parameters: (condition: Bool, message: String)) -> Bool {
            return parameters.condition
        }
        static func equal<T>(_ parameters: (lhs: T, rhs: T)) -> Bool where T: Equatable {
            return parameters.lhs == parameters.rhs
        }
        static func equal<T>(_ parameters: (lhs: T, rhs: T, message: String)) -> Bool where T: Equatable {
            return equal((parameters.lhs, parameters.rhs))
        }
        static func equal<T>(_ parameters: (lhs: T, rhs: T, message: String, file: StaticString)) -> Bool where T: Equatable {
            return equal((parameters.lhs, parameters.rhs))
        }
        static func equal<T>(_ parameters: (lhs: T, rhs: T, message: String, file: StaticString, line: UInt)) -> Bool where T: Equatable {
            return equal((parameters.lhs, parameters.rhs))
        }
        static func equal<T>(_ parameters: (lhs: T?, rhs: T?)) -> Bool where T: Equatable {
            return parameters.lhs == parameters.rhs
        }
        static func equal<T>(_ parameters: (lhs: T?, rhs: T?, message: String)) -> Bool where T: Equatable {
            return equal((parameters.lhs, parameters.rhs))
        }
        static func equal<T>(_ parameters: (lhs: T?, rhs: T?, message: String, file: StaticString)) -> Bool where T: Equatable {
            return equal((parameters.lhs, parameters.rhs))
        }
        static func equal<T>(_ parameters: (lhs: T?, rhs: T?, message: String, file: StaticString, line: UInt)) -> Bool where T: Equatable {
            return equal((parameters.lhs, parameters.rhs))
        }
        static func equal<T>(_ parameters: (lhs: [T], rhs: [T])) -> Bool where T: Equatable {
            return parameters.lhs == parameters.rhs
        }
        static func equal<T>(_ parameters: (lhs: [T], rhs: [T], message: String)) -> Bool where T: Equatable {
            return equal((parameters.lhs, parameters.rhs))
        }
        static func equal<T>(_ parameters: (lhs: [T], rhs: [T], message: String, file: StaticString)) -> Bool where T: Equatable {
            return equal((parameters.lhs, parameters.rhs))
        }
        static func equal<T>(_ parameters: (lhs: [T], rhs: [T], message: String, file: StaticString, line: UInt)) -> Bool where T: Equatable {
            return equal((parameters.lhs, parameters.rhs))
        }
        static func equal<T>(_ parameters: (lhs: ArraySlice<T>, rhs: ArraySlice<T>)) -> Bool where T: Equatable {
            return parameters.lhs == parameters.rhs
        }
        static func equal<T>(_ parameters: (lhs: ArraySlice<T>, rhs: ArraySlice<T>, message: String)) -> Bool where T: Equatable {
            return equal((parameters.lhs, parameters.rhs))
        }
        static func equal<T>(_ parameters: (lhs: ArraySlice<T>, rhs: ArraySlice<T>, message: String, file: StaticString)) -> Bool where T: Equatable {
            return equal((parameters.lhs, parameters.rhs))
        }
        static func equal<T>(_ parameters: (lhs: ArraySlice<T>, rhs: ArraySlice<T>, message: String, file: StaticString, line: UInt)) -> Bool where T: Equatable {
            return equal((parameters.lhs, parameters.rhs))
        }
        static func equal<T>(_ parameters: (lhs: ContiguousArray<T>, rhs: ContiguousArray<T>)) -> Bool where T: Equatable {
            return parameters.lhs == parameters.rhs
        }
        static func equal<T>(_ parameters: (lhs: ContiguousArray<T>, rhs: ContiguousArray<T>, message: String)) -> Bool where T: Equatable {
            return equal((parameters.lhs, parameters.rhs))
        }
        static func equal<T>(_ parameters: (lhs: ContiguousArray<T>, rhs: ContiguousArray<T>, message: String, file: StaticString)) -> Bool where T: Equatable {
            return equal((parameters.lhs, parameters.rhs))
        }
        static func equal<T>(_ parameters: (lhs: ContiguousArray<T>, rhs: ContiguousArray<T>, message: String, file: StaticString, line: UInt)) -> Bool where T: Equatable {
            return equal((parameters.lhs, parameters.rhs))
        }
        static func equal<T, U>(_ parameters: (lhs: [T: U], rhs: [T: U])) -> Bool where U: Equatable {
            return parameters.lhs == parameters.rhs
        }
        static func equal<T, U>(_ parameters: (lhs: [T: U], rhs: [T: U], message: String)) -> Bool where U: Equatable {
            return equal((parameters.lhs, parameters.rhs))
        }
        static func equal<T, U>(_ parameters: (lhs: [T: U], rhs: [T: U], message: String, file: StaticString)) -> Bool where U: Equatable {
            return equal((parameters.lhs, parameters.rhs))
        }
        static func equal<T, U>(_ parameters: (lhs: [T: U], rhs: [T: U], message: String, file: StaticString, line: UInt)) -> Bool where U: Equatable {
            return equal((parameters.lhs, parameters.rhs))
        }
        static func greaterThan<T>(_ parameters: (lhs: T, rhs: T)) -> Bool where T: Comparable {
            return parameters.lhs > parameters.rhs
        }
        static func greaterThan<T>(_ parameters: (lhs: T, rhs: T, message: String)) -> Bool where T: Comparable {
            return greaterThan((parameters.lhs, parameters.rhs))
        }
        static func greaterThan<T>(_ parameters: (lhs: T, rhs: T, message: String, file: StaticString)) -> Bool where T: Comparable {
            return greaterThan((parameters.lhs, parameters.rhs))
        }
        static func greaterThan<T>(_ parameters: (lhs: T, rhs: T, message: String, file: StaticString, line: UInt)) -> Bool where T: Comparable {
            return greaterThan((parameters.lhs, parameters.rhs))
        }
        static func greaterThanOrEqual<T>(_ parameters: (lhs: T, rhs: T)) -> Bool where T: Comparable {
            return parameters.lhs >= parameters.rhs
        }
        static func greaterThanOrEqual<T>(_ parameters: (lhs: T, rhs: T, message: String)) -> Bool where T: Comparable {
            return greaterThanOrEqual((parameters.lhs, parameters.rhs))
        }
        static func greaterThanOrEqual<T>(_ parameters: (lhs: T, rhs: T, message: String, file: StaticString)) -> Bool where T: Comparable {
            return greaterThanOrEqual((parameters.lhs, parameters.rhs))
        }
        static func greaterThanOrEqual<T>(_ parameters: (lhs: T, rhs: T, message: String, file: StaticString, line: UInt)) -> Bool where T: Comparable {
            return greaterThanOrEqual((parameters.lhs, parameters.rhs))
        }
        static func `nil`(_ parameters: (Any?)) -> Bool {
            return parameters == nil
        }
        static func `nil`(_ parameters: (condition: Any?, message: String)) -> Bool {
            return parameters.condition == nil
        }
        static func value(_ value: String) -> String {
            return value
                .replacingOccurrences(of: "\\\\"", with: "\\\\\\\\\\\\"")
                .replacingOccurrences(of: "\\\\t", with: "\\\\\\\\t")
                .replacingOccurrences(of: "\\\\r", with: "\\\\\\\\r")
                .replacingOccurrences(of: "\\\\n", with: "\\\\\\\\n")
                .replacingOccurrences(of: "\\\\0", with: "\\\\\\\\0")
        }
        static func toString<T>(_ value: T?) -> String {
            switch value {
            case .some(let v) where v is String || v is Selector: return "\\\\"\\\\(__Util.value("\\\\(v)"))\\\\""
            case .some(let v): return "\\\\(v)".replacingOccurrences(of: "\\\\n", with: " ")
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

    """

let sourceCode = header + displayWidth + """
    extension __Util {
        public static var source: String {
            let source = \"\"\"
    \((header + displayWidth + helperFunctions).split(separator: "\n").map { String(repeating: " ", count: 4 * 3) + $0 }.joined(separator: "\n"))
                \"\"\"
            return source
        }
    }

    """

try! sourceCode.write(to: URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().appendingPathComponent("../Sources/SwiftPowerAssertCore/Utilities.swift"), atomically: true, encoding: .utf8)
