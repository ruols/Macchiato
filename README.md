<p align="center">
  <img src="Macchiato/Assets.xcassets/MacchiatoBase.imageset/macchiato-base.png" width="64" height="64" alt="Macchiato logo" />
</p>

<h1 align="center">小工具（Macchiato Fork）</h1>

<p align="center">
  原生 macOS 菜单栏工具：保持唤醒（含合盖场景）与键盘清洁模式。
</p>

> 本分支在 [Macchiato 原项目](https://github.com/ObservedObserver/Macchiato) 基础上增加键盘清洁模式、原生设置界面、Power Helper 手动管理及签名诊断。原项目的截图可能与当前界面不同。

## 功能

- **保持唤醒：** 使用 IOKit 电源断言，并通过系统级 Power Helper 调用 `pmset`，在启用时设置 `SleepDisabled = 1`，关闭时恢复为 `0`。合盖持续运行能力还应结合机型、供电和 macOS 行为进行实际测试。
- **键盘清洁模式：** 临时屏蔽普通键盘输入，鼠标、触控板保持可用；可手动解锁，60 秒后自动解锁。需要 macOS「辅助功能」授权，**不依赖 Power Helper**。
- **原生界面：** 菜单栏咖啡杯图标、原生开关、独立设置窗口及退出按钮。
- **可诊断的 Helper 管理：** 区分内嵌文件、系统注册与授权、XPC 实际通信状态；提供安装、卸载与在安全条件下修复注册的操作。

**系统要求：** macOS 14 或更新版本。当前项目版本为 **1.1.4 (6)**。

## 下载与安装

### 获取安装包

- **当前开发分支构建：** 前往 [GitHub Actions — Build](https://github.com/ruols/Macchiato/actions/workflows/build.yml)，选择 `feature/keyboard-cleaning` 分支最新成功的构建，在 **Artifacts** 中下载 `SmallTools-macOS-App`，解压后使用其中的 `小工具.dmg` 或 `小工具-macos.zip`。
- **已发布版本：** 前往 [Releases](https://github.com/ruols/Macchiato/releases)。Release 可能落后于开发分支，请以发布页面标注的版本号为准。

目前 GitHub Actions 可以从 Repository Secrets 导入 **Apple Development** 签名身份，使用相同证书签署主 App 和内嵌 Power Helper。此签名方式已经在项目维护者的 Mac 上完成 LaunchDaemon、XPC 以及电源开关的实机验证，**但构建包未经过 Apple Developer ID 公证，不应视为适用于所有 Mac 的正式分发包**。详情见 [SIGNING.md](SIGNING.md)。

### 首次安装

1. 如果 Mac 上已有原版 Macchiato 或旧版小工具，请先按下文的[更新前安全处理](#更新应用或修改-app-名称)关闭保持唤醒、注销旧 Helper。**原版与此分支使用相同的 Bundle ID 和 Power Helper 服务名，不能当作两个独立应用并行安装使用。**
2. 打开 DMG，将 App 复制到「应用程序」（`/Applications`）。建议统一命名为 `小工具.app`。**重命名或移动 App 前应先卸载已注册的 Helper；不是必须使用这一文件名，但安装路径尽量保持稳定。**
3. 启动小工具（菜单栏咖啡杯图标）。若 macOS 拦截未公证应用，请根据系统显示的来源、安全提示决定是否在「系统设置 → 隐私与安全性」允许打开；不要关闭 SIP 或全局安全校验。
4. 点击小工具设置（齿轮图标），检查 **Power Helper** 区域的「内嵌文件」「注册与授权」「XPC 通信」。
5. 点击 **「安装 Helper」**。如果提示需要授权，前往「系统设置 → 通用 → 登录项与扩展」批准该系统后台服务；LaunchDaemon 需要管理员批准后才能启动。
6. 返回设置并点击刷新，直到显示 **「注册与授权：已登记，允许启动」** 且 **「XPC 通信：通信正常」**。仅仅显示已登记，并不代表 Helper 已经运行。
7. 如果需要键盘清洁模式，按系统提示单独授予「辅助功能」权限。

### 验证是否生效

在小工具中打开「保持唤醒」，然后运行：

```bash
pmset -g live | grep -i SleepDisabled
```

预期出现 `SleepDisabled 1`。在小工具中**关闭**「保持唤醒」，重新运行同一命令，预期恢复为 `SleepDisabled 0`。两个方向都成功才说明电源控制链路已验证；合盖运行需另行实测。

如需检查运行中的 Helper，可执行：

```bash
sudo launchctl print system/app.macchiato.Macchiato.PowerHelper
```

它应显示运行中的服务。需要确认服务来自哪个 App 包时：

```bash
PID="$(sudo launchctl print system/app.macchiato.Macchiato.PowerHelper 2>/dev/null |
  awk '/^[[:space:]]*pid = / {print $3; exit}')"
if [ -n "$PID" ]; then
  sudo lsof -p "$PID" | grep 'PowerHelper'
else
  echo "未发现正在运行的 Power Helper"
fi
```

路径应该指向当前实际安装的 App（例如 `/Applications/小工具.app/Contents/MacOS/app.macchiato.Macchiato.PowerHelper`），而不是已经删除或替换的旧版本。

## 更新应用或修改 App 名称

**不要直接覆盖、移动或重命名一个仍注册着 Helper 的 App。** 系统可能继续运行旧路径的 Helper，导致新 App 报 XPC 签名不匹配（如 `NSCocoaErrorDomain 4102`）。

推荐流程：

1. 关闭「保持唤醒」，用 `pmset -g live | grep -i SleepDisabled` 确认结果为 `0`。
2. 在旧 App 的设置中点击 **「卸载 Helper」**，按提示确认，等待成功消息。
3. 使用 `sudo launchctl print system/app.macchiato.Macchiato.PowerHelper` 验证旧服务已消失。
4. 完全退出旧 App；备份后替换 App，或在 Finder 中重命名 / 移动 App。
5. 启动新 App，点击 **「安装 Helper」**，需要时重新批准后台服务。
6. 刷新确认 **XPC 通信正常**，重新测试 `SleepDisabled` 在 `1` 与 `0` 之间正确切换。

如果同一安装路径与签名身份始终不变，有时更新后无需重新授权；但只要出现旧 Helper 路径、XPC 4102 或无法连接，就应按上述步骤核查，而不是连续点击修复或重置整个后台项目数据库。

## 完整卸载：先 Helper，后 App

**直接将 App 拖入废纸篓并不能作为完整卸载步骤。** Power Helper 是由 macOS `launchd` 管理、以 root 权限运行的 LaunchDaemon。应先通过 App 内的 `SMAppService.unregister()` 注销，确认系统不再运行该服务，最后再删除 App。卸载前恢复正常睡眠尤其重要。

### A. 正常卸载（推荐）

**步骤 1：关闭保持唤醒。** 打开小工具，关闭「保持唤醒」开关，等待操作完成。不要在开关仍显示处理中时退出应用。

**步骤 2：检查系统是否允许睡眠。** 在「终端」执行：

```bash
pmset -g live | grep -i SleepDisabled
```

正常情况下应显示：

```text
SleepDisabled        0
```

如果显示 `SleepDisabled 1`，请先在 App 中尝试关闭「保持唤醒」。如 App 或 Helper 已无法连接，且你确定要取消本工具设置的全局禁止睡眠，可使用管理员权限恢复：

```bash
sudo pmset -a disablesleep 0
pmset -g live | grep -i SleepDisabled
```

**只有确认不再处于 `SleepDisabled 1` 时，才继续注销 Helper。** 上述 `pmset` 是修改系统全局电源设置的命令，如果其他软件或维护任务有意使用该设置，应先协调这些用途。

**步骤 3：在 App 内卸载 Helper。** 打开菜单栏咖啡杯 → 齿轮设置 → **「卸载 Helper」** → 再次确认。等待提示 **「已注销 Power Helper」**。这个操作会调用 `SMAppService.unregister()`，而不只是关闭后台登录项开关。已注册但无法通信的 Helper，只要正常睡眠设置经过确认，也可以安全地尝试注销。

**步骤 4：确认系统服务已消失。** 执行：

```bash
sudo launchctl print system/app.macchiato.Macchiato.PowerHelper
```

卸载成功后，预期输出类似：

```text
Could not find service "app.macchiato.Macchiato.PowerHelper" in domain for system
```

这属于**预期结果**，说明 `launchd` 已找不到该服务，而不是卸载失败。再检查是否还有同名进程：

```bash
pgrep -fl 'app.macchiato.Macchiato.PowerHelper' || echo "未发现 Power Helper 进程"
```

**步骤 5：退出并删除 App。** 确认旧服务已消失后，点击小工具右上角退出按钮（或按 `⌘Q`），再通过 Finder 从「应用程序」将当前 App 拖入废纸篓。App 可以叫 `小工具.app`、`Macchiato.app` 或其他名字，**按实际安装文件名删除，不要照搬路径猜测**。

**步骤 6：可选清理权限。** 如果不再使用，打开「系统设置 → 隐私与安全性 → 辅助功能」，检查并移除该 App 已不需要的授权记录；也可以在「通用 → 登录项与扩展」查看是否还有对应后台项目记录。已被系统保留的历史显示记录不等同于 Helper 仍在运行，最终以 `launchctl` 和进程检查为准。

### B. 卸载失败、旧 App 已删除或 Helper 无法连接

| 遇到的问题 | 安全处理 |
| --- | --- |
| 提示“尚未成功恢复正常睡眠”或 `SleepDisabled 1` | 先恢复正常睡眠并验证为 `0`，不要强行卸载正在控制全局电源状态的 Helper。 |
| 提示 `Couldn't communicate with a helper application`、XPC 4102、或卸载失败 | 保留 App，记录错误信息，检查是否与旧版 Helper 共用相同服务标识；在确认睡眠正常后重新尝试 App 内卸载。 |
| App 已删除，但 `launchctl` 仍显示旧 Helper | 尽量恢复原来**相同路径和签名身份**的 App 后，从设置执行“卸载 Helper”；不应仅靠删除进程或 plist 假装完成注销。 |
| Helper 显示“已登记，允许启动”，但 XPC 无法连接 | 先核对 `launchctl` 和实际加载路径；确认睡眠正常后可在 App 内使用“修复注册”。**修复注册是为继续使用而设计，不是完整卸载的替代步骤。** |
| `launchctl` 显示服务不存在且无同名进程 | Helper 已不在该 system 域运行，可以继续删除 App；无需仅因为历史 BTM 条目而重置系统数据库。 |

**不建议作为常规卸载操作：** `kill -9` 强杀 Helper、`launchctl bootstrap/bootout` 手动替代 `SMAppService`、直接删除系统 plist、`sudo sfltool resetbtm` 全局重置后台项目、禁用 SIP/AMFI。这些操作可能造成服务重新启动、注册状态不一致，或影响其他 App。若无法用 App 安全注销，应先诊断具体错误。

### C. 卸载结束后的最终检查

```bash
pmset -g live | grep -i SleepDisabled
sudo launchctl print system/app.macchiato.Macchiato.PowerHelper
pgrep -fl 'app.macchiato.Macchiato.PowerHelper' || echo "未发现 Power Helper 进程"
```

理想状态是 `SleepDisabled 0`、`launchctl` 找不到服务、没有 Helper 进程。此时再删除 App 即可；不需要卸载某个单独的“Helper.app”，也不需要删除本机 Apple Development 签名证书。

## 常见问题

**为什么显示“已登记，允许启动”，却仍无法使用？**  
`SMAppService.status == .enabled` 表示服务已登记、有资格运行，**不保证 XPC 已收到回复**。请以设置中的 **XPC 通信**状态为准。如果失败，先检查 Helper 实际运行路径，特别是电脑上存在原版 Macchiato、旧版小工具或曾改名的 App 时。

**“修复注册”和“卸载 Helper”有什么区别？**  
“修复注册”会在安全检查后注销并重新注册服务，目的是恢复继续使用；“卸载 Helper”只注销，之后不应再自动安装。二者都不会自动删除 App。

**免费 Apple Development 证书能用吗？**  
已在一台 Mac 上实测成功：App 与 Helper 使用相同的 Apple Development 签名，通过管理员批准、LaunchDaemon 以 root 启动、XPC 通信正常，以及 `SleepDisabled` 在开启和关闭时正确切换。原自签名证书曾被 macOS 以未知签名链拒绝。**这不代表 Apple Development 可替代 Developer ID 进行公众分发或公证。**

**更新签名证书或修改 App 名称是否影响 Helper？**  
可能影响。保持 App / Helper 身份一致，并尽可能固定安装路径；证书变更、App 移动或重命名之前请先注销旧 Helper，完成变更后重新注册。

## 开发与签名

项目使用 IOKit `PreventUserIdleSystemSleep` 断言配合 Power Helper 执行 `pmset -a disablesleep 1/0`。Helper 随 App 一同打包，不要求用户手动向 `/Library/PrivilegedHelperTools` 复制可执行文件；使用 `SMAppService` 管理系统后台服务。

```text
小工具.app/Contents/MacOS/app.macchiato.Macchiato.PowerHelper
小工具.app/Contents/Library/LaunchDaemons/app.macchiato.Macchiato.PowerHelper.plist
```

本地 Debug 构建：

```bash
xcodebuild -project Macchiato.xcodeproj -scheme Macchiato -configuration Debug build
```

本地打包：

```bash
scripts/build-dmg.sh
```

本机 Apple Development 签名测试可参考 [SIGNING.md](SIGNING.md) 与 `scripts/test-apple-development.sh`；无需把证书私钥提交到仓库。GitHub Actions 签名使用 Repository Secrets，正式向其他用户独立分发通常需要 Developer ID 签名与 Apple 公证。

Apple 官方文档：[SMAppService](https://developer.apple.com/documentation/servicemanagement/smappservice) · [register()](https://developer.apple.com/documentation/servicemanagement/smappservice/register%28%29) · [unregister()](https://developer.apple.com/documentation/servicemanagement/smappservice/unregister%28%29)。

## 电源 / 合盖测试

可以使用仓库中的脚本进行更长时间的睡眠日志测试：

```bash
scripts/sleep-log-runner.sh --scenario lid-closed-off
scripts/sleep-log-runner.sh --scenario keep-awake-on
scripts/analyze-sleep-log.sh sleep-test-logs/*.csv
```

先验证 `SleepDisabled` 能正确恢复为 `0`，再进行合盖测试。注意电池、温度与散热情况，尤其是合盖长时间运行时。

## 更新日志

参阅 [CHANGELOG.md](CHANGELOG.md)。
