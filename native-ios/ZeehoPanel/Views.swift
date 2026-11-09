import SwiftUI
import QuickLook

struct RootView: View {
    @EnvironmentObject private var session: AppSession
    var body: some View { Group { if session.demoMode || !session.token.isEmpty { DashboardView() } else { LoginView() } }.preferredColorScheme(.dark).tint(Color(red: 0.58, green: 0.43, blue: 0.95)).alert("提示", isPresented: Binding(get: { !session.error.isEmpty }, set: { _ in session.error = "" })) { Button("确定", role: .cancel) {} } message: { Text(session.error) } }
}

struct LoginView: View {
    @EnvironmentObject private var session: AppSession
    @State private var phone = ""
    @State private var code = ""
    @State private var token = ""
    @State private var seconds = 0
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.08, green: 0.07, blue: 0.12), Color(red: 0.18, green: 0.12, blue: 0.28)], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 22) {
                    Spacer(minLength: 42)
                    Image(systemName: "bolt.car.fill").font(.system(size: 42, weight: .semibold)).foregroundStyle(Color(red: 0.78, green: 0.66, blue: 1.0))
                    VStack(spacing: 6) { Text("极核面板").font(.system(size: 30, weight: .bold)); Text("ZEEHO vehicle control panel").font(.subheadline).foregroundStyle(.white.opacity(0.62)) }
                    VStack(spacing: 14) {
                        Text("手机号登录").font(.headline).frame(maxWidth: .infinity, alignment: .leading)
                        HStack { Image(systemName: "phone"); TextField("11 位手机号", text: $phone).keyboardType(.phonePad).textContentType(.telephoneNumber) }.padding(12).background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
                        HStack { Image(systemName: "number"); TextField("短信验证码", text: $code).keyboardType(.numberPad).textContentType(.oneTimeCode); Spacer(); Button(seconds > 0 ? "\(seconds)s" : "获取验证码") { Task { await session.sendCode(phone: phone); if session.error.isEmpty { startCountdown() } } }.disabled(seconds > 0 || session.sendingCode) }.padding(12).background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
                        Button { Task { await session.login(phone: phone, code: code) } } label: { Text(session.busy ? "登录中…" : "登录").frame(maxWidth: .infinity).padding(.vertical, 14) }.buttonStyle(.borderedProminent).tint(Color(red: 0.48, green: 0.33, blue: 0.82)).disabled(phone.count != 11 || code.isEmpty || session.busy)
                        Text("验证码由极核服务直接发送到你的手机。此页面不打开浏览器。").font(.footnote).foregroundStyle(.white.opacity(0.62)).frame(maxWidth: .infinity, alignment: .leading)
                    }.padding(20).background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 18, style: .continuous)).overlay { RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.12)) }
                    VStack(alignment: .leading, spacing: 12) {
                        Text("已有 token").font(.headline)
                        SecureField("粘贴 Bearer token", text: $token).textFieldStyle(.roundedBorder)
                        Button("验证并登录") { Task { await session.useToken(token) } }.frame(maxWidth: .infinity).disabled(token.isEmpty || session.busy)
                    }.padding(20).background(.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    Button { session.enterDemo() } label: { Label("进入演示模式", systemImage: "play.rectangle") }.foregroundStyle(.white.opacity(0.8))
                    Text("演示模式只使用本地样例数据，不连接服务器或控制车辆。").font(.caption).foregroundStyle(.white.opacity(0.5))
                }.padding(.horizontal, 22).padding(.bottom, 30)
            }
        }
    }
    private func startCountdown() { seconds = 60; Task { while seconds > 0 { try? await Task.sleep(nanoseconds: 1_000_000_000); await MainActor.run { seconds -= 1 } } } }
}

struct DashboardView: View {
    @EnvironmentObject private var session: AppSession
    var body: some View { TabView { HomeTab().tabItem { Label("车况", systemImage: "car.fill") }; DataTab().tabItem { Label("数据", systemImage: "chart.bar.fill") }; ControlTab().tabItem { Label("车控", systemImage: "lock.open.fill") }; SettingsTab().tabItem { Label("设置", systemImage: "gearshape.fill") } }.toolbarBackground(.visible, for: .tabBar).toolbarBackground(Color(red: 0.10, green: 0.08, blue: 0.15), for: .tabBar) }
}

struct HomeTab: View {
    @EnvironmentObject private var session: AppSession
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    if session.demoMode { InfoCard(text: "当前是演示数据：车名、位置、行程都是虚拟样例。退出演示后登录即可查看真实车辆。", icon: "info.circle") }
                    HStack { StatusPill(text: session.summary?.online ?? "未连接", color: .green); StatusPill(text: session.summary?.charging == true ? "充电中" : "坐垫已锁", color: .secondary); Spacer(); StatusPill(text: "已关锁", color: .secondary) }.frame(maxWidth: .infinity, alignment: .leading)
                    if let s = session.summary {
                        VStack(spacing: 12) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading) { Text(s.soc.map { "\(Int($0))" } ?? "-").font(.system(size: 38, weight: .bold, design: .rounded)).foregroundStyle(.green); Text("电量 %").font(.caption).foregroundStyle(.secondary) }
                                Spacer(); Image(systemName: "scooter").font(.system(size: 76)).symbolRenderingMode(.hierarchical).foregroundStyle(.white.opacity(0.85)); Spacer()
                                VStack(alignment: .trailing) { Text("\(s.rangeKm.map { String(format: "%.1f", $0 * 0.568) } ?? "-")").font(.system(size: 28, weight: .bold, design: .rounded)); Text("V").font(.caption).foregroundStyle(.secondary) }
                            }
                            HStack { Metric(text: "2.4", unit: "bar  23°", icon: "circle.fill"); Spacer(); Metric(text: "2.0", unit: "bar  27°", icon: "circle.fill") }
                            ProgressView(value: (s.soc ?? 0) / 100).tint(.green)
                            HStack { Text("总里程 \(s.totalKm ?? "5803.6") km"); Spacer(); Text("信号 中") }.font(.caption).foregroundStyle(.secondary)
                        }.padding(16).background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    HStack(spacing: 10) {
                        ActionCard(title: "寻车", icon: "speaker.wave.2.fill", enabled: !session.demoMode) { if let vin = session.selectedVehicle?.id { Task { await session.loadDetail("寻车", operation: { try await $0.findCar(vin: vin, token: $2) }) } } }
                        ActionCard(title: "开锁", icon: "lock.open.fill", enabled: false) {}
                        ActionCard(title: "打开坐垫", icon: "rectangle.portrait.and.arrow.right", enabled: false) {}
                    }
                    HStack(spacing: 12) {
                        SmallCard(title: "车辆位置", value: session.demoMode ? "已隐藏位置" : "登录后读取", icon: "location.slash")
                        SmallCard(title: "最近骑行", value: session.demoMode ? "今日 0 km\n本月 276.9 km" : "查看记录", icon: "figure.outdoor.cycle")
                    }
                    NavigationLink { ModelCatalogView() } label: { SmallCard(title: "3D 车模", value: "查看模型目录", icon: "cube.fill") }
                }.padding(.horizontal, 16).padding(.bottom, 24)
            }.scrollIndicators(.hidden).background(Color(red: 0.06, green: 0.05, blue: 0.08)).navigationTitle(session.selectedVehicle?.name ?? "我的车辆").toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button { Task { await session.refresh() } } label: { Image(systemName: "arrow.clockwise") } } }.task { if session.vehicles.isEmpty && !session.demoMode { await session.refresh() } }
        }
    }
}

private struct InfoCard: View { let text: String; let icon: String; var body: some View { HStack(alignment: .top, spacing: 8) { Image(systemName: icon); Text(text).font(.footnote) }.foregroundStyle(.white.opacity(0.8)).padding(14).frame(maxWidth: .infinity, alignment: .leading).background(Color.blue.opacity(0.18), in: RoundedRectangle(cornerRadius: 14)) } }
private struct StatusPill: View { let text: String; let color: Color; var body: some View { Text("● \(text)").font(.caption.weight(.semibold)).foregroundStyle(color).padding(.horizontal, 10).padding(.vertical, 6).background(.white.opacity(0.08), in: Capsule()) } }
private struct Metric: View { let text: String; let unit: String; let icon: String; var body: some View { HStack(spacing: 4) { Image(systemName: icon).font(.caption2); Text(text).font(.headline); Text(unit).font(.caption2).foregroundStyle(.secondary) }.padding(.horizontal, 9).padding(.vertical, 7).background(.white.opacity(0.08), in: Capsule()) } }
private struct ActionCard: View { let title: String; let icon: String; let enabled: Bool; let action: () -> Void; var body: some View { Button(action: action) { VStack(spacing: 7) { Image(systemName: icon).font(.headline); Text(title).font(.caption) }.frame(maxWidth: .infinity).padding(.vertical, 15).background(.white.opacity(enabled ? 0.08 : 0.04), in: RoundedRectangle(cornerRadius: 14)) }.disabled(!enabled).foregroundStyle(enabled ? .primary : .secondary) } }
private struct SmallCard: View { let title: String; let value: String; let icon: String; var body: some View { VStack(alignment: .leading, spacing: 10) { Label(title, systemImage: icon).font(.subheadline.weight(.semibold)); Text(value).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.leading) }.frame(maxWidth: .infinity, minHeight: 95, alignment: .topLeading).padding(14).background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16)) } }

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
    @StateObject private var bluetooth = ZeehoBluetooth()
    @State private var showConfirm = false
    var body: some View {
        NavigationStack {
            List {
                Section("当前车辆") { Text(session.selectedVehicle?.name ?? "未选择车辆") }
                Section("写入操作") {
                    if session.demoMode {
                        Label("演示模式已禁用车辆控制", systemImage: "lock.slash")
                    } else {
                        Button("寻车（响铃/闪灯）") { showConfirm = true }.disabled(session.selectedVehicle == nil)
                        Text("写操作会改变车辆状态，请确认车辆和网络环境。此版本暂未自动推断车控参数.").font(.footnote).foregroundStyle(.secondary)
                    }
                }
                if !session.demoMode { Section("蓝牙诊断") {
                    Text(bluetooth.state).font(.footnote)
                    Button("扫描 BLE 设备") { bluetooth.scan() }
                    Button("停止扫描") { bluetooth.stop() }
                    ForEach(bluetooth.peripherals, id: \.identifier) { peripheral in
                        Button { bluetooth.connect(peripheral) } label: { Label(peripheral.name ?? "未命名设备", systemImage: "antenna.radiowaves.left.and.right") }
                    }
                    ForEach(bluetooth.characteristics) { item in Text("\(item.service.uuidString) / \(item.characteristic.uuidString)").font(.caption2).textSelection(.enabled) }
                    Text("协议尚未从 APK 中得到车辆专用 UUID 和数据帧，当前用于发现真实 GATT 结构。").font(.footnote).foregroundStyle(.secondary)
                } } else { Section("蓝牙诊断") { Label("演示模式已禁用蓝牙扫描", systemImage: "antenna.radiowaves.left.and.right.slash") } }
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
                    if session.demoMode { Label("当前为演示模式", systemImage: "play.rectangle"); Button("退出演示模式") { session.logout() } }
                    TextField("用户 ID（个人/社区接口需要）", text: $session.userID).textInputAutocapitalization(.never)
                    Button("保存用户 ID") { session.persistUserID() }
                    Button("退出登录", role: .destructive) { session.logout() }
                }
                if !session.demoMode { Section("诊断") { NavigationLink("接口工作台") { APIWorkbenchView() } } }
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
            if let url = Bundle.main.url(forResource: resource, withExtension: "usdz") { QuickLookModelPreview(url: url) }
            else { Text("模型资源缺失").foregroundStyle(.secondary) }
        }.navigationTitle(title).padding()
    }
}

struct QuickLookModelPreview: UIViewControllerRepresentable {
    let url: URL
    func makeCoordinator() -> Coordinator { Coordinator(url: url) }
    func makeUIViewController(context: Context) -> QLPreviewController { let controller = QLPreviewController(); controller.dataSource = context.coordinator; return controller }
    func updateUIViewController(_ controller: QLPreviewController, context: Context) {}
    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL
        init(url: URL) { self.url = url }
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem { url as NSURL }
    }
}
