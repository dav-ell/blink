//! WebSocket server module

pub mod mdns;
pub mod websocket;

use std::sync::Arc;

use anyhow::Result;
use parking_lot::RwLock as SyncRwLock;
use tokio::net::TcpListener;
use tokio::sync::{mpsc, RwLock};
use tokio_util::sync::CancellationToken;
use tracing::{debug, error, info, trace};

use std::collections::HashMap;

use crate::capture::{CaptureManager, EncodedFrame, set_frame_callback};
use crate::config::Config;
use crate::input::InputInjector;
use crate::video::{VideoConfig, Viewport};
use crate::webrtc_handler::{WebRtcManager, H264RtpPacketizer};

/// Frame data to be sent via channel (owned version of EncodedFrame)
struct FrameData {
    window_id: u32,
    timestamp_ms: u64,
    data: Vec<u8>,
}

/// Optional frame saver for debugging/testing
struct FrameSaver {
    file: std::sync::Mutex<std::fs::File>,
    frame_count: std::sync::atomic::AtomicU32,
}

impl FrameSaver {
    fn new(path: &str) -> Option<Self> {
        std::fs::File::create(path).ok().map(|f| {
            info!("Saving H.264 frames to: {}", path);
            Self {
                file: std::sync::Mutex::new(f),
                frame_count: std::sync::atomic::AtomicU32::new(0),
            }
        })
    }

    fn save_frame(&self, data: &[u8]) {
        use std::io::Write;
        use std::sync::atomic::Ordering;
        
        let count = self.frame_count.fetch_add(1, Ordering::SeqCst) + 1;
        
        if let Ok(mut f) = self.file.lock() {
            // Write Annex-B start code
            let _ = f.write_all(&[0x00, 0x00, 0x00, 0x01]);
            // Write NAL data
            let _ = f.write_all(data);
            
            if count == 1 || count % 30 == 0 {
                info!("Saved frame #{} ({} bytes)", count, data.len());
            }
        }
    }

    fn frame_count(&self) -> u32 {
        use std::sync::atomic::Ordering;
        self.frame_count.load(Ordering::SeqCst)
    }
}

/// Global frame saver, enabled via BLINK_SAVE_FRAMES environment variable
static FRAME_SAVER: std::sync::OnceLock<Option<FrameSaver>> = std::sync::OnceLock::new();

fn get_frame_saver() -> &'static Option<FrameSaver> {
    FRAME_SAVER.get_or_init(|| {
        std::env::var("BLINK_SAVE_FRAMES").ok().and_then(|path| FrameSaver::new(&path))
    })
}

/// Global channel sender for frame callback
static FRAME_SENDER: SyncRwLock<Option<mpsc::UnboundedSender<FrameData>>> = SyncRwLock::new(None);

/// Shared server state
pub struct ServerState {
    pub capture_manager: CaptureManager,
    pub webrtc_manager: RwLock<WebRtcManager>,
    pub input_injector: InputInjector,
    pub rtp_packetizer: H264RtpPacketizer,
    /// Video configuration for scaling
    pub video_config: VideoConfig,
    /// Viewport per window (for crop/zoom)
    pub viewports: SyncRwLock<HashMap<u32, Viewport>>,
}

impl ServerState {
    pub fn new() -> Self {
        Self::with_video_config(VideoConfig::default())
    }
    
    pub fn with_video_config(video_config: VideoConfig) -> Self {
        Self {
            capture_manager: CaptureManager::new(),
            webrtc_manager: RwLock::new(WebRtcManager::new()),
            input_injector: InputInjector::new(),
            rtp_packetizer: H264RtpPacketizer::new(),
            video_config,
            viewports: SyncRwLock::new(HashMap::new()),
        }
    }
    
    /// Set viewport for a window
    pub fn set_viewport(&self, window_id: u32, viewport: Viewport) {
        self.viewports.write().insert(window_id, viewport);
        debug!("Updated viewport for window {}: {:?}", window_id, viewport);
    }
    
    /// Get viewport for a window (defaults to full frame)
    pub fn get_viewport(&self, window_id: u32) -> Viewport {
        self.viewports
            .read()
            .get(&window_id)
            .copied()
            .unwrap_or_default()
    }
}

impl Default for ServerState {
    fn default() -> Self {
        Self::new()
    }
}

/// Frame callback that receives encoded frames from Swift and sends via channel
extern "C" fn on_encoded_frame(frame_ptr: *const EncodedFrame) {
    if frame_ptr.is_null() {
        return;
    }
    
    let frame = unsafe { &*frame_ptr };
    
    // Get data slice from the raw pointer
    let data = if frame.data.is_null() || frame.data_len == 0 {
        debug!("Empty frame received for window {}", frame.window_id);
        return;
    } else {
        unsafe { std::slice::from_raw_parts(frame.data, frame.data_len) }
    };
    
    debug!(
        "Received encoded frame: window={}, size={}, keyframe={}, timestamp={}",
        frame.window_id,
        frame.data_len,
        frame.is_keyframe,
        frame.timestamp_ms
    );
    
    // Save frame to file if BLINK_SAVE_FRAMES is set
    if let Some(saver) = get_frame_saver() {
        saver.save_frame(data);
    }
    
    // Send frame via channel (non-blocking)
    let sender_guard = FRAME_SENDER.read();
    if let Some(sender) = sender_guard.as_ref() {
        let frame_data = FrameData {
            window_id: frame.window_id,
            timestamp_ms: frame.timestamp_ms,
            data: data.to_vec(),
        };
        
        if let Err(e) = sender.send(frame_data) {
            error!("Failed to send frame to channel: {}", e);
        }
    } else {
        debug!("No frame sender available");
    }
}

/// Main WebSocket server
pub struct Server {
    config: Config,
    state: Arc<ServerState>,
    cancel_token: CancellationToken,
}

impl Server {
    pub fn new(config: Config) -> Self {
        Self::with_cancel_token(config, CancellationToken::new())
    }

    /// Create a server with a custom cancellation token for graceful shutdown
    pub fn with_cancel_token(config: Config, cancel_token: CancellationToken) -> Self {
        // Create video config from server config
        let (target_width, target_height) = config.video_dimensions();
        let video_config = VideoConfig {
            target_width,
            target_height,
            enable_scaling: config.video_scaling_enabled,
        };
        
        let state = Arc::new(ServerState::with_video_config(video_config));
        
        // Register the frame callback
        set_frame_callback(on_encoded_frame);
        info!("Frame callback registered for video streaming");
        
        Self {
            config,
            state,
            cancel_token,
        }
    }

    pub fn config(&self) -> &Config {
        &self.config
    }

    /// Get the cancellation token for external shutdown control
    pub fn cancel_token(&self) -> CancellationToken {
        self.cancel_token.clone()
    }

    /// Trigger graceful shutdown
    pub fn shutdown(&self) {
        self.cancel_token.cancel();
    }
    
    // #region agent log
    fn debug_log(hypothesis: &str, location: &str, message: &str, data: &str) {
        use std::io::Write;
        let ts = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap_or_default()
            .as_millis();
        let log_line = format!(
            "{{\"hypothesisId\":\"{}\",\"location\":\"{}\",\"message\":\"{}\",\"data\":{},\"timestamp\":{},\"sessionId\":\"debug-session\"}}\n",
            hypothesis, location, message, data, ts
        );
        if let Ok(mut f) = std::fs::OpenOptions::new()
            .create(true)
            .append(true)
            .open("/Users/davell/Documents/github/blink/.cursor/debug.log") 
        {
            let _ = f.write_all(log_line.as_bytes());
        }
    }
    // #endregion

    pub async fn run(&self) -> Result<()> {
        // Create channel for frame data
        let (tx, mut rx) = mpsc::unbounded_channel::<FrameData>();
        
        // Store sender globally for the FFI callback
        {
            let mut sender_guard = FRAME_SENDER.write();
            *sender_guard = Some(tx);
        }
        
        // Spawn frame processing task
        let state_for_frames = Arc::clone(&self.state);
        let cancel_for_frames = self.cancel_token.clone();
        tokio::spawn(async move {
            info!("Frame processing task started");
            let mut frame_count: u64 = 0;
            
            loop {
                tokio::select! {
                    _ = cancel_for_frames.cancelled() => {
                        info!("Frame processing task cancelled");
                        break;
                    }
                    frame = rx.recv() => {
                        let Some(frame) = frame else {
                            break;
                        };
                        
                        frame_count += 1;
                        
                        // #region agent log
                        // Log first few frames to see timing
                        if frame_count <= 5 || frame_count % 60 == 0 {
                            Self::debug_log("E", "mod.rs:frame_task", "Frame received in task", 
                                &format!("{{\"frame_count\":{},\"window_id\":{},\"size\":{}}}", 
                                    frame_count, frame.window_id, frame.data.len()));
                        }
                        // #endregion
                        
                        // Get the track for this window
                        let webrtc = state_for_frames.webrtc_manager.read().await;
                        let track = match webrtc.get_track(frame.window_id) {
                            Some(t) => t,
                            None => {
                                // #region agent log
                                if frame_count <= 10 {
                                    Self::debug_log("E", "mod.rs:frame_task", "No track for frame", 
                                        &format!("{{\"frame_count\":{},\"window_id\":{}}}", frame_count, frame.window_id));
                                }
                                // #endregion
                                if frame_count % 30 == 1 {
                                    debug!("No track for window {} (frame #{})", frame.window_id, frame_count);
                                }
                                continue;
                            }
                        };
                        drop(webrtc);
                        
                        // Convert timestamp to RTP timestamp (90kHz clock)
                        let rtp_timestamp = (frame.timestamp_ms * 90) as u32;
                        
                        // Log every 30th frame
                        if frame_count % 30 == 1 {
                            info!("Sending frame #{} for window {}, size={} bytes", 
                                  frame_count, frame.window_id, frame.data.len());
                        }
                        
                        // Packetize and send
                        if let Err(e) = state_for_frames.rtp_packetizer
                            .packetize_and_send(&track, &frame.data, rtp_timestamp)
                            .await 
                        {
                            debug!("Failed to send frame: {}", e);
                        }
                        
                        // #region agent log
                        if frame_count <= 5 {
                            Self::debug_log("E", "mod.rs:frame_task", "Frame sent via RTP", 
                                &format!("{{\"frame_count\":{}}}", frame_count));
                        }
                        // #endregion
                    }
                }
            }
            
            info!("Frame processing task ended");
        });
        
        let addr = format!("0.0.0.0:{}", self.config.port);
        let listener = TcpListener::bind(&addr).await?;

        info!("WebSocket server listening on {}", addr);

        loop {
            tokio::select! {
                _ = self.cancel_token.cancelled() => {
                    info!("Server shutdown requested");
                    break;
                }
                result = listener.accept() => {
                    match result {
                        Ok((stream, addr)) => {
                            info!("New connection from {}", addr);
                            let state = Arc::clone(&self.state);
                            let cancel = self.cancel_token.clone();
                            tokio::spawn(async move {
                                tokio::select! {
                                    _ = cancel.cancelled() => {
                                        debug!("Connection handler cancelled for {}", addr);
                                    }
                                    result = websocket::handle_connection(stream, state) => {
                                        if let Err(e) = result {
                                            error!("Connection error from {}: {}", addr, e);
                                        }
                                    }
                                }
                            });
                        }
                        Err(e) => {
                            error!("Failed to accept connection: {}", e);
                        }
                    }
                }
            }
        }

        info!("Server shut down gracefully");
        Ok(())
    }
}

impl Drop for Server {
    fn drop(&mut self) {
        // Clear the channel sender
        let mut sender_guard = FRAME_SENDER.write();
        *sender_guard = None;
    }
}
