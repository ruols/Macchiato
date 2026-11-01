import AppKit
import SwiftUI

/// A system Settings scene, separate from the menu bar's native window.
@MainActor
struct HelperSettingsView: View {
    @Environment(PowerManager.self) private var power
    @State private var status: PowerHelperRegistrationStatus = .notInstalled
    @State private var isWorking = false
    @State private var showUninstallConfirmation = false
    @State private var message: String?
    @State private var isError = false

    var body: some View {
        Form {
            Section("电源管理") {
                LabeledContent("Power Helper 状态", value: status.title)

                HStack(spacing: 12) {
                    Button("安装 Helper") {
                        install()
                    }
                    .disabled(isWorking || status == .enabled || status == .requiresApproval)

                    Button("卸载 Helper", role: .destructive) {
                        showUninstallConfirmation = true
                    }
                    .disabled(isWorking || status == .notInstalled || status == .unavailable)

                    Button {
                        refresh()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .help("刷新 Helper 状态")
                    .disabled(isWorking)
                }

                if status == .requiresApproval {
                    Text("安装请求已提交，请到系统设置批准后台项目。")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button("打开登录项与扩展") {
                        power.openHelperApprovalSettings()
                    }
                }

                if let message {
                    Label(message, systemImage: isError ? "exclamationmark.triangle" : "checkmark.circle")
                        .foregroundStyle(isError ? Color.red : Color.secondary)
                        .font(.caption)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Section("说明") {
                Text("Helper 用于系统级防睡眠（包括合盖场景）。卸载前会尝试恢复正常睡眠设置并验证结果；卸载后需要再次手动安装才能使用“保持唤醒”。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text("键盘清洁模式不需要 Power Helper，卸载不会影响它。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 510, height: 305)
        .task { refresh() }
        .confirmationDialog(
            "卸载小工具 Power Helper？",
            isPresented: $showUninstallConfirmation,
            titleVisibility: .visible
        ) {
            Button("卸载 Helper", role: .destructive) {
                Task { await uninstall() }
            }
        } message: {
            Text("将先恢复正常睡眠设置，再注销系统后台服务。键盘清洁模式不受影响。")
        }
    }

    private func refresh() {
        status = power.helperStatus
    }

    private func install() {
        guard !isWorking else { return }
        isWorking = true
        message = nil
        do {
            try power.installHelper()
            isError = false
            message = "安装请求已提交，请按系统提示批准。"
        } catch {
            isError = true
            message = error.localizedDescription
        }
        refresh()
        isWorking = false
    }

    private func uninstall() async {
        guard !isWorking else { return }
        isWorking = true
        message = nil
        do {
            try await power.uninstallHelper()
            isError = false
            message = "已注销 Power Helper。"
        } catch {
            isError = true
            message = error.localizedDescription
        }
        refresh()
        isWorking = false
    }
}
