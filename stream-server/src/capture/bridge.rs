//! FFI bridge to Swift ScreenCaptureKit wrapper
//!
//! This module provides Rust bindings to the Swift SCKBridge library
//! which handles the actual ScreenCaptureKit operations.

use anyhow::{anyhow, Result};
use serde::Deserialize;
use std::ffi::{c_char, c_void, CStr};
use std::sync::atomic::{AtomicPtr, Ordering};
use tracing::{debug, trace};

use super::{WindowBounds, WindowInfo};

/// Encoded video frame from Swift
#[repr(C)]
#[derive(Debug)]
pub struct EncodedFrame {
    /// Window ID this frame belongs to
    pub window_id: u32,
    /// Presentation timestamp in milliseconds
    pub timestamp_ms: u64,
    /// Whether this is a keyframe (IDR)
    pub is_keyframe: bool,
    /// Pointer to NAL unit data (AVCC format with length prefixes)
    pub data: *const u8,
    /// Length of the data in bytes
    pub data_len: usize,
    /// Frame width
    pub width: u32,
    /// Frame height
    pub height: u32,
}

/// Callback function type for receiving encoded frames from Swift
/// The callback receives a pointer to EncodedFrame
pub type FrameCallbackFn = extern "C" fn(*const EncodedFrame);

/// Global frame callback - set by Rust, called by Swift
static FRAME_CALLBACK: AtomicPtr<c_void> = AtomicPtr::new(std::ptr::null_mut());

/// Set the global frame callback that Swift will call with encoded frames
pub fn set_frame_callback(callback: FrameCallbackFn) {
    FRAME_CALLBACK.store(callback as *mut c_void, Ordering::SeqCst);
    debug!("Frame callback registered");
}

/// Called by Swift when an encoded frame is ready
/// This is exported as a C function for Swift to call
#[no_mangle]
pub extern "C" fn rust_on_encoded_frame(frame: *const EncodedFrame) {
    if frame.is_null() {
        return;
    }

    let callback_ptr = FRAME_CALLBACK.load(Ordering::SeqCst);
    if callback_ptr.is_null() {
        trace!("Frame received but no callback registered");
        return;
    }

    // Call the registered callback
    let callback: FrameCallbackFn = unsafe { std::mem::transmute(callback_ptr) };
    callback(frame);
}

// External Swift bridge functions
// These are implemented in the Swift package and linked at build time
#[cfg(target_os = "macos")]
extern "C" {
    fn sck_initialize() -> i32;
    fn sck_get_windows_json() -> *mut c_char;
    fn sck_free_string(ptr: *mut c_char);
    fn sck_get_window_count() -> i32;
    fn sck_start_capture(window_id: u32) -> i32;
    fn sck_stop_capture(window_id: u32) -> i32;
    fn sck_has_permission() -> i32;
}

/// Initialize the app context for Window Server access
/// This MUST be called before any ScreenCaptureKit operations
#[cfg(target_os = "macos")]
pub fn initialize() -> Result<()> {
    unsafe {
        let result = sck_initialize();
        if result != 0 {
            return Err(anyhow!("Failed to initialize ScreenCaptureKit bridge"));
        }
    }
    debug!("ScreenCaptureKit bridge initialized");
    Ok(())
}

#[cfg(not(target_os = "macos"))]
pub fn initialize() -> Result<()> {
    Ok(())
}

/// JSON structure for deserializing window info from Swift
#[derive(Debug, Deserialize)]
struct JsonWindowInfo {
    id: u32,
    title: String,
    app: String,
    bounds: JsonBounds,
}

#[derive(Debug, Deserialize)]
struct JsonBounds {
    x: f64,
    y: f64,
    width: f64,
    height: f64,
}

/// Get list of available windows from ScreenCaptureKit
#[cfg(target_os = "macos")]
pub fn get_windows() -> Result<Vec<WindowInfo>> {
    unsafe {
        let json_ptr = sck_get_windows_json();

        if json_ptr.is_null() {
            return Ok(Vec::new());
        }

        let json_str = CStr::from_ptr(json_ptr).to_string_lossy().into_owned();
        sck_free_string(json_ptr);

        // Parse JSON
        let json_windows: Vec<JsonWindowInfo> = serde_json::from_str(&json_str)
            .map_err(|e| anyhow!("Failed to parse windows JSON: {}", e))?;

        let windows: Vec<WindowInfo> = json_windows
            .into_iter()
            .map(|w| WindowInfo {
                id: w.id,
                title: w.title,
                app: w.app,
                bounds: WindowBounds {
                    x: w.bounds.x,
                    y: w.bounds.y,
                    width: w.bounds.width,
                    height: w.bounds.height,
                },
            })
            .collect();

        debug!("Got {} windows from ScreenCaptureKit", windows.len());
        Ok(windows)
    }
}

/// Check if screen recording permission is granted
#[cfg(target_os = "macos")]
pub fn has_permission() -> bool {
    unsafe { sck_has_permission() == 1 }
}

/// Get count of available windows
#[cfg(target_os = "macos")]
pub fn get_window_count() -> i32 {
    unsafe { sck_get_window_count() }
}

/// Start capturing a window
#[cfg(target_os = "macos")]
pub fn start_capture(window_id: u32) -> Result<()> {
    unsafe {
        let result = sck_start_capture(window_id);
        if result != 0 {
            return Err(anyhow!("Failed to start capture for window {}", window_id));
        }
    }
    Ok(())
}

/// Stop capturing a window
#[cfg(target_os = "macos")]
pub fn stop_capture(window_id: u32) -> Result<()> {
    unsafe {
        let result = sck_stop_capture(window_id);
        if result != 0 {
            return Err(anyhow!("Failed to stop capture for window {}", window_id));
        }
    }
    Ok(())
}

// Stub implementations for non-macOS platforms
#[cfg(not(target_os = "macos"))]
pub fn get_windows() -> Result<Vec<WindowInfo>> {
    tracing::warn!("ScreenCaptureKit is only available on macOS");
    Ok(Vec::new())
}

#[cfg(not(target_os = "macos"))]
pub fn has_permission() -> bool {
    false
}

#[cfg(not(target_os = "macos"))]
pub fn get_window_count() -> i32 {
    0
}

#[cfg(not(target_os = "macos"))]
pub fn start_capture(_window_id: u32) -> Result<()> {
    Err(anyhow!("ScreenCaptureKit is only available on macOS"))
}

#[cfg(not(target_os = "macos"))]
pub fn stop_capture(_window_id: u32) -> Result<()> {
    Err(anyhow!("ScreenCaptureKit is only available on macOS"))
}
