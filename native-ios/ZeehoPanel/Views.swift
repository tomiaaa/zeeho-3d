import SwiftUI

struct RootView: View {
    @EnvironmentObject private var session: AppSession
    var body: some View { Group { session.token.isEmpty ? LoginView() : DashboardView() }.alert("提示", isPresented: Binding(get: { !session.error.isEmpty }, set: { _ in session.error = "" })) { Button("确定", role: .cancel) {} } message: { Text(session.error) } }
}

struct LoginView: View {
    @EnvironmentObject private var session: AppSession
    @State private var phone = ""; @State private var code = ""; @State private var appId = ""; @State private var secret = ""; @State private var basic = ""; @State private var codeSent = false
    var body: some View { NavigationStack { Form { Section("接口凭据") { TextField("appId", text: $appId); SecureField("appSecret", text: $secret); SecureField("Basic", text: $basic) }; Section("手机号登录") { TextField("手机号", text: $phone).keyboardType(.phonePad); HStack { TextField("验证码", text: $code).keyboardType(.numberPad); Button("发送验证码") { session.credentials.appId = appId; session.credentials.appSecret = secret; session.credentials.basic = basic; Task { do { try await session.api.sendCode(phone: phone); codeSent = true } catch { session.error = error.localizedDescription } } }.disabled(phone.count < 11 || session.busy) }; Button("登录") { session.credentials.appId = appId; session.credentials.appSecret = secret; session.credentials.basic = basic; Task { await session.login(phone: phone, code: code) } }.disabled(phone.isEmpty || code.isEmpty || session.busy); if codeSent { Text("验证码已发送").font(.footnote).foregroundStyle(.secondary) } } }.navigationTitle("极核面板") } }
}

struct DashboardView: View {
    @EnvironmentObject private var session: AppSession
    var body: some View { NavigationStack { List { Section("车辆") { ForEach(session.vehicles) { vehicle in Button { session.selectedVehicle = vehicle; Task { do { session.summary = try await session.api.home(vin: vehicle.id, token: session.token) } catch { session.error = error.localizedDescription } } } label: { Label(vehicle.name, systemImage: vehicle.id == session.selectedVehicle?.id ? "checkmark.circle.fill" : "car.fill") } } }; if let s = session.summary { Section("车况") { LabeledContent("车辆", value: s.name.isEmpty ? s.vin : s.name); LabeledContent("电量", value: s.soc.map { "\(Int($0))%" } ?? "-"); LabeledContent("续航", value: s.rangeKm.map { "\(Int($0)) km" } ?? "-"); LabeledContent("在线状态", value: s.online.isEmpty ? "未知" : s.online); LabeledContent("OTA", value: s.otaVersion.isEmpty ? "-" : s.otaVersion) } }; Section { Button("刷新") { Task { await session.refresh() } }; Button("退出登录", role: .destructive) { session.token = ""; UserDefaults.standard.removeObject(forKey: "zeeho.native.token") } } }.navigationTitle("极核面板") } }
}
