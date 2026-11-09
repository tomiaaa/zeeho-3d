import Foundation

struct Vehicle: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let typeName: String
    let imageURL: URL?
}

struct VehicleSummary: Codable {
    let vin: String
    let name: String
    let typeName: String
    let online: String
    let soc: Double?
    let rangeKm: Double?
    let totalKm: String?
    let otaVersion: String
    let charging: Bool
}

struct APIEnvelope: Decodable {
    let data: JSONValue?
    let code: String?
    let message: String?
}

indirect enum JSONValue: Decodable {
    case object([String: JSONValue]), array([JSONValue]), string(String), number(Double), bool(Bool), null
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let v = try? c.decode([String: JSONValue].self) { self = .object(v) }
        else if let v = try? c.decode([JSONValue].self) { self = .array(v) }
        else if let v = try? c.decode(String.self) { self = .string(v) }
        else if let v = try? c.decode(Double.self) { self = .number(v) }
        else { self = .bool(try c.decode(Bool.self)) }
    }
    var object: [String: JSONValue]? { if case .object(let v) = self { return v }; return nil }
    var array: [JSONValue]? { if case .array(let v) = self { return v }; return nil }
    var string: String? { if case .string(let v) = self { return v }; if case .number(let v) = self { return String(v) }; return nil }
    var double: Double? { if case .number(let v) = self { return v }; return string.flatMap(Double.init) }
    var pretty: String {
        switch self {
        case .object(let values): return "{\n" + values.keys.sorted().map { "  \"\($0)\": \(values[$0]!.pretty)" }.joined(separator: ",\n") + "\n}"
        case .array(let values): return "[\n" + values.map { "  \($0.pretty)" }.joined(separator: ",\n") + "\n]"
        case .string(let value): return "\"\(value)\""
        case .number(let value): return String(value)
        case .bool(let value): return String(value)
        case .null: return "null"
        }
    }
}
