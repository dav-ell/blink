//! Server configuration

/// Server configuration settings
#[derive(Debug, Clone)]
pub struct Config {
    /// WebSocket server port
    pub port: u16,
    /// Server name for mDNS advertisement
    pub server_name: String,
    /// API version
    pub version: String,
}

impl Default for Config {
    fn default() -> Self {
        let server_name = hostname::get()
            .ok()
            .and_then(|h| h.into_string().ok())
            .unwrap_or_else(|| "Blink Stream Server".to_string());

        Self {
            port: 8080,
            server_name,
            version: "1".to_string(),
        }
    }
}


