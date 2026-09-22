import Foundation
import ServiceManagement
import UserNotifications

// Read-only system queries. This separate probe identity is not the Watt app.
@main
struct StatusProbe {
    static func timestamp() -> String {
        ISO8601DateFormatter().string(from: Date())
    }

    static func authorizationName(_ status: UNAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return "notDetermined"
        case .denied: return "denied"
        case .authorized: return "authorized"
        case .provisional: return "provisional"
        @unknown default: return "unknown"
        }
    }

    static func loginName(_ status: SMAppService.Status) -> String {
        switch status {
        case .notRegistered: return "notRegistered"
        case .enabled: return "enabled"
        case .requiresApproval: return "requiresApproval"
        case .notFound: return "notFound"
        @unknown default: return "unknown"
        }
    }

    @MainActor
    static func main() async throws {
        let started = timestamp()
        // Bound an unresponsive OS query without requesting any system change.
        DispatchQueue.global().asyncAfter(deadline: .now() + 30) {
            FileHandle.standardError.write(Data("notification settings query timed out after 30 seconds\n".utf8))
            exit(2)
        }
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        let notificationRead = timestamp()
        let loginStatus = SMAppService.mainApp.status
        let result: [String: Any] = [
            "run": CommandLine.arguments.dropFirst().first ?? "unspecified",
            "processID": ProcessInfo.processInfo.processIdentifier,
            "processStartedAtUTC": started,
            "notificationReadAtUTC": notificationRead,
            "loginReadAtUTC": timestamp(),
            "osVersion": ProcessInfo.processInfo.operatingSystemVersionString,
            "systemUptimeSeconds": ProcessInfo.processInfo.systemUptime,
            "bundleIdentifier": Bundle.main.bundleIdentifier ?? "missing",
            "bundlePath": Bundle.main.bundlePath,
            "notificationAuthorization": authorizationName(settings.authorizationStatus),
            "notificationAuthorizationRawValue": settings.authorizationStatus.rawValue,
            "mainAppStatus": loginName(loginStatus),
            "mainAppStatusRawValue": loginStatus.rawValue,
            "scope": "probe identity only; no delivery, registration, or approval mutation proof"
        ]
        let data = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
        FileHandle.standardOutput.write(data)
        print()
    }
}
