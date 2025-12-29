// WindowEnumerator - Helper for window enumeration
// Provides additional window filtering and sorting utilities

import Foundation
import ScreenCaptureKit
import AppKit

/// Window enumeration utilities
@available(macOS 12.3, *)
public enum WindowEnumerator {
    
    /// Get all windows with detailed filtering options
    public static func getWindows(
        excludeDesktop: Bool = true,
        onScreenOnly: Bool = true,
        minWidth: CGFloat = 100,
        minHeight: CGFloat = 100,
        excludeBundleIds: [String] = []
    ) async throws -> [SCWindow] {
        let content = try await SCShareableContent.excludingDesktopWindows(
            excludeDesktop,
            onScreenWindowsOnly: onScreenOnly
        )
        
        return content.windows.filter { window in
            // Size filter
            guard window.frame.width >= minWidth && window.frame.height >= minHeight else {
                return false
            }
            
            // Title filter
            guard let title = window.title, !title.isEmpty else {
                return false
            }
            
            // Bundle ID filter
            let bundleId = window.owningApplication?.bundleIdentifier ?? ""
            if excludeBundleIds.contains(where: { bundleId.contains($0) }) {
                return false
            }
            
            return true
        }
    }
    
    /// Default bundle IDs to exclude (system windows)
    public static let defaultExcludedBundleIds = [
        "com.apple.dock",
        "com.apple.controlcenter",
        "com.apple.notificationcenterui",
        "com.apple.SystemUIServer",
        "com.apple.WindowManager"
    ]
    
    /// Find a specific window by ID
    public static func findWindow(id: CGWindowID) async throws -> SCWindow? {
        let content = try await SCShareableContent.excludingDesktopWindows(
            true,
            onScreenWindowsOnly: false
        )
        return content.windows.first { $0.windowID == id }
    }
    
    /// Get windows for a specific application
    public static func getWindowsForApp(bundleId: String) async throws -> [SCWindow] {
        let content = try await SCShareableContent.excludingDesktopWindows(
            true,
            onScreenWindowsOnly: true
        )
        
        return content.windows.filter { window in
            window.owningApplication?.bundleIdentifier == bundleId
        }
    }
}
