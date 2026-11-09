import CryptoKit
import Foundation

struct ZeehoCredentials: Codable { var base = "https://tapi.zeehoev.com"; var appId = ""; var appSecret = ""; var basic = "" }

final class ZeehoAPI {
    private let credentials: ZeehoCredentials
    private let session: URLSession
    private let appPrefix = "/v1.0/app/cfmotoserverapp/"
    private let minePrefix = "/v1.0/mine/cfmotoservermine/"

    init(credentials: ZeehoCredentials, session: URLSession = .shared) { self.credentials = credentials; self.session = session }

    func sendCode(phone: String) async throws { _ = try await request(path: minePrefix + "authCode/" + phone, token: nil) }
    func login(phone: String, code: String) async throws -> String {
        let body = try JSONSerialization.data(withJSONObject: ["phone": phone, "authCode": code])
        let value = try await request(path: minePrefix + "user/loginByPhone", method: "POST", body: body, token: nil, basic: credentials.basic)
        guard let token = value.object?["data"]?.object?["tokenInfo"]?.object?["access_token"]?.string ?? value.object?["access_token"]?.string else { throw APIError.message("登录响应没有 access_token") }
        return token
    }

    func vehicles(token: String) async throws -> [Vehicle] {
        let value = try await request(path: appPrefix + "vehicle/list", token: token)
        let array = value.object?["data"]?.array ?? value.array ?? []
        return array.compactMap { item in
            guard let o = item.object else { return nil }
            let vin = o["vinNo"]?.string ?? o["vin"]?.string ?? ""
            guard !vin.isEmpty else { return nil }
            return Vehicle(id: vin, name: o["vehicleName"]?.string ?? vin, typeName: o["vehicleTypeName"]?.string ?? "", imageURL: URL(string: o["vehiclePicUrl"]?.string ?? ""))
        }
    }

    func home(vin: String, token: String) async throws -> VehicleSummary {
        let value = try await request(path: appPrefix + "vehicleHomePageV2/" + vin, token: token)
        let o = value.object?["data"]?.object ?? value.object ?? [:]
        return VehicleSummary(vin: o["vinNo"]?.string ?? vin, name: o["vehicleName"]?.string ?? "", typeName: o["vehicleTypeName"]?.string ?? "", online: o["onlineStatus"]?.string ?? "", soc: o["bmssoc"]?.double, rangeKm: o["hmiRidableMile"]?.double, totalKm: o["totalRideMile"]?.string, otaVersion: o["otaVersion"]?.string ?? "", charging: o["chargeState"]?.string == "1")
    }

    private func request(path: String, method: String = "GET", body: Data? = nil, token: String?, basic: String? = nil) async throws -> JSONValue {
        guard let url = URL(string: credentials.base + path) else { throw APIError.message("无效接口地址") }
        var request = URLRequest(url: url); request.httpMethod = method; request.httpBody = body; request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type"); request.setValue("okhttp/4.9.2", forHTTPHeaderField: "User-Agent")
        guard !credentials.appId.isEmpty, !credentials.appSecret.isEmpty else { throw APIError.message("请先填写 appId 和 appSecret") }
        let timestamp = String(Int(Date().timeIntervalSince1970 * 1000))
        let nonce = Self.randomNonce() + timestamp
        let query = Self.canonicalQuery(url.query ?? "")
        let canonicalURL = url.path + (query.isEmpty ? "" : "?" + query)
        let bodyText = body.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        let signingInput = method == "GET" ? url.scheme! + "://" + url.host! + canonicalURL : query + bodyText
        let param = "appId=\(credentials.appId)&nonce=\(nonce)&timestamp=\(timestamp)"
        let sha = Insecure.SHA1.hash(data: Data((signingInput + param + credentials.appSecret).utf8))
        let shaHex = sha.map { String(format: "%02x", $0) }.joined()
        let signature = Insecure.MD5.hash(data: Data(shaHex.utf8)).map { String(format: "%02x", $0) }.joined()
        request.setValue(credentials.appId, forHTTPHeaderField: "appId")
        request.setValue(nonce, forHTTPHeaderField: "nonce")
        request.setValue(timestamp, forHTTPHeaderField: "timestamp")
        request.setValue(signature, forHTTPHeaderField: "signature")
        request.setValue(param, forHTTPHeaderField: "Cfmoto-X-Param")
        request.setValue(signature, forHTTPHeaderField: "Cfmoto-X-Sign")
        request.setValue("0", forHTTPHeaderField: "Cfmoto-X-Sign-Type")
        if let token { request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization") }
        if let basic { request.setValue(basic.hasPrefix("Basic ") ? basic : "Basic " + basic, forHTTPHeaderField: "Authorization") }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw APIError.message("服务端返回错误") }
        return try JSONDecoder().decode(JSONValue.self, from: data)
    }

    private static func canonicalQuery(_ query: String) -> String {
        guard var parts = URLComponents(string: "https://local.invalid/?" + query)?.queryItems else { return "" }
        parts.sort { ($0.name, $0.value ?? "") < ($1.name, $1.value ?? "") }
        return parts.map { "\(rfc3986($0.name))=\(rfc3986($0.value ?? ""))" }.joined(separator: "&")
    }

    private static func rfc3986(_ value: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    private static func randomNonce() -> String {
        let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789")
        return String((0..<16).map { _ in alphabet.randomElement()! })
    }
}

enum APIError: LocalizedError { case message(String); var errorDescription: String? { if case .message(let s) = self { return s }; return nil } }
