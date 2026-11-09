import CryptoKit
import Foundation

struct ZeehoCredentials: Codable {
    var base = "https://tapi.zeehoev.com"
    var appId = "S7qPWPU1"
    var appSecret = "c5e0da7f4da28df805694ec3dd1fc6792e9df99d"
    var basic = "Basic bWNrOjEyMzQ1Ng=="
    var appInfo = "MOBILE|Android|17|ZEEHO_APP|3.0.5|Dalvik/2.1.0 (Linux; U; Android 17; 2510DRK44C Build/CP2A.260605.016)|1156*2510|1|100|5G|xiaomi"
}

final class ZeehoAPI {
    private let credentials: ZeehoCredentials
    private let session: URLSession
    private let appPrefix = "/v1.0/app/cfmotoserverapp/"
    private let minePrefix = "/v1.0/mine/cfmotoservermine/"

    init(credentials: ZeehoCredentials, session: URLSession = .shared) { self.credentials = credentials; self.session = session }

    func sendCode(phone: String) async throws {
        _ = try await request(path: minePrefix + "authCode/" + Self.rfc3986(phone), token: nil)
    }
    func login(phone: String, code: String) async throws -> String {
        let body = Data(("{\"phone\":\(Self.jsonString(phone)),\"authCode\":\(Self.jsonString(code))}").utf8)
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

    func get(path: String, token: String) async throws -> JSONValue { try await request(path: path, token: token) }
    func rideHome(vin: String, token: String) async throws -> JSONValue { try await request(path: appPrefix + "homeRideInfo?vinNo=" + Self.rfc3986(vin), token: token) }
    func rideMonth(vin: String, month: String, token: String) async throws -> JSONValue { try await request(path: appPrefix + "myRideInfo?vinNo=" + Self.rfc3986(vin) + "&month=" + Self.rfc3986(month), token: token) }
    func otaInfo(vin: String, token: String) async throws -> JSONValue { try await request(path: appPrefix + "ota/mmi/info/v2?vinNo=" + Self.rfc3986(vin), token: token) }
    func otaList(vin: String, token: String) async throws -> JSONValue { try await request(path: appPrefix + "ota/list?vinNo=" + Self.rfc3986(vin), token: token) }
    func battery(vin: String, token: String) async throws -> JSONValue { try await request(path: appPrefix + "batteryInfo/" + Self.rfc3986(vin), token: token) }
    func tire(vin: String, token: String) async throws -> JSONValue { try await request(path: appPrefix + "app/vehicle/tire/monitoring?vinNo=" + Self.rfc3986(vin) + "&sensorType=EXTERNAL", token: token) }
    func settings(vin: String, token: String) async throws -> JSONValue { try await request(path: appPrefix + "vehicleSet/vehicleSetInfo/" + Self.rfc3986(vin), token: token) }
    func messages(token: String) async throws -> JSONValue { try await request(path: minePrefix + "app/Message/allUnRead", token: token) }
    func wallpapers(vin: String, token: String) async throws -> JSONValue { try await request(path: appPrefix + "vehicle/wallpaper/pageVehicleWallpaper?vinNo=" + Self.rfc3986(vin) + "&pageNum=1&pageSize=20", token: token) }
    func themes(vin: String, token: String) async throws -> JSONValue { try await request(path: appPrefix + "vehicleTheme/list?vinNo=" + Self.rfc3986(vin), token: token) }
    func generic(path: String, token: String) async throws -> JSONValue { try await request(path: path.hasPrefix("/") ? path : "/" + path, token: token) }
    func generic(method: String, path: String, body: [String: Any] = [:], token: String) async throws -> JSONValue {
        let data = try JSONSerialization.data(withJSONObject: body)
        return try await request(path: path.hasPrefix("/") ? path : "/" + path, method: method, body: method == "GET" ? nil : data, token: token)
    }
    func userInfo(uid: String, token: String) async throws -> JSONValue { try await request(path: minePrefix + "setting/other/" + Self.rfc3986(uid), token: token) }
    func appCodes(token: String) async throws -> JSONValue { try await request(path: minePrefix + "user/appCode", token: token) }
    func integral(token: String) async throws -> JSONValue { try await request(path: minePrefix + "integral/totalIntegral", token: token) }
    func signIn(token: String) async throws -> JSONValue { try await request(path: "/cfmotoservermine/signin/info?month=\(DateFormatter.month.string(from: Date()))&server_name=SMART", token: token) }
    func myPosts(uid: String, token: String) async throws -> JSONValue { try await request(path: "/v1.0/social/cfmotoserversocial/community/mineArticleInfo?userId=" + Self.rfc3986(uid), token: token) }
    func squarePosts(token: String) async throws -> JSONValue { try await request(path: "/v1.0/social/cfmotoserversocial/community/qbTzInfoNewV2?postModule=1&slidingType=0&page=1&pageSize=20", token: token) }
    func findCar(vin: String, token: String) async throws -> JSONValue { let body = try JSONSerialization.data(withJSONObject: ["controlType": "HORN"]); return try await request(path: appPrefix + "vehicleInfo/control/" + Self.rfc3986(vin), method: "PUT", body: body, token: token) }

    private func request(path: String, method: String = "GET", body: Data? = nil, token: String?, basic: String? = nil) async throws -> JSONValue {
        guard let url = URL(string: credentials.base + path) else { throw APIError.message("无效接口地址") }
        var request = URLRequest(url: url); request.httpMethod = method; request.httpBody = body; request.timeoutInterval = 20
        request.setValue("application/json;charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.setValue("zh-CN", forHTTPHeaderField: "Accept-Language")
        request.setValue("okhttp/4.12.0", forHTTPHeaderField: "User-Agent")
        guard !credentials.appId.isEmpty, !credentials.appSecret.isEmpty else { throw APIError.message("请先填写 appId 和 appSecret") }
        let timestamp = String(Int(Date().timeIntervalSince1970 * 1000))
        let nonce = timestamp + Self.randomNonce()
        let query = Self.canonicalQuery(url.query ?? "")
        let bodyText = body.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        let signingPath = "path=" + url.path + (query.isEmpty ? "" : "?" + query)
        let signingInput = signingPath + (method == "GET" ? "" : bodyText)
        let param = "appId=\(credentials.appId)&nonce=\(nonce)&timestamp=\(timestamp)"
        let sha = Insecure.SHA1.hash(data: Data((signingInput + param + credentials.appSecret).utf8))
        let shaHex = sha.map { String(format: "%02x", $0) }.joined()
        let signature = Insecure.MD5.hash(data: Data(shaHex.utf8)).map { String(format: "%02x", $0) }.joined()
        request.setValue(credentials.appId, forHTTPHeaderField: "appid")
        request.setValue(credentials.appInfo, forHTTPHeaderField: "x-app-info")
        request.setValue("2", forHTTPHeaderField: "interfaceversion")
        request.setValue(nonce, forHTTPHeaderField: "nonce")
        request.setValue(timestamp, forHTTPHeaderField: "timestamp")
        request.setValue(signature, forHTTPHeaderField: "signature")
        request.setValue(param, forHTTPHeaderField: "Cfmoto-X-Param")
        request.setValue(signature, forHTTPHeaderField: "Cfmoto-X-Sign")
        request.setValue("0", forHTTPHeaderField: "Cfmoto-X-Sign-Type")
        if let token { request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization") }
        if let basic { request.setValue(basic.hasPrefix("Basic ") ? basic : "Basic " + basic, forHTTPHeaderField: "Authorization") }
        let (data, response) = try await session.data(for: request)
        let httpStatus = (response as? HTTPURLResponse)?.statusCode ?? 0
        let decoded = try? JSONDecoder().decode(JSONValue.self, from: data)
        guard (200..<300).contains(httpStatus) else {
            let code = decoded?.object?["code"]?.string ?? "HTTP \(httpStatus)"
            let message = decoded?.object?["message"]?.string ?? decoded?.object?["msg"]?.string ?? "服务端返回错误"
            throw APIError.message("\(code)：\(message)")
        }
        if let decoded { return decoded }
        throw APIError.message("服务端返回不是有效 JSON")
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

    private static func jsonString(_ value: String) -> String {
        guard let data = try? JSONEncoder().encode(value) else { return "\"\"" }
        return String(data: data, encoding: .utf8) ?? "\"\""
    }
}

enum APIError: LocalizedError { case message(String); var errorDescription: String? { if case .message(let s) = self { return s }; return nil } }

private extension DateFormatter {
    static let month: DateFormatter = { let value = DateFormatter(); value.dateFormat = "yyyy-MM"; value.locale = Locale(identifier: "en_US_POSIX"); return value }()
}
