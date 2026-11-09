# GitHub Actions 构建 IPA

把本项目上传到 GitHub 后，在仓库 `Settings > Secrets and variables > Actions` 添加以下 Secrets：

`IOS_CERTIFICATE_BASE64`（发布证书 `.p12` 的 base64）、`IOS_CERTIFICATE_PASSWORD`、`IOS_KEYCHAIN_PASSWORD`、`IOS_PROVISIONING_PROFILE_BASE64`（profile 的 base64）、`IOS_TEAM_ID`、`IOS_PROFILE_NAME`、`IOS_EXPORT_METHOD`（通常为 `ad-hoc`、`app-store` 或 `development`）。

在 `Actions > Build native iOS app > Run workflow` 启动构建。成功后从 workflow 的 Artifacts 下载 `ZeehoPanel-ipa`。证书、profile 和密码只放 GitHub Secrets，不要提交到仓库。

越狱设备可使用 ad-hoc 构建：进入 `Actions > Build unsigned jailbreak IPA > Run workflow`，不需要添加上述 Secrets。工作流使用 macOS `codesign` 做 ad-hoc 签名（不使用 Apple 开发者证书），再打包 IPA。成功后下载 `ZeehoPanel-unsigned-ipa`，用 TrollStore 安装。普通 iPhone 无法安装。
