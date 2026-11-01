<p align="center">
  <img src="Macchiato/Assets.xcassets/MacchiatoBase.imageset/macchiato-base.png" width="64" height="64" alt="Macchiato logo" />
</p>

<h1 align="center">小工具（Macchiato Fork）</h1>

<p align="center">
  原生 macOS 菜单栏小工具：保持唤醒、键盘清洁模式。
</p>

## What It Solves

Mac-chiato is built for people who leave long-running work on their Mac: coding agents, local automation, builds, data jobs, model runs, downloads, and anything else that should keep going while you step away.

> **注意：** 原仓库的截图展示的是旧版 Macchiato 界面；本分支已改为「小工具」原生开关界面。

When you need to close your computer, you should be able to close it normally. No leaving the lid slightly open, no changing system settings by hand, and no wondering whether the agent that was halfway through a task got interrupted.

Macchiato gives you a single menu bar switch:

- **On:** keep the Mac awake, including lid-closed use.
- **Off:** restore normal macOS sleep behavior.

## How To Use

1. 从 [Releases](https://github.com/ruols/Macchiato/releases) 下载 **SmallTools-v1.1.0-macOS.dmg**，拖动 App 到「应用程序」。
2. 启动 **小工具**，点击菜单栏原有的咖啡杯图标。
3. 使用原生开关操作 **保持唤醒** 或 **键盘清洁模式**。
4. 键盘清洁模式首次使用需要 macOS 辅助功能权限，60 秒后自动解锁。
5. 菜单右上角电源图标可退出；按下 `⌘Q` 也可退出。

**发布状态：** v1.1.0 为临时（ad-hoc）签名的测试版，未经过 Apple Developer ID 签名与公证。系统级合盖防睡眠依赖特权 Macchiato Helper，在本测试包中**不保证注册成功**；如需可靠使用此功能，应在本机或发布流程中正确签名 App 与 Helper。

## Keyboard Cleaning

Use **Keyboard Cleaning** from the menu bar to temporarily suppress keyboard input while you wipe the keys. Mouse and trackpad input still works: click the same control to unlock. As a safety fallback, the keyboard automatically unlocks after **60 seconds**.

macOS requires **Accessibility** permission in **System Settings > Privacy & Security > Accessibility**. Without that permission, the feature will not activate. Keyboard Cleaning is independent of **Keep Awake** and does not use the privileged power helper.

Ordinary typing, modifier keys, and many system-defined keyboard events are suppressed. Hardware-managed keys such as the power button or Touch ID may still respond. This is a cleaning convenience, not a security lock. If Macchiato quits or crashes, the operating system releases the event tap.

## Good For

- Agents that continue working while you are away from the keyboard.
- Local development servers, builds, test runs, and scripts.
- Long downloads, syncs, exports, or processing jobs.
- Any moment where you want to close the MacBook without babysitting the lid.

For long sessions, keep an eye on battery and heat, especially if the Mac is closed and not plugged in.

## If Something Goes Wrong

If Macchiato is force-quit or crashes while enabled, you can manually restore normal sleep behavior:

```sh
sudo pmset -a disablesleep 0
```

## Helper 管理与签名

进入「小工具」右上角齿轮设置，可查看 Power Helper 的状态，并安装或卸载。安装后可能需要在「系统设置 → 通用 → 登录项与扩展」批准。卸载时先恢复正常睡眠，并进行验证；键盘清洁模式不受影响。详情参阅 [SIGNING.md](SIGNING.md) 配置个人免费长期签名。

## 使用 Apple Development 免费证书本机测试

在自己的 Mac 上签名，不导出私钥、不把验证码交给任何人，也不会覆盖已安装的 App：

```bash
git checkout feature/keyboard-cleaning
bash scripts/test-apple-development.sh
```

脚本默认使用现有 Apple Development 签名 SHA-1 `C20B41BD6C06968B7A8154A02A67D3EB2792295C`。若以后证书更新，可在命令后指定新证书 SHA-1。生成的独立 Release 测试 App 保存在 `dist/AppleDevelopmentLocal/`。安装前先退出并备份已有 App，在设置中注销旧 Helper（系统已允许正常睡眠时可以在无 XPC 响应的情况下安全注销）。将新的测试 App 安装到 `/Applications/小工具.app` 后，再从设置安装 Helper 并批准。

此步骤只验证开发证书能否被 macOS 接受，不保证免费 Personal Team 一定支持特权 LaunchDaemon。详见 [SIGNING.md](SIGNING.md)。

## 更新日志

查看 [CHANGELOG.md](CHANGELOG.md) 了解各版本改动。

## Development

Macchiato uses an IOKit `PreventUserIdleSystemSleep` assertion plus macOS' `pmset disablesleep` setting. The app ships a privileged LaunchDaemon helper, installed through `SMAppService`, so the system-level `pmset` work is approved once instead of prompting on every toggle.

Internal distribution uses the project's private signing flow. Release builds must not include debug signing entitlements such as `get-task-allow`, and the app and embedded helper must be signed consistently before packaging the DMG. Users approve/trust the internal build through macOS, then Macchiato registers the helper through `SMAppService`.

Build locally:

```sh
xcodebuild -project Macchiato.xcodeproj -scheme Macchiato -configuration Debug build
```

Build the internal distribution DMG:

```sh
scripts/build-dmg.sh
```

Additional `xcodebuild` build settings can be passed through when needed by the internal signing flow.

The `Macchiato` target depends on `Macchiato Power Helper` and embeds the helper executable plus its launchd plist into:

```text
Macchiato.app/Contents/MacOS/app.macchiato.Macchiato.PowerHelper
Macchiato.app/Contents/Library/LaunchDaemons/app.macchiato.Macchiato.PowerHelper.plist
```

## Verify The Assertion

Launch the app, turn on **Keep Awake**, then run:

```sh
pmset -g assertions | grep Macchiato
```

You should see a `PreventUserIdleSystemSleep` assertion named `Macchiato is keeping your Mac awake`.

You can also verify the lid-closed sleep setting:

```sh
pmset -g live | grep SleepDisabled
```

## Local Sleep Logging Test

The repo includes two local scripts for manual acceptance testing:

```sh
scripts/sleep-log-runner.sh --scenario lid-closed-off
scripts/sleep-log-runner.sh --scenario keep-awake-on
scripts/analyze-sleep-log.sh sleep-test-logs/*.csv
```

Suggested flow:

1. Ensure Macchiato is off, start `scripts/sleep-log-runner.sh --scenario lid-closed-off`, close the lid or otherwise trigger the sleep condition, wait 10 minutes, reopen the Mac, then stop the logger with Ctrl+C.
2. Turn on **Keep Awake**, start `scripts/sleep-log-runner.sh --scenario keep-awake-on`, repeat the 10 minute window, reopen the Mac, then stop the logger.
3. Run `scripts/analyze-sleep-log.sh sleep-test-logs/*.csv`.

The analyzer reports sample count, wall time, maximum timestamp gap, whether the Macchiato power assertion was observed, and how many samples saw `SleepDisabled=1`. A large gap means the logger stopped running during the test window, which usually indicates sleep.
