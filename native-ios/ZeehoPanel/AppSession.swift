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
    private let tokenKey = "zeeho.native.token"

    init() { token = UserDefaults.standard.string(forKey: tokenKey) ?? "" }
    var api: ZeehoAPI { ZeehoAPI(credentials: credentials) }
    func login(phone: String, code: String) async {
        busy = true; error = ""; defer { busy = false }
        do { token = try await api.login(phone: phone, code: code); UserDefaults.standard.set(token, forKey: tokenKey); try await loadVehicles() }
        catch { error = error.localizedDescription }
    }
    func loadVehicles() async throws { vehicles = try await api.vehicles(token: token); selectedVehicle = vehicles.first; if let v = selectedVehicle { summary = try await api.home(vin: v.id, token: token) } }
    func refresh() async { do { try await loadVehicles() } catch { error = error.localizedDescription } }
}
