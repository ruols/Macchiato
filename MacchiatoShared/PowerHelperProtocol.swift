import Foundation
import Security
import CryptoKit

enum PowerHelperConstants {
    static let appBundleIdentifier = "app.macchiato.Macchiato"
    static let helperBundleIdentifier = "app.macchiato.Macchiato.PowerHelper"
    static let machServiceName = "app.macchiato.Macchiato.PowerHelper"
    static let launchDaemonPlistName = "\(machServiceName).plist"

    static var appCodeSigningRequirement: String {
        codeSigningRequirement(for: appBundleIdentifier)
    }

    static var helperCodeSigningRequirement: String {
        codeSigningRequirement(for: helperBundleIdentifier)
    }

    private static func codeSigningRequirement(for bundleIdentifier: String) -> String {
        var requirement = #"identifier "\#(bundleIdentifier)""#

        if let teamIdentifier = currentTeamIdentifier() {
            requirement += #" and anchor apple generic and certificate leaf[subject.OU] = "\#(teamIdentifier)""#
        } else if let leafHash = currentLeafCertificateSHA1() {
            // Free/local signing may have no TeamIdentifier. Never fall back to
            // identifier-only checks for a privileged XPC endpoint.
            requirement += #" and certificate leaf = H"\#(leafHash)""#
        } else {
            // Ad-hoc signing has no certificate to bind. Fail closed in Release.
            requirement += " and anchor apple generic"
        }

        return requirement
    }

    private static func currentLeafCertificateSHA1() -> String? {
        var code: SecCode?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code else { return nil }
        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess,
              let staticCode else { return nil }

        var signingInformation: CFDictionary?
        let flags = SecCSFlags(rawValue: kSecCSSigningInformation)
        guard SecCodeCopySigningInformation(staticCode, flags, &signingInformation) == errSecSuccess,
              let information = signingInformation as? [String: Any],
              let certificates = information[kSecCodeInfoCertificates as String] as? [SecCertificate],
              let leaf = certificates.first else {
            return nil
        }

        let certificateData = SecCertificateCopyData(leaf) as Data
        return Insecure.SHA1.hash(data: certificateData)
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private static func currentTeamIdentifier() -> String? {
        var code: SecCode?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code else {
            return nil
        }

        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode else {
            return nil
        }

        var signingInformation: CFDictionary?
        let flags = SecCSFlags(rawValue: kSecCSSigningInformation)
        guard SecCodeCopySigningInformation(staticCode, flags, &signingInformation) == errSecSuccess,
              let information = signingInformation as? [String: Any],
              let teamIdentifier = information[kSecCodeInfoTeamIdentifier as String] as? String,
              !teamIdentifier.isEmpty else {
            return nil
        }

        return teamIdentifier
    }
}

@objc(PowerHelperProtocol)
protocol PowerHelperProtocol {
    func setSleepDisabled(_ disabled: Bool, withReply reply: @escaping (Bool, String?) -> Void)
    func getSleepDisabled(withReply reply: @escaping (Bool, String?) -> Void)
}
