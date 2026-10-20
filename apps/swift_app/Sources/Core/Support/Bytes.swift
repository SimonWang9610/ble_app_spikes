import Foundation

enum ValueFormat: String, CaseIterable, Identifiable {
    case hex, utf8
    var id: Self { self }
}

struct InvalidInput: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

extension Data {
    /// "01 02 0a"
    var hex: String { map { String(format: "%02x", $0) }.joined(separator: " ") }

    var utf8Text: String? { String(data: self, encoding: .utf8) }

    /// "2a 00 00 00 = 42" for 4-byte counters, "68 69 "hi"" for plain text, hex otherwise.
    func display(asCounter: Bool = false) -> String {
        guard !isEmpty else { return "(empty)" }
        if asCounter, count == 4 {
            let n = enumerated().reduce(UInt32(0)) { $0 | UInt32($1.element) << (8 * $1.offset) }
            return "\(hex) = \(n)"
        }
        if let text = utf8Text, text.allSatisfy({ $0.isASCII && !$0.isNewline && ($0.isLetter || $0.isNumber || $0.isPunctuation || $0.isSymbol || $0 == " ") }) {
            return "\(hex) \"\(text)\""
        }
        return hex
    }

    /// Parses "01 02 0a", "01020a" or "0x01 0x02".
    init(hex text: String) throws {
        let digits = text.replacingOccurrences(of: "0x", with: "").filter { !$0.isWhitespace }
        guard digits.count.isMultiple(of: 2) else { throw InvalidInput(message: "odd number of hex digits") }
        var bytes: [UInt8] = []
        var index = digits.startIndex
        while index < digits.endIndex {
            let next = digits.index(index, offsetBy: 2)
            guard let byte = UInt8(digits[index..<next], radix: 16) else {
                throw InvalidInput(message: "not hex: \(digits[index..<next])")
            }
            bytes.append(byte)
            index = next
        }
        self.init(bytes)
    }

    init(_ text: String, format: ValueFormat) throws {
        switch format {
        case .hex: try self.init(hex: text)
        case .utf8: self.init(text.utf8)
        }
    }
}
