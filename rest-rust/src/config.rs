use config::{Config, ConfigError, Environment, File};
use serde::Deserialize;
use std::path::PathBuf;

#[derive(Debug, Deserialize, Clone)]
pub struct Settings {
    // Database configuration
    pub db_path: PathBuf,
    
    // Cursor agent configuration
    pub cursor_agent_path: PathBuf,
    pub cursor_agent_timeout: u64,
    
    // API server configuration
    pub api_host: String,
    pub api_port: u16,
    pub api_reload: bool,
    
    // Job management configuration
    pub job_cleanup_max_age_hours: u64,
    pub job_cleanup_interval_minutes: u64,
    
    // Device management configuration
    pub device_db_path: PathBuf,
    
    // SSH configuration
    pub ssh_timeout: u64,
    pub ssh_connect_timeout: u64,
    pub default_cursor_agent_path: String,
    
    // CORS configuration
    pub cors_allow_origins: Vec<String>,
    pub cors_allow_credentials: bool,
}

impl Settings {
    pub fn new() -> Result<Self, ConfigError> {
        let home = std::env::var("HOME").unwrap_or_else(|_| ".".to_string());
        
        let builder = Config::builder()
            // Set defaults
            .set_default("db_path", format!("{}/Library/Application Support/Cursor/User/globalStorage/state.vscdb", home))?
            .set_default("cursor_agent_path", format!("{}/.local/bin/cursor-agent", home))?
            .set_default("cursor_agent_timeout", 90)?
            .set_default("api_host", "0.0.0.0")?
            .set_default("api_port", 8000)?
            .set_default("api_reload", false)?
            .set_default("job_cleanup_max_age_hours", 1)?
            .set_default("job_cleanup_interval_minutes", 30)?
            .set_default("device_db_path", format!("{}/.cursor_agent_devices.db", home))?
            .set_default("ssh_timeout", 120)?
            .set_default("ssh_connect_timeout", 10)?
            .set_default("default_cursor_agent_path", "~/.local/bin/cursor-agent")?
            .set_default("cors_allow_origins", vec!["*"])?
            .set_default("cors_allow_credentials", true)?
            // Add .env file if it exists
            .add_source(File::with_name(".env").required(false))
            // Add environment variables (with no prefix)
            .add_source(Environment::default());

        let config = builder.build()?;
        config.try_deserialize()
    }
}

impl Default for Settings {
    fn default() -> Self {
        Self::new().expect("Failed to load configuration")
    }
}

