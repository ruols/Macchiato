import AppKit
import ApplicationServices
import CoreGraphics
import Foundation
import Observation

/// Temporarily suppresses ordinary keyboard events during cleaning.
/// Pointer input stays available for unlocking from the menu bar.
@MainActor
@Observable
final class KeyboardLockManager {
    static let shared = KeyboardLockManager()
    static let lockDurationSeconds = 60

    private(set) var isLocked = false
    private(set) var secondsRemaining = lockDurationSeconds
    private(set) var lastError: String?
    private(set) var needsAccessibilityPermission = false

    @ObservationIgnored private var eventTap: CFMachPort?
    @ObservationIgnored private var eventTapSource: CFRunLoopSource?
    @ObservationIgnored private var countdownTask: Task<Void, Never>?

    private init() {}

    func lock() {
        guard !isLocked else { return }
        lastError = nil
        needsAccessibilityPermission = false

        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        guard AXIsProcessTrustedWithOptions(options) else {
            lastError = "Allow Macchiato in Privacy & Security > Accessibility, then try again."
            needsAccessibilityPermission = true
            return
        }

        let types: [CGEventType] = [.keyDown, .keyUp, .flagsChanged, .systemDefined]
        let mask = types.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1.rawValue) }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: keyboardCleaningEventTap,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            lastError = "Unable to intercept the keyboard. Check Accessibility permission."
            return
        }

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            CFMachPortInvalidate(tap)
            lastError = "Unable to install the keyboard event tap."
            return
        }

        CFRunLoopAddSource(CFRunLoopGetMain(), source, kCFRunLoopCommonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        guard CGEvent.tapIsEnabled(tap: tap) else {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, kCFRunLoopCommonModes)
            CFMachPortInvalidate(tap)
            lastError = "The keyboard event tap was not enabled."
            return
        }

        eventTap = tap
        eventTapSource = source
        isLocked = true
        startAutoUnlockCountdown()
    }

    func unlock() {
        stopFiltering()
        lastError = nil
        needsAccessibilityPermission = false
    }

    func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }

    func interceptionDidStop() {
        guard isLocked else { return }
        stopFiltering()
        lastError = "Keyboard interception stopped. Normal typing is available again."
    }

    private func startAutoUnlockCountdown() {
        secondsRemaining = Self.lockDurationSeconds
        countdownTask?.cancel()
        countdownTask = Task { [weak self] in
            for _ in 0..<Self.lockDurationSeconds {
                do {
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                } catch {
                    return
                }
                guard let self, self.isLocked else { return }
                guard let tap = self.eventTap, CGEvent.tapIsEnabled(tap: tap) else {
                    self.interceptionDidStop()
                    return
                }
                self.secondsRemaining -= 1
                if self.secondsRemaining == 0 {
                    self.unlock()
                    return
                }
            }
        }
    }

    private func stopFiltering() {
        countdownTask?.cancel()
        countdownTask = nil
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = eventTapSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), source, kCFRunLoopCommonModes)
            }
            CFMachPortInvalidate(tap)
        }
        eventTapSource = nil
        eventTap = nil
        isLocked = false
        secondsRemaining = Self.lockDurationSeconds
    }
}

/// The system calls this synchronously from the main run loop.
/// It neither reads nor records any pressed key.
private func keyboardCleaningEventTap(
    _ proxy: CGEventTapProxy,
    _ type: CGEventType,
    _ event: CGEvent,
    _ userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let userInfo {
            let manager = Unmanaged<KeyboardLockManager>.fromOpaque(userInfo).takeUnretainedValue()
            Task { @MainActor in manager.interceptionDidStop() }
        }
        return Unmanaged.passUnretained(event)
    }

    switch type {
    case .keyDown, .keyUp, .flagsChanged, .systemDefined:
        return nil
    default:
        return Unmanaged.passUnretained(event)
    }
}
