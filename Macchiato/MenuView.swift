import AppKit
import SwiftUI

@MainActor
struct MenuView: View {
    @Environment(PowerManager.self) private var power
    @Environment(KeyboardLockManager.self) private var keyboard

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            VStack(spacing: 10) {
                featureCard(
                    title: "Keep Awake",
                    subtitle: power.isActive ? "Sleep is blocked" : "Prevent Mac sleep",
                    symbol: power.isActive ? "moon.zzz.fill" : "moon.zzz",
                    isOn: power.isActive,
                    isBusy: power.isChanging
                ) {
                    guard !power.isChanging else { return }
                    Task { await power.setActive(!power.isActive) }
                }

                featureCard(
                    title: "Keyboard Cleaning",
                    subtitle: keyboard.isLocked ? "Keyboard temporarily locked" : "Block typing while cleaning",
                    symbol: "keyboard",
                    isOn: keyboard.isLocked,
                    isBusy: false
                ) {
                    if keyboard.isLocked {
                        keyboard.unlock()
                    } else {
                        keyboard.lock()
                    }
                }
            }

            if power.isChanging || power.lastError != nil {
                powerStatus
            }

            if keyboard.isLocked || keyboard.lastError != nil {
                keyboardStatus
            }

            Divider()

            footer
        }
        .padding(16)
        .frame(width: 340)
        // MenuBarExtra already provides the native background.
        // An additional material layer washes out colors in dark mode.
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image("MacchiatoBase")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 34, height: 34)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text("Macchiato")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color(nsColor: .labelColor))

                Text(power.isActive ? "Keeping this Mac awake" : "Normal sleep behavior")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(nsColor: .secondaryLabelColor))
            }

            Spacer(minLength: 0)
        }
    }

    private func featureCard(
        title: String,
        subtitle: String,
        symbol: String,
        isOn: Bool,
        isBusy: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .symbolRenderingMode(.monochrome)
                    .font(.system(size: 22, weight: .medium))
                    // Use explicit semantic text colors rather than a
                    // translucent secondary style in a vibrant menu window.
                    .foregroundStyle(Color(nsColor: .labelColor))
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.primary.opacity(0.07))
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color(nsColor: .labelColor))
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)

                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                TogglePill(isOn: isOn, isBusy: isBusy)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("\(title), \(isOn ? "on" : "off")"))
    }

    private var powerStatus: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: power.lastError == nil ? "clock.arrow.circlepath" : "exclamationmark.triangle.fill")
                .font(.system(size: 13, weight: .medium))

            Text(power.lastError ?? "Applying sleep setting…")
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            if needsHelperApproval {
                Button("Open Settings") {
                    power.openHelperApprovalSettings()
                }
                .buttonStyle(.borderless)
            }
        }
        .font(.system(size: 12))
        .foregroundStyle(power.lastError == nil ? Color(nsColor: .secondaryLabelColor) : Color.red)
    }

    @ViewBuilder
    private var keyboardStatus: some View {
        if keyboard.isLocked {
            HStack(spacing: 8) {
                Image(systemName: "clock")
                Text("Click to unlock or wait \(keyboard.secondsRemaining)s.")
                Spacer(minLength: 0)
            }
            .font(.system(size: 12))
            .foregroundStyle(Color(nsColor: .secondaryLabelColor))
        } else if let lastError = keyboard.lastError {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                Text(lastError)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)

                if keyboard.needsAccessibilityPermission {
                    Button("Open Settings") {
                        keyboard.openAccessibilitySettings()
                    }
                    .buttonStyle(.borderless)
                }
            }
            .font(.system(size: 12))
            .foregroundStyle(Color.red)
        }
    }

    private var needsHelperApproval: Bool {
        guard let lastError = power.lastError else { return false }
        return lastError == "Approve Macchiato Helper in System Settings, then try again."
            || lastError.contains("Approve the helper")
    }

    private var footer: some View {
        HStack {
            Text("Mac utility")
                .font(.system(size: 11))
                .foregroundStyle(Color(nsColor: .secondaryLabelColor))

            Spacer()

            Button {
                Task {
                    keyboard.unlock()
                    await power.disable()
                    if !power.isActive {
                        NSApplication.shared.terminate(nil)
                    }
                }
            } label: {
                Label("Quit", systemImage: "power")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(nsColor: .labelColor))
            }
            .buttonStyle(.plain)
            .keyboardShortcut("q")
        }
    }
}

private struct TogglePill: View {
    let isOn: Bool
    let isBusy: Bool

    var body: some View {
        ZStack(alignment: isOn ? .trailing : .leading) {
            Capsule()
                .fill(isOn ? Color.accentColor : Color.primary.opacity(0.18))
                .overlay(
                    Capsule()
                        .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                )

            Circle()
                .fill(Color.white)
                .frame(width: 24, height: 24)
                .padding(3)
                .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                .overlay {
                    if isBusy {
                        ProgressView()
                            .controlSize(.mini)
                    }
                }
        }
        .frame(width: 50, height: 30)
        .animation(.spring(response: 0.26, dampingFraction: 0.82), value: isOn)
        .accessibilityHidden(true)
    }
}
