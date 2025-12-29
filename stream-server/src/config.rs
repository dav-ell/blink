//! Server configuration

use std::env;

/// Video resolution presets
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum VideoResolution {
    /// 854x480
    Resolution480p,
    /// 1280x720
    Resolution720p,
    /// 1920x1080
    Resolution1080p,
    /// Custom resolution
    Custom { width: u32, height: u32 },
}

impl VideoResolution {
    /// Get width and height
    pub fn dimensions(&self) -> (u32, u32) {
        match self {
            VideoResolution::Resolution480p => (854, 480),
            VideoResolution::Resolution720p => (1280, 720),
            VideoResolution::Resolution1080p => (1920, 1080),
            VideoResolution::Custom { width, height } => (*width, *height),
        }
    }
    
    /// Parse from environment variable string (e.g., "720p", "1080p", "1920x1080")
    pub fn from_str(s: &str) -> Option<Self> {
        match s.to_lowercase().as_str() {
            "480p" => Some(VideoResolution::Resolution480p),
            "720p" => Some(VideoResolution::Resolution720p),
            "1080p" => Some(VideoResolution::Resolution1080p),
            _ => {
                // Try to parse as WxH format
                let parts: Vec<&str> = s.split('x').collect();
                if parts.len() == 2 {
                    let width = parts[0].parse().ok()?;
                    let height = parts[1].parse().ok()?;
                    Some(VideoResolution::Custom { width, height })
                } else {
                    None
                }
            }
        }
    }
}

impl Default for VideoResolution {
    fn default() -> Self {
        VideoResolution::Resolution720p
    }
}

/// Server configuration settings
#[derive(Debug, Clone)]
pub struct Config {
    /// WebSocket server port
    pub port: u16,
    /// Server name for mDNS advertisement
    pub server_name: String,
    /// API version
    pub version: String,
    /// Video output resolution
    pub video_resolution: VideoResolution,
    /// Whether video scaling is enabled
    pub video_scaling_enabled: bool,
}

impl Config {
    /// Create a new config with a custom port
    pub fn new(port: u16) -> Self {
        let server_name = hostname::get()
            .ok()
            .and_then(|h| h.into_string().ok())
            .unwrap_or_else(|| "Blink Stream Server".to_string());

        // Check environment variables for video settings
        let video_resolution = env::var("BLINK_VIDEO_RESOLUTION")
            .ok()
            .and_then(|s| VideoResolution::from_str(&s))
            .or_else(|| {
                // Try BLINK_VIDEO_WIDTH and BLINK_VIDEO_HEIGHT
                let width = env::var("BLINK_VIDEO_WIDTH").ok()?.parse().ok()?;
                let height = env::var("BLINK_VIDEO_HEIGHT").ok()?.parse().ok()?;
                Some(VideoResolution::Custom { width, height })
            })
            .unwrap_or_default();
        
        let video_scaling_enabled = env::var("BLINK_VIDEO_SCALING")
            .map(|s| s != "0" && s.to_lowercase() != "false")
            .unwrap_or(true);

        Self {
            port,
            server_name,
            version: "1".to_string(),
            video_resolution,
            video_scaling_enabled,
        }
    }

    /// Create a new config with custom port and server name
    pub fn with_name(port: u16, server_name: String) -> Self {
        let mut config = Self::new(port);
        config.server_name = server_name;
        config
    }
    
    /// Get video dimensions
    pub fn video_dimensions(&self) -> (u32, u32) {
        self.video_resolution.dimensions()
    }
}

impl Default for Config {
    fn default() -> Self {
        Self::new(8080)
    }
}


