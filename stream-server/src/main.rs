//! Blink Stream Server - macOS window streaming via WebRTC
//!
//! This server captures macOS windows using ScreenCaptureKit and streams them
//! to iOS/Flutter clients via WebRTC.

mod capture;
mod config;
mod input;
mod server;
mod webrtc_handler;

use anyhow::Result;
use tracing::{info, Level};
use tracing_subscriber::FmtSubscriber;

use crate::config::Config;
use crate::server::Server;

#[tokio::main]
async fn main() -> Result<()> {
    // Initialize logging
    let subscriber = FmtSubscriber::builder()
        .with_max_level(Level::INFO)
        .with_target(true)
        .with_thread_ids(true)
        .finish();
    tracing::subscriber::set_global_default(subscriber)?;

    info!("Starting Blink Stream Server");

    // Initialize ScreenCaptureKit bridge (required for Window Server access)
    capture::initialize()?;
    info!("ScreenCaptureKit bridge initialized");

    // Load configuration
    let config = Config::default();
    info!("Configuration loaded: port={}", config.port);

    // Start mDNS advertisement
    let mdns_handle = server::mdns::advertise_service(config.port, &config.server_name)?;
    info!("mDNS service advertised as _blink._tcp on port {}", config.port);

    // Create and run the server
    let server = Server::new(config);
    
    info!("Server starting on 0.0.0.0:{}", server.config().port);
    server.run().await?;

    // Cleanup
    drop(mdns_handle);

    Ok(())
}


