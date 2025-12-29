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

impl Config {
    /// Create a new config with a custom port
    pub fn new(port: u16) -> Self {
        let server_name = hostname::get()
            .ok()
            .and_then(|h| h.into_string().ok())
            .unwrap_or_else(|| "Blink Stream Server".to_string());

        Self {
            port,
            server_name,
            version: "1".to_string(),
        }
    }

    /// Create a new config with custom port and server name
    pub fn with_name(port: u16, server_name: String) -> Self {
        Self {
            port,
            server_name,
            version: "1".to_string(),
        }
    }
}

impl Default for Config {
    fn default() -> Self {
        Self::new(8080)
    }
}


