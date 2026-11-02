import AppKit
import SwiftUI

/// The system Settings scene separates registration/approval from XPC health.
/// Never treat SMAppService.status == .enabled as proof that the daemon is alive.
@MainActor
struct HelperSettingsView: View {
    @Environment(PowerManager.self) private var power
    @State private var status: PowerHelperRegistrationStatus = .notInstalled
    @State private var connectivity: PowerHelperConnectivity = .notChecked
    @State private var bundleIssue: String?
    @State private var isWorking = false
    @State private var isChecking = false
    @State private var showUninstallConfirmation = false
    @State private var showRepairConfirmation = false
    @State private var message: String?
    @State private var isError = false

    var body: some View {
        Form {
            Section("Power Helper") {
                LabeledContent("内嵌文件", value: bundleIssue == nil ? "完整" : "异常")
                LabeledContent("注册与授权", value: status.title)
                LabeledContent("XPC 通信", value: connectivity.title)

                HStack(spacing: 12) {
                    Button("安装 Helper") {
                        install()
                    }
                    .disabled(
                        isWorking || isChecking || bundleIssue != nil ||
                        !(status == .notInstalled || status == .missingService)
                    )

                    Button("修复注册") {
                        showRepairConfirmation = true
                    }
                    .disabled(
                        isWorking || isChecking || bundleIssue != nil ||
                        status != .enabled || !connectivity.needsRepair
                    )
                    .confirmationDialog(
                        "修复 Power Helper 注册？",
                        isPresented: $showRepairConfirmation,
                        titleVisibility: .visible
                    ) {
                        Button("注销并重新注册", role: .destructive) {
                            Task { await repair() }
                        }
                    } message: {
                        Text("仅在当前睡眠设置正常时注销旧服务并重新注册。可能需要再次由管理员批准；不会重置其他应用的后台权限。")
                    }

                    Button("卸载 Helper", role: .destructive) {
                        showUninstallConfirmation = true
                    }
                    .disabled(
                        isWorking || isChecking || status == .notInstalled ||
                        status == .missingService || status == .unavailable
                    )
                    .confirmationDialog(
                        "卸载小工具 Power Helper？",
                        isPresented: $showUninstallConfirmation,
                        titleVisibility: .visible
                    ) {
                        Button("卸载 Helper", role: .destructive) {
                            Task { await uninstall() }
                        }
                    } message: {
                        Text("将先验证系统允许正常睡眠，再注销系统后台服务。")
                    }

                    Button {
                        Task { await refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .help("刷新注册状态与 XPC 通信")
                    .disabled(isWorking || isChecking)
                }

                if status == .requiresApproval {
                    Text("LaunchDaemon 已登记，但仍需管理员在系统设置中批准。")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button("打开登录项与扩展") {
                        power.openHelperApprovalSettings()
                    }
                }

                if let bundleIssue {
                    Label(bundleIssue, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                        .font(.caption)
                }

                if let failure = connectivity.failureDetail, bundleIssue == nil {
                    Label(
                        "系统记录不代表 Helper 正在运行：\(failure)",
                        systemImage: "exclamationmark.triangle"
                    )
                    .foregroundStyle(.orange)
                    .font(.caption)
                    .fixedSize(horizontal: false, vertical: true)
                }

                if let message {
                    Label(message, systemImage: isError ? "exclamationmark.triangle" : "info.circle")
                        .foregroundStyle(isError ? Color.red : Color.secondary)
                        .font(.caption)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Section("说明") {
                Text("安装只提交 SMAppService 注册；只有 XPC 收到 Helper 的实际回复才算通信正常。若已启用但无法连接，可使用“修复注册”。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text("修复或卸载前会检查全局睡眠设置，禁止睡眠尚未恢复时不会注销 Helper。键盘清洁模式不受影响。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 540, height: 440)
        .task { await refresh() }
    }

    private func refresh() async {
        guard !isChecking else { return }
        isChecking = true
        status = power.helperStatus
        bundleIssue = power.helperBundleIssue
        connectivity = status == .enabled && bundleIssue == nil ? .checking : .notChecked
        if connectivity == .checking {
            connectivity = await power.checkHelperConnectivity()
        }
        status = power.helperStatus
        isChecking = false
    }

    private func install() {
        guard !isWorking && !isChecking else { return }
        isWorking = true
        message = nil
        do {
            try power.installHelper()
            isError = false
            message = "注册请求已提交；正在检查授权与实际通信状态。"
        } catch {
            isError = true
            message = describe(error)
        }
        Task {
            await refresh()
            isWorking = false
        }
    }

    private func repair() async {
        guard !isWorking && !isChecking else { return }
        isWorking = true
        message = nil
        do {
            try await power.repairHelper()
            isError = false
            message = "已重新提交注册，请确认管理员授权并查看通信检测结果。"
        } catch {
            isError = true
            message = "修复失败：\(describe(error))"
        }
        await refresh()
        isWorking = false
    }

    private func uninstall() async {
        guard !isWorking && !isChecking else { return }
        isWorking = true
        message = nil
        do {
            try await power.uninstallHelper()
            isError = false
            message = "已注销 Power Helper。"
        } catch {
            isError = true
            message = "卸载失败：\(describe(error))"
        }
        await refresh()
        isWorking = false
    }

    private func describe(_ error: Error) -> String {
        let nsError = error as NSError
        return "\(nsError.localizedDescription) [\(nsError.domain): \(nsError.code)]"
    }
}
