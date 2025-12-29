// SCKBridge - Swift bridge for ScreenCaptureKit
// Exposes C-compatible functions for Rust FFI

import Foundation
import ScreenCaptureKit
import CoreGraphics
import CoreMedia

// MARK: - Capture Session Manager

/// Thread-safe manager for capture sessions
private final class CaptureManager {
    static let shared = CaptureManager()
    
    private let lock = NSLock()
    private var sessions: [UInt32: Any] = [:]
    
    private init() {}
    
    @available(macOS 12.3, *)
    func getSession(_ windowId: UInt32) -> CaptureSession? {
        lock.lock()
        defer { lock.unlock() }
        return sessions[windowId] as? CaptureSession
    }
    
    @available(macOS 12.3, *)
    func setSession(_ windowId: UInt32, session: CaptureSession?) {
        lock.lock()
        defer { lock.unlock() }
        if let session = session {
            sessions[windowId] = session
        } else {
            sessions.removeValue(forKey: windowId)
        }
    }
    
    @available(macOS 12.3, *)
    func removeSession(_ windowId: UInt32) -> CaptureSession? {
        lock.lock()
        defer { lock.unlock() }
        return sessions.removeValue(forKey: windowId) as? CaptureSession
    }
}

/// Capture session wrapper
@available(macOS 12.3, *)
private class CaptureSession {
    let windowId: UInt32
    var stream: SCStream?
    var outputHandler: FrameOutputHandler?
    
    init(windowId: UInt32) {
        self.windowId = windowId
    }
}

// MARK: - Window Enumeration

/// Get count of available windows
/// Returns: JSON string with window list, caller must free with sck_free_string
@_cdecl("sck_get_windows_json")
public func sck_get_windows_json() -> UnsafeMutablePointer<CChar>? {
    var windowsJson = "[]"
    
    let semaphore = DispatchSemaphore(value: 0)
    
    if #available(macOS 12.3, *) {
        SCShareableContent.getExcludingDesktopWindows(true, onScreenWindowsOnly: true) { content, error in
            defer { semaphore.signal() }
            
            guard let content = content, error == nil else {
                return
            }
            
            let windows = content.windows.filter { window in
                // Filter out system windows and windows without titles
                guard let title = window.title, !title.isEmpty else { return false }
                guard let app = window.owningApplication else { return false }
                
                // Skip certain system apps
                let bundleId = app.bundleIdentifier
                if bundleId.contains("com.apple.dock") ||
                   bundleId.contains("com.apple.controlcenter") ||
                   bundleId.contains("com.apple.notificationcenterui") {
                    return false
                }
                
                return window.frame.width > 100 && window.frame.height > 100
            }
            
            // Convert to JSON
            var jsonArray: [[String: Any]] = []
            for window in windows {
                let dict: [String: Any] = [
                    "id": window.windowID,
                    "title": window.title ?? "",
                    "app": window.owningApplication?.applicationName ?? "",
                    "bounds": [
                        "x": window.frame.origin.x,
                        "y": window.frame.origin.y,
                        "width": window.frame.width,
                        "height": window.frame.height
                    ]
                ]
                jsonArray.append(dict)
            }
            
            if let jsonData = try? JSONSerialization.data(withJSONObject: jsonArray),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                windowsJson = jsonString
            }
        }
        
        // Wait for async operation (with timeout)
        _ = semaphore.wait(timeout: .now() + 5.0)
    }
    
    return strdup(windowsJson)
}

/// Free a string returned by sck functions
@_cdecl("sck_free_string")
public func sck_free_string(_ ptr: UnsafeMutablePointer<CChar>?) {
    if let ptr = ptr {
        free(ptr)
    }
}

/// Get window count
@_cdecl("sck_get_window_count")
public func sck_get_window_count() -> Int32 {
    var count: Int32 = 0
    let semaphore = DispatchSemaphore(value: 0)
    
    if #available(macOS 12.3, *) {
        SCShareableContent.getExcludingDesktopWindows(true, onScreenWindowsOnly: true) { content, error in
            defer { semaphore.signal() }
            
            guard let content = content, error == nil else {
                return
            }
            
            count = Int32(content.windows.filter { window in
                guard let title = window.title, !title.isEmpty else { return false }
                guard window.owningApplication != nil else { return false }
                return window.frame.width > 100 && window.frame.height > 100
            }.count)
        }
        
        _ = semaphore.wait(timeout: .now() + 5.0)
    }
    
    return count
}

// MARK: - Screen Capture

/// Start capturing a specific window
/// Returns: 0 on success, -1 on failure
@_cdecl("sck_start_capture")
public func sck_start_capture(windowId: UInt32) -> Int32 {
    guard #available(macOS 12.3, *) else {
        return -1
    }
    
    return startCaptureImpl(windowId: windowId)
}

@available(macOS 12.3, *)
private func startCaptureImpl(windowId: UInt32) -> Int32 {
    let manager = CaptureManager.shared
    
    // Check if already capturing
    if manager.getSession(windowId) != nil {
        return 0 // Already capturing
    }
    
    let semaphore = DispatchSemaphore(value: 0)
    var success = false
    
    SCShareableContent.getExcludingDesktopWindows(true, onScreenWindowsOnly: true) { content, error in
        defer { semaphore.signal() }
        
        guard let content = content, error == nil else {
            return
        }
        
        // Find the window
        guard let window = content.windows.first(where: { $0.windowID == windowId }) else {
            return
        }
        
        // Create content filter for single window
        let filter = SCContentFilter(desktopIndependentWindow: window)
        
        // Configure stream
        let config = SCStreamConfiguration()
        config.width = Int(window.frame.width)
        config.height = Int(window.frame.height)
        config.minimumFrameInterval = CMTime(value: 1, timescale: 60) // 60 FPS max
        config.queueDepth = 5
        config.showsCursor = true
        config.pixelFormat = kCVPixelFormatType_32BGRA
        
        // Create capture session
        let session = CaptureSession(windowId: windowId)
        
        // Create stream
        let stream = SCStream(filter: filter, configuration: config, delegate: nil)
        
        do {
            // Add stream output
            let output = FrameOutputHandler(windowId: windowId)
            try stream.addStreamOutput(output, type: .screen, sampleHandlerQueue: .global(qos: .userInteractive))
            
            session.outputHandler = output
            session.stream = stream
            
            // Start capture
            stream.startCapture { error in
                if let error = error {
                    print("Failed to start capture: \(error)")
                    return
                }
                success = true
            }
            
            manager.setSession(windowId, session: session)
            
        } catch {
            print("Failed to setup stream: \(error)")
        }
    }
    
    _ = semaphore.wait(timeout: .now() + 5.0)
    
    return success ? 0 : -1
}

/// Stop capturing a window
@_cdecl("sck_stop_capture")
public func sck_stop_capture(windowId: UInt32) -> Int32 {
    guard #available(macOS 12.3, *) else {
        return -1
    }
    
    return stopCaptureImpl(windowId: windowId)
}

@available(macOS 12.3, *)
private func stopCaptureImpl(windowId: UInt32) -> Int32 {
    let manager = CaptureManager.shared
    
    guard let session = manager.removeSession(windowId) else {
        return 0 // Not capturing
    }
    
    session.stream?.stopCapture { error in
        if let error = error {
            print("Error stopping capture: \(error)")
        }
    }
    
    return 0
}

/// Check if screen recording permission is granted
@_cdecl("sck_has_permission")
public func sck_has_permission() -> Int32 {
    if #available(macOS 12.3, *) {
        // Try to get shareable content - this will fail if no permission
        var hasPermission = false
        let semaphore = DispatchSemaphore(value: 0)
        
        SCShareableContent.getExcludingDesktopWindows(true, onScreenWindowsOnly: true) { content, error in
            hasPermission = content != nil && error == nil
            semaphore.signal()
        }
        
        _ = semaphore.wait(timeout: .now() + 2.0)
        return hasPermission ? 1 : 0
    }
    return 0
}

// MARK: - Frame Output Handler

@available(macOS 12.3, *)
private class FrameOutputHandler: NSObject, SCStreamOutput {
    let windowId: UInt32
    
    init(windowId: UInt32) {
        self.windowId = windowId
        super.init()
    }
    
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen else { return }
        
        // Get pixel buffer
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            return
        }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let dataSize = bytesPerRow * height
        
        // Get timestamp
        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let timestamp = UInt64(CMTimeGetSeconds(pts) * 1000) // Milliseconds
        
        // Frame data is available here for processing
        // In a full implementation, this would be sent to the WebRTC track
        _ = (windowId, width, height, dataSize, timestamp, baseAddress)
    }
}
