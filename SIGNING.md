# 小工具：长期稳定签名

当前 GitHub Actions 支持 Apple Development 和固定自签名证书，未设置三项 Repository Secrets 时使用 Ad-hoc。需要注意：**自签名证书可用于普通 App，但在 macOS 上可能无法通过特权 LaunchDaemon 的启动约束校验。**

## 将已验证可用的 Apple Development 证书用于 GitHub Actions

本机已验证的签名身份是 `Apple Development: jsnjycwyz@gmail.com (W682PV296P)`（SHA-1：`93A7B24B7972673159533F9B5B84DA46273806C8`）。
此证书已在本机通过 SMAppService LaunchDaemon 启动、XPC 通信以及 `pmset` 开关测试；不等于具有 Developer ID 公证能力。

1. 在 Mac **Xcode → Settings → Accounts → 对应 Apple Account → Manage Certificates**，右键 Apple Development 证书，选择 **Export Certificate**，导出带私钥且有强密码保护的 `.p12`。也可以在“钥匙串访问”的“我的证书”里导出带私钥的身份。
2. 在 Mac 上执行 `base64 -i "/path/to/AppleDevelopment.p12" | tr -d '\n' | pbcopy`，将 Base64 粘贴到仓库 `Settings → Secrets and variables → Actions` 中的 `SMALLTOOLS_CERT_P12_BASE64`，**只在 GitHub Secrets 页面粘贴**。
3. 将刚才为 P12 设置的密码写入 `SMALLTOOLS_CERT_P12_PASSWORD`，将上述 SHA-1 写入 `SMALLTOOLS_SIGN_IDENTITY`；更新已有同名 Secret，不要在仓库提交 P12、密码或 Base64。
4. 在仓库 Actions 页手动运行 `Build` 工作流（`feature/keyboard-cleaning` 分支），检查 `Sign app and bundled helper` 步骤。
5. 此工作流会只对自签名证书额外设置信任。Apple Development 证书走系统 Apple 根证书链，同时给 App/Helper 写入与本机成功测试一致的显式 leaf SHA-1 DR。构建校验通过后，再在自己的 Mac 上注销旧 Helper、安装更新包并重新注册，检查 XPC 和 `SleepDisabled`。

**注意安全：** `.p12` 包含签名私钥。存储在 GitHub Actions Secrets 意味着信任 GitHub 托管构建环境与有工作流写入权限的人；对公开仓库尤其需要保护工作流修改权限。不想把私钥放在云端时，继续在本机签名即可。导出的 P12 应妥善加密保管或安全删除，并及时清理剪贴板。

## 使用现有免费 Apple Development 证书进行本机试验

你的 Mac 已有 Apple Development 开发证书（本地测试默认证书 SHA-1：`93A7B24B7972673159533F9B5B84DA46273806C8`）。在本机运行：

```bash
bash scripts/test-apple-development.sh
```

它会使用本机 Keychain 中的身份编译 Release 并签名主 App、Power Helper，然后通过显式指定叶证书 DR 验证主 App 与 Helper 的完整签名。`TeamIdentifier=not set` 会显示警告，而非误报文件签名失败。输出到被 Git 忽略的 `dist/AppleDevelopmentLocal/`，**不导出任何证书、私钥或验证码，不修改 GitHub Secrets，也不覆盖旧 App**。证书到期或更换后可将新 SHA-1 作为第一个参数。

如果 Xcode 提示 Apple ID 需要验证，在你自己的 Mac 的 **Xcode → 设置 → Accounts** 中操作即可。免费账号的描述文件可能有 7 天限制；Apple Development 证书有效期是另一个概念。

请先退出旧版 App，备份旧 App 到 `/Applications` 以外的目录，尽量通过「设置 → 卸载 Helper」注销旧服务后再手动安装新 App 到 `/Applications/小工具.app`。新 App 上安装 Helper 后检查 `sudo launchctl print system/app.macchiato.Macchiato.PowerHelper` 和签名拒绝日志。**Apple Development 证书不是 Developer ID，能否通过特权服务校验需要实测。**

## Apple 官方要求：免费 Apple Development 与特权 Helper

- Apple 的 [Getting Started with SMAppService](https://developer.apple.com/forums/thread/802443) 给出了在 Xcode 中编译、注册 LaunchDaemon、由管理员批准的完整开发流程，**没有将付费 Developer ID 写成开发测试的前置条件**。
- Apple 官方 [register() 文档](https://developer.apple.com/documentation/servicemanagement/smappservice/register%28%29) 指明：LaunchDaemon 注册后，需要管理员批准；`enabled` 只表示有资格运行，不保证 XPC 已连接。
- Apple DTS 在 [相关论坛回复](https://developer.apple.com/forums/thread/799910) 特别指出：主 App 和内嵌 Helper 应当使用**同一个 Apple 签发的代码签名身份**，ad-hoc 签名可能导致注册、重启时异常。
- Apple 的 [独立分发签名文档](https://developer.apple.com/documentation/xcode/creating-distribution-signed-code-for-the-mac/) 与 [公证要求](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution) 要求 Developer ID；**免费的 Apple Development 不是用于独立分发、公证的替代品**。
- 因此：本机使用免费 Apple Development **可以进行构建、签名、注册测试**，但 Mac 上能否实际获批启动 root 级 LaunchDaemon 必须实测。当前系统曾报告 `TeamIdentifier=not set`，不能用 `codesign --verify` 成功替代启动结论。

### 新版 Helper 安装 / 修复逻辑

- **内嵌文件：** 先检查可执行 Helper 和 LaunchDaemon plist 的路径与关键字段。
- **注册与授权：** 按 `SMAppService.status` 分辨未注册、待批准、可运行与找不到服务。
- **真实可用性：** 独立进行只读 XPC 健康检查；只收到 Helper 回复才显示“通信正常”。
- **修复注册：** 仅由用户主动触发。在确认 `pmset -g live` 不再禁止睡眠后，通过 `SMAppService.unregister()` 再 `register()` 重建登记。不会调用 `launchctl bootstrap`、不会直接编辑后台项目数据库，也不会自动全局 `sfltool resetbtm`。
- **可诊断错误：** 保留 ServiceManagement / XPC 原始 NSError domain 和 code；“已注册但无法运行”不再被误显示为“已安装并启用”。
- 不要同时启动上游原版 Macchiato 与此分支：它们共享 Bundle ID、Daemon label 与 Mach service 名称，容易相互干扰。

## 故障定位

在 App 的“Helper 设置”窗口查看“内嵌文件 / 注册与授权 / XPC 通信”三项。
如果提示“注册与授权：已注册”但“XPC 通信：无法连接”，检查系统服务：

```bash
sudo launchctl print system/app.macchiato.Macchiato.PowerHelper
sudo log show --last 10m --info --style compact --predicate 'eventMessage CONTAINS[c] "app.macchiato.Macchiato.PowerHelper"' | tail -60
```

如果签名被 AMFI 拒绝，先修签名；如果系统仍在等待批准，使用 App 内的“打开登录项与扩展”；如果已批准但失联，使用“修复注册”，并根据错误域与错误码继续定位。不要将 `sfltool resetbtm` 当作常规安装步骤。

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
