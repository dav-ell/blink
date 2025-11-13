use anyhow::{Context, Result};
use std::env;

/// Application configuration
#[derive(Debug, Clone)]
pub struct Config {
    /// Host to bind to (default: 0.0.0.0)
    pub host: String,
    
    /// Port to listen on (default: 9876)
    pub port: u16,
    
    /// Path to cursor-agent executable
    pub cursor_agent_path: String,
    
    /// API key for authentication
    pub api_key: String,
    
    /// Command execution timeout in seconds
    pub execution_timeout: u64,
}

impl Config {
    /// Load configuration from environment variables
    pub fn from_env() -> Result<Self> {
        let host = env::var("HOST").unwrap_or_else(|_| "0.0.0.0".to_string());
        
        let port = env::var("PORT")
            .unwrap_or_else(|_| "9876".to_string())
            .parse()
            .context("Invalid PORT value")?;
        
        let cursor_agent_path = env::var("CURSOR_AGENT_PATH")
            .unwrap_or_else(|_| {
                // Try common paths
                if cfg!(target_os = "macos") || cfg!(target_os = "linux") {
                    shellexpand::tilde("~/.local/bin/cursor-agent").to_string()
                } else {
                    "cursor-agent".to_string()
                }
            });
        
        let api_key = env::var("API_KEY")
            .context("API_KEY environment variable is required")?;
        
        if api_key.len() < 16 {
            anyhow::bail!("API_KEY must be at least 16 characters long (got {} characters)", api_key.len());
        }
        
        let execution_timeout = env::var("EXECUTION_TIMEOUT")
            .unwrap_or_else(|_| "300".to_string())
            .parse()
            .context("Invalid EXECUTION_TIMEOUT value")?;
        
        Ok(Config {
            host,
            port,
            cursor_agent_path,
            api_key,
            execution_timeout,
        })
    }
}

