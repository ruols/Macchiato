# 更新日志

所有版本的显著改动记录于此。版本号遵循 `主版本.次版本.修订版本`。

## [1.1.4] - 2026-11-02

### Helper 注册与恢复
- 将 Helper 内嵌文件检查、SMAppService 注册/授权状态和真正的 XPC 可用性分开呈现，不再把 `enabled` 当作 Helper 已运行的证据。
- 增加明确的“修复注册”入口：仅在用户触发时检查 `pmset`、注销旧登记并重新注册，禁止睡眠未恢复则拒绝操作；不触碰其他 App 的后台项目记录。
- 添加独立的只读 XPC 健康探测和超时，暴露 NSError domain/code 便于区分签名、服务登记和通信问题。
- XPC 在免费开发签名无 TeamIdentifier 时绑定同一签名叶证书，避免退化成仅凭 Bundle ID 验证；Ad-hoc Release 情况下无证书则拒绝信任。

### App 图标
- 重新绘制深青色爱心工具箱图标，同步更新 `AppIcon.appiconset` 的全部 10 个 PNG 文件与图标生成脚本；菜单栏咖啡杯图标保持不变。

### 本地签名与说明
- 修正 Apple Development 本地签名脚本中的 designated requirement，将叶证书作为 leaf 而非 root；签名校验通过不代表 LaunchDaemon 一定能启动。
- 补充 Apple 官方 SMAppService / Developer ID 与免费本机开发测试的区别和验收步骤。
- 版本更新至 1.1.4 (6)；保留原有功能和 GitHub Actions 既有密钥配置。

## [1.1.3] - 2026-11-01

### 开发测试
- 新增 `scripts/test-apple-development.sh`：直接使用 Mac 钥匙串里现有的免费 Apple Development 证书，本机一致签署主 App 和 Power Helper。
- 测试包独立保存，不自动覆盖已安装 App，也不将私钥或验证码发送到 GitHub。
- 修复 Helper 已注册但启动失败时无法卸载的问题：若只读 `pmset` 已确认系统允许睡眠，可安全注销，不再必须等待无法启动的 Helper 回复。
- 版本更新至 1.1.3 (5)。

### 说明
- GitHub Actions 的既有固定自签名配置不变。Apple Development 证书仅用于本机试验，仍需实机确认是否满足 macOS 特权 LaunchDaemon 签名要求。

## [1.1.2] - 2026-11-01

### 修复
- GitHub Actions 改为使用 **Release** 而不是 Debug 构建日常安装包，避免 Xcode 的 `Macchiato.debug.dylib` 与固定自签名 + Hardened Runtime 的动态库验证发生冲突。
- 增加安装包检查：阻止包含 Debug 动态库或 `get-task-allow` 调试权限的构建继续打包。
- 更新安装包内的签名说明，区分固定自签名测试包和未配置证书的 Ad-hoc 包。

### 提醒
- 仍为个人自签名、未经 Apple 公证的测试包；首次打开可能需要 macOS 单独批准。
- 是否解决具体 Mac 上无法启动的问题仍需实机验证，可通过终端运行 App 主程序查看 dyld 或 Gatekeeper 诊断。

## [1.1.1] - 2026-11-01

### 新增
- 设置窗口：Power Helper 的状态查看、手动安装、卸载及后台项目授权入口。
- 卸载前会恢复并验证正常睡眠，避免留下全局禁止睡眠的配置；键盘清洁功能保持独立。
- Helper 在系统中使用「小工具 Power Helper」显示名称，不改变系统服务标识。

### 修改
- 移除保持唤醒时的隐式 Helper 自动安装，卸载后不会偷偷重新注册。
- GitHub Actions 支持从仓库 Secrets 导入并使用长期固定签名证书；未配置时仍产出有明确提示的 ad-hoc 测试包。
- 保留原有咖啡杯菜单栏图标和简洁工具箱 App 图标。

### 注意
- 只有完成固定证书配置并使用该证书签出的构建，后续更新才有望持续保留辅助功能权限。
- 自签名证书不能替代 Apple Developer ID 公证，特权 Helper 的系统批准及兼容性仍需实机验证。

## [1.1.0] - 2026-11-01

### 新增
- **键盘清洁模式：** 使用 macOS 辅助功能权限与 Quartz 事件拦截，清洁时临时阻止普通按键及修饰键输入。
- 保留鼠标/触控板操作，并在 **60 秒**后自动恢复键盘；退出程序时主动释放事件拦截。
- 应用显示名称改为 **「小工具」**，采用简洁的原创工具箱 App 图标。

### 界面
- 采用原生 macOS `MenuBarExtra(.window)` 与系统 `Toggle(.switch)`，**没有勾选式菜单项或自绘开关**。
- macOS 26 由系统窗口呈现 Liquid Glass；移除重复的内层玻璃边框。
- 两行设置的图标、文字和开关固定对齐；退出按钮改为**右上角单独的电源图标**。
- 恢复原有咖啡杯菜单栏图标（保持唤醒开启时使用填充状态）。
- 优化深色模式可读性、留白及标题布局。

### 构建和发布
- 在 GitHub Actions 的 macOS 26 / Xcode 26.6 环境构建并校验 App 签名形态。
- 输出 **小工具.dmg** 与 **小工具-macos.zip**；同步更新 Xcode 版本为 **1.1.0 (2)**。
- 保留原有 `PowerManager`、`PowerHelper` 和合盖防睡眠逻辑，未改变内部 Bundle Identifier。

### 已知限制
- 此版本是 **ad-hoc 临时签名测试版**，未使用 Developer ID 签名，也未做 Apple 公证。首次打开可能需要系统手动批准。
- **保持唤醒的特权 Helper** 可能因临时签名无法向 macOS 注册，因此合盖防睡眠功能尚需真实设备验证。
- 受系统限制，部分硬件管理的按键（包括电源键、Touch ID）可能不受清洁模式拦截。
- GitHub Actions 仅验证编译、签名校验和安装包生成；不替代 macOS 实机交互测试。

[1.1.0]: https://github.com/ruols/Macchiato/releases/tag/v1.1.0
