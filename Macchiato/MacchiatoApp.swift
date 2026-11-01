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
        }
        .menuBarExtraStyle(.window)
    }
}
