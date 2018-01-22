public struct Country {
    public let code: String

    public init(code: String) {
        self.code = code.uppercased()
    }

    public var emojiFlag: String {
        return "\u{1f1f5}\u{1f1f7}"
    }
}
