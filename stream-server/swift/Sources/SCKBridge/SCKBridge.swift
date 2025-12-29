// SCKBridge - Swift bridge for ScreenCaptureKit
// Exposes C-compatible functions for Rust FFI

import Foundation
import ScreenCaptureKit
import CoreGraphics
import CoreMedia
import AppKit
import VideoToolbox

// MARK: - FFI Types (must match Rust definitions)

/// Encoded frame structure matching Rust's EncodedFrame
@frozen
public struct EncodedFrameFFI {
    public let windowId: UInt32
    public let timestampMs: UInt64
    public let isKeyframe: Bool
    public let data: UnsafePointer<UInt8>
    public let dataLen: Int
    public let width: UInt32
    public let height: UInt32
}

/// Import the Rust callback function
@_silgen_name("rust_on_encoded_frame")
func rustOnEncodedFrame(_ frame: UnsafePointer<EncodedFrameFFI>)

// MARK: - App Initialization

/// Initialize the app context for Window Server access
/// This MUST be called before any ScreenCaptureKit or CoreGraphics window operations
/// Returns: 0 on success
@_cdecl("sck_initialize")
public func sck_initialize() -> Int32 {
    // Ensure we're connected to the Window Server
    // This is required for CLI apps to use ScreenCaptureKit
    _ = NSApplication.shared
    NSApp.setActivationPolicy(.accessory)
    
    // Run the run loop briefly to process initialization
    RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
    
    return 0
}

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

/// Stream delegate to handle errors
@available(macOS 12.3, *)
private class StreamDelegate: NSObject, SCStreamDelegate {
    let windowId: UInt32
    
    init(windowId: UInt32) {
        self.windowId = windowId
        super.init()
    }
    
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        print("SCStream stopped with error for window \(windowId): \(error)")
    }
}

/// Capture session wrapper
@available(macOS 12.3, *)
private class CaptureSession {
    let windowId: UInt32
    var stream: SCStream?
    var outputHandler: FrameOutputHandler?
    var streamDelegate: StreamDelegate?
    var encoder: H264Encoder?
    let width: Int
    let height: Int
    
    init(windowId: UInt32, width: Int, height: Int) {
        self.windowId = windowId
        self.width = width
        self.height = height
    }
    
    func startEncoder() {
        let enc = H264Encoder(windowId: windowId, width: width, height: height)
        
        let success = enc.start { [weak self] windowId, timestampMs, isKeyframe, nalData, width, height in
            guard let _ = self else { return }
            
            // Call Rust with the encoded frame
            nalData.withUnsafeBytes { buffer in
                guard let ptr = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
                
                var frame = EncodedFrameFFI(
                    windowId: windowId,
                    timestampMs: timestampMs,
                    isKeyframe: isKeyframe,
                    data: ptr,
                    dataLen: nalData.count,
                    width: UInt32(width),
                    height: UInt32(height)
                )
                
                withUnsafePointer(to: &frame) { framePtr in
                    rustOnEncodedFrame(framePtr)
                }
            }
        }
        
        if success {
            self.encoder = enc
        }
    }
    
    func stopEncoder() {
        encoder?.stop()
        encoder = nil
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
    
    let contentSemaphore = DispatchSemaphore(value: 0)
    let captureSemaphore = DispatchSemaphore(value: 0)
    var success = false
    
    SCShareableContent.getExcludingDesktopWindows(true, onScreenWindowsOnly: true) { content, error in
        guard let content = content, error == nil else {
            contentSemaphore.signal()
            return
        }
        
        // Find the window
        guard let window = content.windows.first(where: { $0.windowID == windowId }) else {
            print("Window \(windowId) not found in available windows")
            contentSemaphore.signal()
            return
        }
        
        let frameWidth = Int(window.frame.width)
        let frameHeight = Int(window.frame.height)
        
        // Create content filter for single window
        let filter = SCContentFilter(desktopIndependentWindow: window)
        
        // Configure stream
        let config = SCStreamConfiguration()
        config.width = frameWidth
        config.height = frameHeight
        config.minimumFrameInterval = CMTime(value: 1, timescale: 30) // 30 FPS for encoding
        config.queueDepth = 5
        config.showsCursor = true
        config.pixelFormat = kCVPixelFormatType_32BGRA
        
        // Capture options for better frame delivery
        if #available(macOS 13.0, *) {
            config.capturesAudio = false
        }
        
        // Scale to fit the configured dimensions
        config.scalesToFit = true
        
        // Create capture session with dimensions
        let session = CaptureSession(windowId: windowId, width: frameWidth, height: frameHeight)
        
        // Start the H264 encoder
        session.startEncoder()
        
        // Create stream delegate
        let streamDelegate = StreamDelegate(windowId: windowId)
        session.streamDelegate = streamDelegate
        
        // Create stream with delegate
        let stream = SCStream(filter: filter, configuration: config, delegate: streamDelegate)
        
        do {
            // Add stream output - pass session reference for encoder access
            let output = FrameOutputHandler(windowId: windowId, session: session)
            try stream.addStreamOutput(output, type: .screen, sampleHandlerQueue: .global(qos: .userInteractive))
            
            session.outputHandler = output
            session.stream = stream
            
            // Store session before starting (so bounds are available)
            manager.setSession(windowId, session: session)
            
            // Start capture and wait for completion
            stream.startCapture { captureError in
                if let captureError = captureError {
                    print("Failed to start capture: \(captureError)")
                    session.stopEncoder()
                    manager.setSession(windowId, session: nil)
                } else {
                    success = true
                    print("Capture started successfully for window \(windowId) at \(frameWidth)x\(frameHeight)")
                }
                captureSemaphore.signal()
            }
            
            contentSemaphore.signal()
            
        } catch {
            print("Failed to setup stream: \(error)")
            session.stopEncoder()
            contentSemaphore.signal()
        }
    }
    
    // Wait for content enumeration
    _ = contentSemaphore.wait(timeout: .now() + 5.0)
    
    // Wait for capture to start
    _ = captureSemaphore.wait(timeout: .now() + 5.0)
    
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
    
    // Stop encoder first
    session.stopEncoder()
    
    session.stream?.stopCapture { error in
        if let error = error {
            print("Error stopping capture: \(error)")
        }
    }
    
    return 0
}

/// Request a keyframe for a window's encoder
@_cdecl("sck_request_keyframe")
public func sck_request_keyframe(windowId: UInt32) -> Int32 {
    guard #available(macOS 12.3, *) else {
        return -1
    }
    
    let manager = CaptureManager.shared
    guard let session = manager.getSession(windowId) else {
        print("sck_request_keyframe: No session for window \(windowId)")
        return -1
    }
    
    session.encoder?.requestKeyframe()
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
    private weak var session: CaptureSession?
    private var frameCount: UInt64 = 0
    private var validFrameCount: UInt64 = 0
    private var lastLogTime: Date = Date()
    
    init(windowId: UInt32, session: CaptureSession) {
        self.windowId = windowId
        self.session = session
        super.init()
    }
    
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen else { return }
        
        frameCount += 1
        
        // Check if sample buffer is valid and has data
        guard CMSampleBufferIsValid(sampleBuffer),
              CMSampleBufferDataIsReady(sampleBuffer) else {
            return // Silent skip for invalid buffers
        }
        
        // Get pixel buffer - may be nil for some frames (e.g., no content change)
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            // Only log occasionally to avoid spam
            if frameCount <= 5 || frameCount % 100 == 0 {
                // Check attachments for clues about why there's no pixel buffer
                if let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[CFString: Any]] {
                    let hasStatusFrame = attachments.first?[SCStreamFrameInfo.status as CFString] != nil
                    if hasStatusFrame {
                        // This is a status-only frame, not an error
                        return
                    }
                }
                print("FrameOutputHandler: No pixel buffer in frame #\(frameCount)")
            }
            return
        }
        
        validFrameCount += 1
        
        // Log every 30 valid frames or every 2 seconds
        let now = Date()
        if validFrameCount % 30 == 1 || now.timeIntervalSince(lastLogTime) >= 2.0 {
            print("FrameOutputHandler: Captured valid frame #\(validFrameCount) (total: \(frameCount)) for window \(windowId)")
            lastLogTime = now
        }
        
        // Get timestamp
        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        
        // Encode the frame
        if let encoder = session?.encoder {
            encoder.encode(pixelBuffer: pixelBuffer, timestamp: pts)
        } else {
            if validFrameCount == 1 {
                print("FrameOutputHandler: No encoder for window \(windowId)")
            }
        }
    }
}
