import AppKit
@preconcurrency import ApplicationServices
import AVFoundation
import Observation

/// Microphone and Accessibility permission state.
@MainActor
@Observable
public final class Permissions {
    public enum Status {
        case granted, denied, notDetermined
    }

    public enum Pane: String {
        case microphone = "Privacy_Microphone"
        case accessibility = "Privacy_Accessibility"
    }

    public private(set) var microphone: Status = .notDetermined
    public private(set) var accessibilityGranted = false

    public init() {
        refresh()
    }

    public func refresh() {
        microphone = switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: .granted
        case .notDetermined: .notDetermined
        default: .denied
        }
        accessibilityGranted = AXIsProcessTrusted()
    }

    /// Shows the system prompt the first time; afterwards returns the stored decision.
    public func requestMicrophone() async -> Bool {
        let granted = await AVCaptureDevice.requestAccess(for: .audio)
        refresh()
        return granted
    }

    /// Shows the system dialog that leads to Privacy & Security → Accessibility.
    public func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        accessibilityGranted = AXIsProcessTrustedWithOptions(options)
    }

    public static func openSystemSettings(_ pane: Pane) {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane.rawValue)")!
        NSWorkspace.shared.open(url)
    }
}
