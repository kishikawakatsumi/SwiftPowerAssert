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

var generatedCode = """
    //===----------------------------------------------------------------------===//
    // Automatically Generated From Tools/GenerateUtilities.swift
    //===----------------------------------------------------------------------===//

    import Foundation

    public class __DisplayWidth {
        public static func of(_ s: String, inEastAsian: Bool = false) -> Int {
            return s.unicodeScalars.reduce(0) { $0 + of($1, inEastAsian: inEastAsian) }
        }

        private static func of(_ s: UnicodeScalar, inEastAsian: Bool) -> Int {
            switch s.value {
    \(cases)        default: return 1
            }
        }
    }

    """

generatedCode = """
    \(generatedCode)
    extension __DisplayWidth {
        public static var myself: String {
            let myself = \"\"\"
    \(generatedCode.split(separator: "\n").map { String(repeating: " ", count: 4 * 3) + $0 }.joined(separator: "\n"))
                \"\"\"
            return myself
        }
    }

    """

try! generatedCode.write(to: URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().appendingPathComponent("../Sources/SwiftPowerAssertCore/Utilities.swift"), atomically: true, encoding: .utf8)
