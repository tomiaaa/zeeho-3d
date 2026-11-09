# GitHub Actions 构建 IPA

把本项目上传到 GitHub 后，在仓库 `Settings > Secrets and variables > Actions` 添加以下 Secrets：

`IOS_CERTIFICATE_BASE64`（发布证书 `.p12` 的 base64）、`IOS_CERTIFICATE_PASSWORD`、`IOS_KEYCHAIN_PASSWORD`、`IOS_PROVISIONING_PROFILE_BASE64`（profile 的 base64）、`IOS_TEAM_ID`、`IOS_PROFILE_NAME`、`IOS_EXPORT_METHOD`（通常为 `ad-hoc`、`app-store` 或 `development`）。

在 `Actions > Build native iOS app > Run workflow` 启动构建。成功后从 workflow 的 Artifacts 下载 `ZeehoPanel-ipa`。证书、profile 和密码只放 GitHub Secrets，不要提交到仓库。

越狱设备可尝试使用未签名构建：进入 `Actions > Build unsigned jailbreak IPA > Run workflow`，不需要添加上述 Secrets。成功后下载 `ZeehoPanel-unsigned-ipa`。该文件没有 Apple 签名，只适用于支持未签名安装的越狱工具，普通 iPhone 无法安装。
