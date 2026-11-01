import SwiftUI

@main
@MainActor
struct MacchiatoApp: App {
    @State private var power = PowerManager.shared
    @State private var keyboard = KeyboardLockManager.shared

    var body: some Scene {
        MenuBarExtra {
            MenuView()
                .environment(power)
                .environment(keyboard)
        } label: {
            Image(systemName: power.isActive ? "cup.and.saucer.fill" : "cup.and.saucer")
                .accessibilityLabel("小工具")
        }
        // The native menu-bar window supports real switches.
        // Menu style would display checkmarks instead.
        .menuBarExtraStyle(.window)

        Settings {
            HelperSettingsView()
                .environment(power)
        }
    }
}
