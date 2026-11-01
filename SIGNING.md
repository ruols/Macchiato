# 小工具：长期稳定签名

当前 GitHub Actions 支持固定自签名证书，未设置三项 Repository Secrets 时使用 Ad-hoc。需要注意：**自签名证书可用于普通 App，但在 macOS 上可能无法通过特权 LaunchDaemon 的启动约束校验。**

## 使用现有免费 Apple Development 证书进行本机试验

你的 Mac 已有 Apple Development 开发证书（SHA-1：`C20B41BD6C06968B7A8154A02A67D3EB2792295C`）。在本机运行：

```bash
bash scripts/test-apple-development.sh
```

它会使用本机 Keychain 中的身份编译 Release 并签名主 App、Power Helper，然后验证签名和 TeamIdentifier。输出到被 Git 忽略的 `dist/AppleDevelopmentLocal/`，**不导出任何证书、私钥或验证码，不修改 GitHub Secrets，也不覆盖旧 App**。证书到期或更换后可将新 SHA-1 作为第一个参数。

如果 Xcode 提示 Apple ID 需要验证，在你自己的 Mac 的 **Xcode → 设置 → Accounts** 中操作即可。免费账号的描述文件可能有 7 天限制；Apple Development 证书有效期是另一个概念。

请先退出旧版 App，备份旧 App 到 `/Applications` 以外的目录，尽量通过「设置 → 卸载 Helper」注销旧服务后再手动安装新 App 到 `/Applications/小工具.app`。新 App 上安装 Helper 后检查 `sudo launchctl print system/app.macchiato.Macchiato.PowerHelper` 和签名拒绝日志。**Apple Development 证书不是 Developer ID，能否通过特权服务校验需要实测。**

## 不付费的方案：固定的自签名代码签名证书

1. 在你自己的 Mac 打开 **钥匙串访问（Keychain Access）**，通过 **证书助理 → 创建证书** 创建一张专用于代码签名的长期自签名证书，例如 `SmallTools Local Code Signing`（Certificate Type: Code Signing；创建时保留私钥）。不要每个版本重新创建。
2. 在钥匙串中将这张证书及其私钥导出为 **PKCS#12（.p12）**，设置强密码。妥善备份，**绝对不要提交到 GitHub 仓库或在聊天中发送私钥**。
3. 在 Mac 终端运行 `security find-identity -v -p codesigning`，确保该签名身份可以用来签署代码。自签名证书可能需要在本机设置适当信任；只信任你自己生成、自己保管的证书。
4. 在本机把 .p12 转成一行 Base64，例如 `base64 -i /path/to/certificate.p12 | tr -d '\\n' | pbcopy`，复制后不要粘贴到公开页面。
5. 打开仓库 GitHub → Settings → Secrets and variables → Actions，添加以下三个 **Repository secrets**：

| Secret | 值 |
| --- | --- |
| `SMALLTOOLS_CERT_P12_BASE64` | .p12 文件 Base64 内容 |
| `SMALLTOOLS_CERT_P12_PASSWORD` | .p12 导出时设置的密码 |
| `SMALLTOOLS_SIGN_IDENTITY` | `security find-identity -v -p codesigning` 显示的证书名称或 SHA-1 身份 ID |

6. 以后每次 Actions 构建都会导入同一份证书，为内嵌 dylib、Power Helper 和主 App 使用同一个签名身份，并验证包签名。
7. **首次**从旧 Ad-hoc 签名切换到自签名版本，通常需要重新批准辅助功能；后续保持相同证书、Bundle ID 和安装路径时，权限一般可延续，但以你的 macOS 实测为准。

## 限制与安全

- 免费 **Apple Development / Personal Team** 签名与独立自签名证书不等同于付费 **Developer ID**。自签名程序**没有 Apple 公证**，系统可能要求手动放行。
- **特权 Helper 属于 root 级 LaunchDaemon。** 即使成功签名，`SMAppService` 是否接受以及系统是否批准特权服务仍需实机验证；固定签名并不保证它一定能安装。
- 自签名证书及私钥是敏感材料，只保存在你的 Mac 钥匙串与 GitHub 加密 Secrets 中。不要把生成证书/私钥的流程放到每次 GitHub Actions 构建中。
- 未配置任何上述 Secrets 时，Actions 仍生成 Ad-hoc 测试包，并明确警告辅助功能权限可能在更新后失效；只配置部分 Secrets 会令构建失败以避免误签。
- 建议不要将此签名方案用于公开向不受信任用户分发；可靠的公开分发仍应使用 Developer ID 并公证。

## 发布流程

普通分支推送只构建可下载的 GitHub Actions Artifact，不修改已经发布的 Release；只有显式创建新的 `v*` Tag 才触发新的预发布 Release，并禁止覆盖相同版本。
