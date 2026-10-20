import Foundation
import Testing
@testable import BlePocSwiftApp

struct BytesTests {
    @Test(arguments: ["01 02 0a", "01020a", "0x01 0x02 0x0a"])
    func parsesHex(_ text: String) throws {
        #expect(try Data(hex: text) == Data([1, 2, 10]))
    }

    @Test(arguments: ["012", "zz"])
    func rejectsBadHex(_ text: String) {
        #expect(throws: InvalidInput.self) { try Data(hex: text) }
    }

    @Test func parsesText() throws {
        #expect(try Data("hi", format: .utf8) == Data("hi".utf8))
    }

    @Test func displays() {
        #expect(Data().display() == "(empty)")
        #expect(Data([0x2a, 0, 0, 0]).display(asCounter: true) == "2a 00 00 00 = 42")
        #expect(Data("hi".utf8).display() == "68 69 \"hi\"")
        #expect(Data([0x00, 0xff]).display() == "00 ff")
    }
}
