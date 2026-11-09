import Foundation
import Combine

@MainActor final class AppSession: ObservableObject {
    @Published var credentials = ZeehoCredentials()
    @Published var token = ""
    @Published var vehicles: [Vehicle] = []
    @Published var selectedVehicle: Vehicle?
    @Published var summary: VehicleSummary?
    @Published var error = ""
    @Published var busy = false
    @Published var detail = ""
    @Published var detailTitle = ""
    @Published var userID = ""
    private let tokenKey = "token"

    init() {
        token = SecureStore.read(tokenKey).flatMap { String(data: $0, encoding: .utf8) } ?? ""
        if let data = SecureStore.read("credentials"), let value = try? JSONDecoder().decode(ZeehoCredentials.self, from: data), !value.appId.isEmpty, !value.appSecret.isEmpty { credentials = value }
        userID = SecureStore.read("user-id").flatMap { String(data: $0, encoding: .utf8) } ?? ""
    }
    var api: ZeehoAPI { ZeehoAPI(credentials: credentials) }
    func persistCredentials() { if let data = try? JSONEncoder().encode(credentials) { SecureStore.write(data, key: "credentials") } }
    func persistUserID() { SecureStore.write(Data(userID.utf8), key: "user-id") }
    func login(phone: String, code: String) async {
        busy = true; error = ""; defer { busy = false }
        do { token = try await api.login(phone: phone, code: code); SecureStore.write(Data(token.utf8), key: tokenKey); try await loadVehicles() }
        catch { self.error = error.localizedDescription }
    }
    func useToken(_ value: String) async {
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "Bearer ", with: "", options: [.caseInsensitive, .anchored])
        guard !cleaned.isEmpty else { error = "请粘贴 token"; return }
        busy = true; error = ""; defer { busy = false }
        token = cleaned; SecureStore.write(Data(cleaned.utf8), key: tokenKey)
        do { try await loadVehicles() } catch { token = ""; SecureStore.delete(tokenKey); self.error = error.localizedDescription }
    }
    func loadVehicles() async throws { vehicles = try await api.vehicles(token: token); selectedVehicle = vehicles.first; if let v = selectedVehicle { summary = try await api.home(vin: v.id, token: token) } }
    func refresh() async { do { try await loadVehicles() } catch { self.error = error.localizedDescription } }
    func logout() { token = ""; vehicles = []; selectedVehicle = nil; summary = nil; SecureStore.delete(tokenKey) }
    func loadDetail(_ title: String, path: String) async {
        guard !token.isEmpty else { error = "请先登录"; return }
        busy = true; detailTitle = title; detail = "加载中…"; defer { busy = false }
        do { detail = try await api.generic(path: path, token: token).pretty }
        catch { detail = "请求失败：\(error.localizedDescription)" }
    }
    func loadDetail(_ title: String, operation: (ZeehoAPI, String, String) async throws -> JSONValue) async {
        guard let vehicle = selectedVehicle else { error = "请先选择车辆"; return }
        busy = true; detailTitle = title; detail = "加载中…"; defer { busy = false }
        do { detail = try await operation(api, vehicle.id, token).pretty }
        catch { detail = "请求失败：\(error.localizedDescription)" }
    }
    func performWrite(_ title: String, method: String, path: String, body: [String: Any] = [:]) async {
        guard !token.isEmpty else { error = "请先登录"; return }
        busy = true; detailTitle = title; detail = "执行中…"; defer { busy = false }
        do { detail = try await api.generic(method: method, path: path, body: body, token: token).pretty }
        catch { detail = "执行失败：\(error.localizedDescription)" }
    }
}
