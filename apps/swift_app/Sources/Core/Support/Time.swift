import Foundation

extension Duration {
    var seconds: Double { Double(components.seconds) + Double(components.attoseconds) / 1e18 }
}

extension Double {
    /// "7.3"
    var oneDecimal: String { formatted(.number.precision(.fractionLength(1))) }
}
