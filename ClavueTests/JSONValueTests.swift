import Testing
import Foundation
@testable import Clavue

struct JSONValueTests {

    // MARK: - Decoding

    @Test func decodesString() throws {
        let json = Data(#""hello""#.utf8)
        let value = try JSONDecoder().decode(JSONValue.self, from: json)
        #expect(value.stringValue == "hello")
    }

    @Test func decodesNumber() throws {
        let json = Data("42.5".utf8)
        let value = try JSONDecoder().decode(JSONValue.self, from: json)
        guard case .number(let n) = value else {
            Issue.record("Expected .number"); return
        }
        #expect(n == 42.5)
    }

    @Test func decodesBool() throws {
        let json = Data("true".utf8)
        let value = try JSONDecoder().decode(JSONValue.self, from: json)
        guard case .bool(let b) = value else {
            Issue.record("Expected .bool"); return
        }
        #expect(b == true)
    }

    @Test func decodesNull() throws {
        let json = Data("null".utf8)
        let value = try JSONDecoder().decode(JSONValue.self, from: json)
        guard case .null = value else {
            Issue.record("Expected .null"); return
        }
    }

    @Test func decodesArray() throws {
        let json = Data(#"[1,"two",true]"#.utf8)
        let value = try JSONDecoder().decode(JSONValue.self, from: json)
        guard case .array(let arr) = value else {
            Issue.record("Expected .array"); return
        }
        #expect(arr.count == 3)
    }

    @Test func decodesObject() throws {
        let json = Data(#"{"key":"value","num":3}"#.utf8)
        let value = try JSONDecoder().decode(JSONValue.self, from: json)
        guard case .object(let dict) = value else {
            Issue.record("Expected .object"); return
        }
        #expect(dict["key"]?.stringValue == "value")
    }

    // MARK: - Encoding roundtrip

    @Test func encodingRoundtrip() throws {
        let original: JSONValue = .object([
            "name": .string("test"),
            "count": .number(42),
            "active": .bool(true),
            "tags": .array([.string("a"), .string("b")]),
            "meta": .null,
        ])

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(JSONValue.self, from: data)

        guard case .object(let dict) = decoded else {
            Issue.record("Expected .object after roundtrip"); return
        }
        #expect(dict["name"]?.stringValue == "test")
        #expect(dict["count"]?.description == "42.0")
    }

    // MARK: - stringValue

    @Test func stringValueReturnsNilForNonString() {
        #expect(JSONValue.number(42).stringValue == nil)
        #expect(JSONValue.bool(true).stringValue == nil)
        #expect(JSONValue.null.stringValue == nil)
    }

    @Test func stringValueReturnsStringForString() {
        #expect(JSONValue.string("hi").stringValue == "hi")
    }

    // MARK: - description

    @Test func descriptionFormats() {
        #expect(JSONValue.string("hi").description == "hi")
        #expect(JSONValue.bool(false).description == "false")
        #expect(JSONValue.null.description == "null")
    }
}
