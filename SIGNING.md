# 小工具：长期稳定签名

目前仓库的默认 GitHub Actions 构建只有 **Ad-hoc 临时签名**。每次代码改变都会改变应用的代码身份，macOS TCC 可能要求重新授权键盘清洁模式使用的辅助功能。

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
