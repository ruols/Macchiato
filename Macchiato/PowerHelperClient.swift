import Foundation
import ServiceManagement

enum PowerHelperRegistrationStatus: Equatable {
    case enabled
    case requiresApproval
    case notInstalled
    case unavailable

    var title: String {
        switch self {
        case .enabled: return "已安装并启用"
        case .requiresApproval: return "等待系统批准"
        case .notInstalled: return "未安装"
        case .unavailable: return "不可用"
        }
    }
}

enum PowerHelperManagementError: LocalizedError {
    case busy
    case sleepStillBlocked
    case cannotVerifySleepState
    case unsupportedState

    var errorDescription: String? {
        switch self {
        case .busy: return "正在修改睡眠状态，请完成后再试。"
        case .sleepStillBlocked: return "尚未成功恢复正常睡眠，已取消卸载，避免留下异常电源设置。"
        case .cannotVerifySleepState: return "无法确认系统是否仍禁止睡眠，已取消卸载。请先检查 pmset 设置。"
        case .unsupportedState: return "Helper 状态不可用。"
        }
    }
}

final class PowerHelperClient {
    static let shared = PowerHelperClient()

    private static let requestTimeoutNanoseconds: UInt64 = 8_000_000_000

    private let service = SMAppService.daemon(plistName: PowerHelperConstants.launchDaemonPlistName)
    private let connectionLock = NSLock()
    private var connection: NSXPCConnection?

    private init() {}

    var registrationStatus: PowerHelperRegistrationStatus {
        switch service.status {
        case .enabled: return .enabled
        case .requiresApproval: return .requiresApproval
        case .notRegistered, .notFound: return .notInstalled
        @unknown default: return .unavailable
        }
    }

    /// Register only when the user explicitly chooses Install in Settings.
    func installHelper() throws {
        try registerHelperIfNeeded()
    }

    /// Reset sleep settings before removing the system daemon registration.
    /// Never auto-register the helper as a side effect of uninstalling.
    func uninstallHelper() async throws {
        switch service.status {
        case .enabled:
            try await setSleepDisabled(false)
            guard try await !isSleepDisabled() else {
                throw PowerHelperManagementError.sleepStillBlocked
            }

        case .requiresApproval:
            // Service is not runnable. Verify the global setting through
            // read-only pmset output rather than silently leaving sleep disabled.
            guard try normalSleepIsAllowed() else {
                throw PowerHelperManagementError.sleepStillBlocked
            }

        case .notRegistered, .notFound:
            resetCurrentConnection()
            return

        @unknown default:
            throw PowerHelperManagementError.unsupportedState
        }

        resetCurrentConnection()
        try service.unregister()
    }

    private func normalSleepIsAllowed() throws -> Bool {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = ["-g", "live"]
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0,
                  let output = String(data: outputData, encoding: .utf8) else {
                throw PowerHelperManagementError.cannotVerifySleepState
            }
            return output.range(of: #"SleepDisabled\s+1"#, options: .regularExpression) == nil
        } catch {
            throw PowerHelperManagementError.cannotVerifySleepState
        }
    }

    func setSleepDisabled(_ disabled: Bool) async throws {
        try await performWithHelperConnection { connection in
            try await sendSleepDisabled(disabled, connection: connection)
        }
    }

    func isSleepDisabled() async throws -> Bool {
        try await performWithHelperConnection { connection in
            try await requestSleepDisabled(connection: connection)
        }
    }

    func openHelperApprovalSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    private func sendSleepDisabled(_ disabled: Bool, connection: NSXPCConnection) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let once = ContinuationGate(continuation)
            let timeout = scheduleTimeout(for: once, connection: connection)

            guard let proxy = connection.remoteObjectProxyWithErrorHandler({ [weak self, weak connection] error in
                timeout.cancel()
                if let connection {
                    self?.resetConnection(connection)
                }
                once.resume(throwing: error)
            }) as? PowerHelperProtocol else {
                timeout.cancel()
                once.resume(throwing: PowerHelperClientError.unavailable)
                return
            }

            proxy.setSleepDisabled(disabled) { success, message in
                timeout.cancel()
                if success {
                    once.resume()
                } else {
                    once.resume(throwing: PowerHelperClientError.commandFailed(message))
                }
            }
        }
    }

    private func requestSleepDisabled(connection: NSXPCConnection) async throws -> Bool {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Bool, Error>) in
            let once = ContinuationGate(continuation)
            let timeout = scheduleTimeout(for: once, connection: connection)

            guard let proxy = connection.remoteObjectProxyWithErrorHandler({ [weak self, weak connection] error in
                timeout.cancel()
                if let connection {
                    self?.resetConnection(connection)
                }
                once.resume(throwing: error)
            }) as? PowerHelperProtocol else {
                timeout.cancel()
                once.resume(throwing: PowerHelperClientError.unavailable)
                return
            }

            proxy.getSleepDisabled { disabled, message in
                timeout.cancel()
                if let message {
                    once.resume(throwing: PowerHelperClientError.commandFailed(message))
                } else {
                    once.resume(returning: disabled)
                }
            }
        }
    }

    private func performWithHelperConnection<Value>(
        _ operation: (NSXPCConnection) async throws -> Value
    ) async throws -> Value {
        // Explicit management: do not silently reinstall an uninstalled helper.
        guard service.status == .enabled else {
            throw PowerHelperClientError.requiresApprovalOrInstallation
        }
        return try await operation(makeConnectionIfNeeded())
    }

    private func registerHelperIfNeeded() throws {
        switch service.status {
        case .enabled:
            return
        case .notRegistered, .notFound:
            do {
                try service.register()
            } catch {
                if service.status == .requiresApproval {
                    throw PowerHelperClientError.requiresApproval
                }
                throw error
            }
            guard service.status == .enabled else {
                throw PowerHelperClientError.requiresApproval
            }
        case .requiresApproval:
            throw PowerHelperClientError.requiresApproval
        @unknown default:
            throw PowerHelperClientError.unavailable
        }
    }

    private func makeConnectionIfNeeded() -> NSXPCConnection {
        connectionLock.lock()
        defer { connectionLock.unlock() }

        if let connection {
            return connection
        }

        let newConnection = makeConnection()
        connection = newConnection
        return newConnection
    }

    private func makeConnection() -> NSXPCConnection {
        let connection = NSXPCConnection(
            machServiceName: PowerHelperConstants.machServiceName,
            options: .privileged
        )
        connection.remoteObjectInterface = NSXPCInterface(with: PowerHelperProtocol.self)
#if !DEBUG
        connection.setCodeSigningRequirement(PowerHelperConstants.helperCodeSigningRequirement)
#endif
        connection.invalidationHandler = { [weak self, weak connection] in
            if let connection {
                self?.clearConnection(connection)
            }
        }
        connection.resume()
        return connection
    }

    private func scheduleTimeout<Value>(
        for gate: ContinuationGate<Value>,
        connection: NSXPCConnection
    ) -> Task<Void, Never> {
        Task { [weak self, weak connection] in
            do {
                try await Task.sleep(nanoseconds: Self.requestTimeoutNanoseconds)
            } catch {
                return
            }

            guard !Task.isCancelled else { return }

            if let connection {
                self?.resetConnection(connection)
            }
            gate.resume(throwing: PowerHelperClientError.timedOut)
        }
    }

    private func resetConnection(_ connectionToInvalidate: NSXPCConnection) {
        clearConnection(connectionToInvalidate)
        connectionToInvalidate.invalidate()
    }

    private func resetCurrentConnection() {
        connectionLock.lock()
        let currentConnection = connection
        connection = nil
        connectionLock.unlock()

        currentConnection?.invalidate()
    }

    private func clearConnection(_ connectionToClear: NSXPCConnection) {
        connectionLock.lock()
        defer { connectionLock.unlock() }

        if connection === connectionToClear {
            connection = nil
        }
    }
}

private final class ContinuationGate<Value> {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Value, Error>?

    init(_ continuation: CheckedContinuation<Value, Error>) {
        self.continuation = continuation
    }

    func resume(returning value: Value) {
        take()?.resume(returning: value)
    }

    func resume(throwing error: Error) {
        take()?.resume(throwing: error)
    }

    func resume() where Value == Void {
        take()?.resume()
    }

    private func take() -> CheckedContinuation<Value, Error>? {
        lock.lock()
        defer { lock.unlock() }

        let current = continuation
        continuation = nil
        return current
    }
}

private enum PowerHelperClientError: LocalizedError {
    case commandFailed(String?)
    case notFound
    case requiresApproval
    case requiresApprovalOrInstallation
    case timedOut
    case unavailable

    var errorDescription: String? {
        switch self {
        case .commandFailed(let message):
            if let message, !message.isEmpty {
                return message
            }
            return "Could not update lid-closed sleep setting."
        case .notFound:
            return "小工具 Power Helper is missing from the app bundle."
        case .requiresApproval:
            return "请在系统设置中批准小工具 Power Helper，然后重试。"
        case .requiresApprovalOrInstallation:
            return "请先到小工具设置中安装并批准 Power Helper。"
        case .timedOut:
            return "小工具 Power Helper did not respond. Approve the helper in System Settings or relaunch Macchiato, then try again."
        case .unavailable:
            return "小工具 Power Helper is unavailable."
        }
    }
}
