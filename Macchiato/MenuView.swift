import AppKit
import SwiftUI

@MainActor
struct MenuView: View {
    @Environment(PowerManager.self) private var power
    @Environment(KeyboardLockManager.self) private var keyboard

    private var powerBinding: Binding<Bool> {
        Binding(
            get: { power.isActive },
            set: { enabled in
                guard !power.isChanging else { return }
                Task { await power.setActive(enabled) }
            }
        )
    }

    private var keyboardBinding: Binding<Bool> {
        Binding(
            get: { keyboard.isLocked },
            set: { enabled in
                if enabled { keyboard.lock() } else { keyboard.unlock() }
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Text("小工具")
                    .font(.title3)
                    .fontWeight(.semibold)

                Spacer(minLength: 0)

                quitButton
            }

            VStack(spacing: 20) {
                settingRow(
                    "保持唤醒",
                    subtitle: "阻止 Mac 进入系统睡眠",
                    symbol: "moon.zzz",
                    isOn: powerBinding,
                    isDisabled: power.isChanging
                )

                settingRow(
                    "键盘清洁模式",
                    subtitle: "临时屏蔽键盘输入",
                    symbol: "keyboard",
                    isOn: keyboardBinding
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if power.isChanging {
                Label("正在更新睡眠设置…", systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let error = power.lastError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)

                if needsHelperApproval {
                    Button("打开系统设置") { power.openHelperApprovalSettings() }
                }
            }

            if keyboard.isLocked {
                Label("键盘将在 \(keyboard.secondsRemaining) 秒后自动恢复", systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if let error = keyboard.lastError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)

                if keyboard.needsAccessibilityPermission {
                    Button("打开辅助功能设置") { keyboard.openAccessibilitySettings() }
                }
            }
        }
        .padding(16)
        .frame(width: 320)
    }

    /// Keep each row full-width. Toggle's intrinsic label layout otherwise
    /// moves the icon and switch depending on the length of Chinese text.
    private func settingRow(
        _ title: String,
        subtitle: String,
        symbol: String,
        isOn: Binding<Bool>,
        isDisabled: Bool = false
    ) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 16))
                .frame(width: 26)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Toggle(title, isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .disabled(isDisabled)
                .accessibilityLabel(title)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var quitButton: some View {
        Button {
            Task {
                keyboard.unlock()
                await power.disable()
                if !power.isActive {
                    NSApplication.shared.terminate(nil)
                }
            }
        } label: {
            Image(systemName: "power")
                .font(.system(size: 16, weight: .regular))
                .frame(width: 28, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .keyboardShortcut("q")
        .accessibilityLabel("退出小工具")
        .help("退出小工具")
    }

    private var needsHelperApproval: Bool {
        guard let error = power.lastError else { return false }
        return error == "Approve Macchiato Helper in System Settings, then try again."
            || error.contains("Approve the helper")
    }
}
