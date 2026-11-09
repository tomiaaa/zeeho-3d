# ZeehoPanel native iOS project

这是 SwiftUI 原生工程，未使用 WebView、Capacitor 或网页资源。最低部署版本为 iOS 16。

在 macOS 上用 Xcode 15 或更高版本打开 `ZeehoPanel.xcodeproj`。首次运行前，在应用设置页填写服务端要求的 `appId`、`appSecret` 与登录 `Basic` 凭据。工程不会内置这些敏感凭据。

当前原生实现包含手机号验证码登录、车辆列表、车况概览、刷新车辆数据和本地 token 保存。API 签名算法与现有接口文档一致，后续页面可在 `ZeehoAPI.swift` 上继续扩展。
