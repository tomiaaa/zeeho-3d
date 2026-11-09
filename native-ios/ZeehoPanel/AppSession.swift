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
    private let tokenKey = "zeeho.native.token"

    init() { token = UserDefaults.standard.string(forKey: tokenKey) ?? "" }
    var api: ZeehoAPI { ZeehoAPI(credentials: credentials) }
    func login(phone: String, code: String) async {
        busy = true; error = ""; defer { busy = false }
        do { token = try await api.login(phone: phone, code: code); UserDefaults.standard.set(token, forKey: tokenKey); try await loadVehicles() }
        catch { self.error = error.localizedDescription }
    }
    func loadVehicles() async throws { vehicles = try await api.vehicles(token: token); selectedVehicle = vehicles.first; if let v = selectedVehicle { summary = try await api.home(vin: v.id, token: token) } }
    func refresh() async { do { try await loadVehicles() } catch { self.error = error.localizedDescription } }
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
}
