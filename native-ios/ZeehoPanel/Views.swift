import SwiftUI

struct RootView: View {
    @EnvironmentObject private var session: AppSession
    var body: some View { Group { if session.token.isEmpty { LoginView() } else { DashboardView() } }.alert("提示", isPresented: Binding(get: { !session.error.isEmpty }, set: { _ in session.error = "" })) { Button("确定", role: .cancel) {} } message: { Text(session.error) } }
}

struct LoginView: View {
    @EnvironmentObject private var session: AppSession
    @State private var phone = ""; @State private var code = ""; @State private var appId = ""; @State private var secret = ""; @State private var basic = ""; @State private var codeSent = false
    var body: some View { NavigationStack { Form { Section("接口凭据") { TextField("appId", text: $appId); SecureField("appSecret", text: $secret); SecureField("Basic", text: $basic) }; Section("手机号登录") { TextField("手机号", text: $phone).keyboardType(.phonePad); HStack { TextField("验证码", text: $code).keyboardType(.numberPad); Button("发送验证码") { saveCredentials(); Task { do { try await session.api.sendCode(phone: phone); codeSent = true } catch { session.error = error.localizedDescription } } }.disabled(phone.count < 11 || session.busy) }; Button("登录") { saveCredentials(); Task { await session.login(phone: phone, code: code) } }.disabled(phone.isEmpty || code.isEmpty || session.busy); if codeSent { Text("验证码已发送").font(.footnote).foregroundStyle(.secondary) } } }.navigationTitle("极核面板").onAppear { appId = session.credentials.appId; secret = session.credentials.appSecret; basic = session.credentials.basic } } }
    private func saveCredentials() { session.credentials.appId = appId; session.credentials.appSecret = secret; session.credentials.basic = basic; session.persistCredentials() }
}

struct DashboardView: View {
    @EnvironmentObject private var session: AppSession
    var body: some View { TabView { HomeTab().tabItem { Label("车况", systemImage: "car.fill") }; DataTab().tabItem { Label("数据", systemImage: "chart.bar.fill") }; ControlTab().tabItem { Label("车控", systemImage: "lock.open.fill") }; SettingsTab().tabItem { Label("设置", systemImage: "gearshape.fill") } } }
}

struct HomeTab: View {
    @EnvironmentObject private var session: AppSession
    var body: some View { NavigationStack { List { Section("车辆") { ForEach(session.vehicles) { vehicle in Button { session.selectedVehicle = vehicle; Task { do { session.summary = try await session.api.home(vin: vehicle.id, token: session.token) } catch { session.error = error.localizedDescription } } } label: { Label(vehicle.name, systemImage: vehicle.id == session.selectedVehicle?.id ? "checkmark.circle.fill" : "car.fill") } } }; if let s = session.summary { Section("车况") { LabeledContent("车辆", value: s.name.isEmpty ? s.vin : s.name); LabeledContent("电量", value: s.soc.map { "\(Int($0))%" } ?? "-"); LabeledContent("续航", value: s.rangeKm.map { "\(Int($0)) km" } ?? "-"); LabeledContent("在线状态", value: s.online.isEmpty ? "未知" : s.online); LabeledContent("OTA", value: s.otaVersion.isEmpty ? "-" : s.otaVersion) } }; Section("车辆资料") { NavigationLink("车辆信息与蓝牙资料") { DetailView(title: "车辆资料", action: { await session.loadDetail("车辆资料", path: "/v1.0/app/cfmotoserverapp/vehicleSet/vehicleSetInfo/\(session.selectedVehicle?.id ?? "")") }) }; NavigationLink("车模目录") { ModelCatalogView() } }; Section { Button("刷新") { Task { await session.refresh() } } }.task { if session.vehicles.isEmpty { await session.refresh() } } }.navigationTitle("车况") } }
}

struct DataTab: View {
    @EnvironmentObject private var session: AppSession
    var body: some View { NavigationStack { List { Section("骑行") { DetailLink(title: "最近骑行") { await session.loadDetail("最近骑行") { try await $0.rideHome(vin: $1, token: $2) } }; DetailLink(title: "本月骑行") { await session.loadDetail("本月骑行") { try await $0.rideMonth(vin: $1, month: String(Calendar.current.component(.year, from: Date())) + "." + String(format: "%02d", Calendar.current.component(.month, from: Date())), token: $2) } }; DetailLink(title: "骑行轨迹") { await session.loadDetail("骑行轨迹") { try await $0.generic(path: "/v1.0/app/cfmotoserverapp/ridetrack_v2?vinNo=\($1)&page=1&pageSize=20", token: $2) } }; DetailLink(title: "骑行画像") { await session.loadDetail("骑行画像") { try await $0.generic(path: "/v1.0/app/cfmotoserverapp/analyse/analyse?vinNo=\($1)", token: $2) } } }; Section("车辆数据") { DetailLink(title: "电池信息") { await session.loadDetail("电池信息") { try await $0.battery(vin: $1, token: $2) } }; DetailLink(title: "胎压监测") { await session.loadDetail("胎压监测") { try await $0.tire(vin: $1, token: $2) } }; DetailLink(title: "车辆设置能力") { await session.loadDetail("车辆设置能力") { try await $0.settings(vin: $1, token: $2) } } }; Section("OTA / 主题 / 壁纸") { DetailLink(title: "OTA 信息") { await session.loadDetail("OTA 信息") { try await $0.otaInfo(vin: $1, token: $2) } }; DetailLink(title: "OTA 任务") { await session.loadDetail("OTA 任务") { try await $0.otaList(vin: $1, token: $2) } }; DetailLink(title: "车机壁纸") { await session.loadDetail("车机壁纸") { try await $0.wallpapers(vin: $1, token: $2) } }; DetailLink(title: "车机主题") { await session.loadDetail("车机主题") { try await $0.themes(vin: $1, token: $2) } } }; Section("账户与社区") { DetailLink(title: "用户资料") { await session.loadDetail("用户资料") { try await $0.userInfo(uid: session.userID, token: $2) } }; DetailLink(title: "积分") { await session.loadDetail("积分") { try await $0.integral(token: $2) } }; DetailLink(title: "签到") { await session.loadDetail("签到") { try await $0.signIn(token: $2) } }; DetailLink(title: "我的动态") { await session.loadDetail("我的动态") { try await $0.myPosts(uid: session.userID, token: $2) } }; DetailLink(title: "社区广场") { await session.loadDetail("社区广场") { try await $0.squarePosts(token: $2) } } }; Section("消息") { DetailLink(title: "未读消息") { await session.loadDetail("未读消息") { try await $0.messages(token: $2) } } } }.navigationTitle("数据") } }
}

struct DetailLink: View {
    let title: String
    let action: () async -> Void
    var body: some View { NavigationLink(title) { DetailView(title: title, action: action) } }
}

struct ControlTab: View {
    @EnvironmentObject private var session: AppSession
    @State private var showConfirm = false
    var body: some View {
        NavigationStack {
            List {
                Section("当前车辆") { Text(session.selectedVehicle?.name ?? "未选择车辆") }
                Section("写入操作") {
                    Button("寻车（响铃/闪灯）") { showConfirm = true }.disabled(session.selectedVehicle == nil)
                    Text("写操作会改变车辆状态，请确认车辆和网络环境。此版本暂未自动推断车控参数.").font(.footnote).foregroundStyle(.secondary)
                }
                Section("蓝牙") { Label("蓝牙传输协议未在项目源码中提供", systemImage: "bluetooth") }
            }
            .navigationTitle("车控")
            .alert("确认寻车", isPresented: $showConfirm) {
                Button("取消", role: .cancel) {}
                Button("执行", role: .destructive) {
                    if let vin = session.selectedVehicle?.id {
                        Task {
                            do { session.detail = try await session.api.findCar(vin: vin, token: session.token).pretty }
                            catch { session.error = error.localizedDescription }
                        }
                    }
                }
            } message: { Text("将向车辆发送寻车控制请求.") }
        }
    }
}
struct DetailView: View {
    let title: String
    var action: (() async -> Void)? = nil
    @EnvironmentObject private var session: AppSession
    init(title: String, action: @escaping () async -> Void) { self.title = title; self.action = action }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if !session.detail.isEmpty { ShareLink(item: session.detail) { Label("分享 / 导出响应", systemImage: "square.and.arrow.up") } }
                Text(session.detail).font(.system(.footnote, design: .monospaced)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
            }.padding()
        }.navigationTitle(title).task { if let action { await action() } }
    }
}

struct SettingsTab: View {
    @EnvironmentObject private var session: AppSession
    var body: some View {
        NavigationStack {
            List {
                Section("账户") {
                    TextField("用户 ID（个人/社区接口需要）", text: $session.userID).textInputAutocapitalization(.never)
                    Button("保存用户 ID") { session.persistUserID() }
                    Button("退出登录", role: .destructive) { session.logout() }
                }
                Section("诊断") { NavigationLink("接口工作台") { APIWorkbenchView() } }
                Section("说明") { Text("蓝牙指令、云解锁和车机上传需要实际车辆验证。") }
            }.navigationTitle("设置")
        }
    }
}

struct APIWorkbenchView: View {
    @EnvironmentObject private var session: AppSession
    @State private var path = "/v1.0/app/cfmotoserverapp/vehicle/list"
    @State private var method = "GET"
    @State private var bodyText = "{}"
    @State private var confirmWrite = false
    private let methods = ["GET", "POST", "PUT", "DELETE"]
    var body: some View {
        Form {
            Section("请求") {
                Picker("方法", selection: $method) { ForEach(methods, id: \.self) { Text($0) } }
                TextField("接口路径（含 query）", text: $path, axis: .vertical).lineLimit(2...4).textInputAutocapitalization(.never)
                if method != "GET" { TextEditor(text: $bodyText).frame(minHeight: 100).font(.system(.footnote, design: .monospaced)) }
                Button("发送请求") { if method == "GET" { run() } else { confirmWrite = true } }
            }
            Section("响应") { Text(session.detail).font(.system(.footnote, design: .monospaced)).textSelection(.enabled) }
        }
        .navigationTitle("接口工作台")
        .confirmationDialog("发送写入请求？", isPresented: $confirmWrite, titleVisibility: .visible) { Button("继续发送", role: .destructive) { run() } }
    }
    private func run() {
        var payload: [String: Any] = [:]
        if method != "GET" {
            guard let data = bodyText.data(using: .utf8), let object = try? JSONSerialization.jsonObject(with: data), let value = object as? [String: Any] else { session.error = "请求体必须是 JSON 对象"; return }
            payload = value
        }
        Task { await session.performWrite("接口响应", method: method, path: path, body: payload) }
    }
}

struct ModelCatalogView: View {
    let models = [("AE4 MAX2+", "AE4-MAX2plus"), ("咕咕嘎嘎", "gugugaga"), ("DeepSeek 玩偶", "deepseek-fumo"), ("巫女立绘", "miko-bust")]
    var body: some View {
        List(Array(models.enumerated()), id: \.offset) { _, model in
            NavigationLink { NativeModelView(title: model.0, resource: model.1) } label: { Label(model.0, systemImage: "cube.fill") }
        }.navigationTitle("3D 车模")
    }
}

struct NativeModelView: View {
    let title: String
    let resource: String
    var body: some View {
        Group {
            if let url = Bundle.main.url(forResource: resource, withExtension: "usdz") {
                Model3D(url: url) { state in
                    switch state {
                    case .empty: ProgressView()
                    case .success(let model): model.resizable().scaledToFit()
                    case .failure: ContentUnavailableView("模型无法加载", systemImage: "cube.transparent")
                    @unknown default: ProgressView()
                    }
                }
            } else { ContentUnavailableView("模型资源缺失", systemImage: "cube.transparent") }
        }.navigationTitle(title).padding()
    }
}
