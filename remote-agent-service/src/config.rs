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
    
    /// Maximum execution timeout (safety limit)
    pub max_execution_timeout: u64,
    
    /// Health check interval in seconds
    pub health_check_interval: u64,
    
    /// Maximum concurrent executions
    pub max_concurrent_executions: usize,
    
    /// Enable request tracing with correlation IDs
    pub enable_request_tracing: bool,
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
        
        let max_execution_timeout = env::var("MAX_EXECUTION_TIMEOUT")
            .unwrap_or_else(|_| "600".to_string())
            .parse()
            .context("Invalid MAX_EXECUTION_TIMEOUT value")?;
        
        let health_check_interval = env::var("HEALTH_CHECK_INTERVAL")
            .unwrap_or_else(|_| "60".to_string())
            .parse()
            .context("Invalid HEALTH_CHECK_INTERVAL value")?;
        
        let max_concurrent_executions = env::var("MAX_CONCURRENT_EXECUTIONS")
            .unwrap_or_else(|_| "10".to_string())
            .parse()
            .context("Invalid MAX_CONCURRENT_EXECUTIONS value")?;
        
        let enable_request_tracing = env::var("ENABLE_REQUEST_TRACING")
            .unwrap_or_else(|_| "true".to_string())
            .parse()
            .unwrap_or(true);
        
        Ok(Config {
            host,
            port,
            cursor_agent_path,
            api_key,
            execution_timeout,
            max_execution_timeout,
            health_check_interval,
            max_concurrent_executions,
            enable_request_tracing,
        })
    }
}

