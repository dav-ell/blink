//! Screen capture module using ScreenCaptureKit bridge

mod bridge;

pub use bridge::{initialize, set_frame_callback, EncodedFrame, FrameCallbackFn};

use std::collections::HashMap;
use std::sync::Arc;

use anyhow::Result;
use parking_lot::RwLock;
use serde::{Deserialize, Serialize};
use tracing::info;

/// Window bounds
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WindowBounds {
    pub x: f64,
    pub y: f64,
    pub width: f64,
    pub height: f64,
}

/// Information about a capturable window
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WindowInfo {
    pub id: u32,
    pub title: String,
    pub app: String,
    pub bounds: WindowBounds,
}

/// Captured frame data
#[derive(Debug)]
pub struct CapturedFrame {
    pub window_id: u32,
    pub width: u32,
    pub height: u32,
    pub data: Vec<u8>,
    pub timestamp: u64,
}

/// Callback type for frame capture
pub type FrameCallback = Arc<dyn Fn(CapturedFrame) + Send + Sync>;

/// Manages window capture sessions
pub struct CaptureManager {
    active_captures: RwLock<HashMap<u32, CaptureSession>>,
    frame_callbacks: RwLock<HashMap<u32, FrameCallback>>,
}

struct CaptureSession {
    window_id: u32,
    #[allow(dead_code)]
    is_active: bool,
}

impl CaptureManager {
    pub fn new() -> Self {
        Self {
            active_captures: RwLock::new(HashMap::new()),
            frame_callbacks: RwLock::new(HashMap::new()),
        }
    }

    /// Get list of all available windows
    pub fn get_windows(&self) -> Vec<WindowInfo> {
        // Call into Swift bridge to enumerate windows
        match bridge::get_windows() {
            Ok(windows) => windows,
            Err(e) => {
                tracing::error!("Failed to get windows: {}", e);
                Vec::new()
            }
        }
    }

    /// Get bounds for a specific window
    pub fn get_window_bounds(&self, window_id: u32) -> Option<WindowBounds> {
        self.get_windows()
            .into_iter()
            .find(|w| w.id == window_id)
            .map(|w| w.bounds)
    }

    /// Start capturing a window
    pub fn start_capture(&self, window_id: u32) -> Result<()> {
        let mut captures = self.active_captures.write();

        if captures.contains_key(&window_id) {
            info!("Capture already active for window {}", window_id);
            return Ok(());
        }

        // Start capture via Swift bridge
        bridge::start_capture(window_id)?;

        captures.insert(
            window_id,
            CaptureSession {
                window_id,
                is_active: true,
            },
        );

        info!("Started capture for window {}", window_id);
        Ok(())
    }

    /// Stop capturing a window
    pub fn stop_capture(&self, window_id: u32) -> Result<()> {
        let mut captures = self.active_captures.write();

        if let Some(_session) = captures.remove(&window_id) {
            bridge::stop_capture(window_id)?;
            info!("Stopped capture for window {}", window_id);
        }

        self.frame_callbacks.write().remove(&window_id);

        Ok(())
    }

    /// Register a callback for captured frames
    pub fn set_frame_callback(&self, window_id: u32, callback: FrameCallback) {
        self.frame_callbacks.write().insert(window_id, callback);
    }

    /// Called by the Swift bridge when a frame is captured
    pub fn on_frame(&self, frame: CapturedFrame) {
        let callbacks = self.frame_callbacks.read();
        if let Some(callback) = callbacks.get(&frame.window_id) {
            callback(frame);
        }
    }
}

impl Default for CaptureManager {
    fn default() -> Self {
        Self::new()
    }
}
