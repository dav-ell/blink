//! Blink Stream Server - macOS window streaming via WebRTC
//!
//! This server captures macOS windows using ScreenCaptureKit and streams them
//! to iOS/Flutter clients via WebRTC.

use anyhow::Result;
use std::env;
use tracing::{info, Level};
use tracing_subscriber::FmtSubscriber;

use blink_stream_server::capture;
use blink_stream_server::config::Config;
use blink_stream_server::server::{mdns, Server};
use blink_stream_server::video::VideoPipeline;

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

    // Initialize GStreamer for video processing
    VideoPipeline::init()?;
    info!("GStreamer initialized for video scaling");

    // Load configuration - check for BLINK_PORT env var or CLI arg
    let port = env::var("BLINK_PORT")
        .ok()
        .and_then(|p| p.parse::<u16>().ok())
        .or_else(|| {
            // Check for --port argument
            let args: Vec<String> = env::args().collect();
            args.iter()
                .position(|arg| arg == "--port")
                .and_then(|i| args.get(i + 1))
                .and_then(|p| p.parse::<u16>().ok())
        })
        .unwrap_or(8080);
    
    let config = Config::new(port);
    let (vw, vh) = config.video_dimensions();
    info!(
        "Configuration loaded: port={}, video={}x{}, scaling={}",
        config.port, vw, vh, config.video_scaling_enabled
    );

    // Start mDNS advertisement
    let mdns_handle = mdns::advertise_service(config.port, &config.server_name)?;
    info!("mDNS service advertised as _blink._tcp on port {}", config.port);

    // Create and run the server
    let server = Server::new(config);
    
    info!("Server starting on 0.0.0.0:{}", server.config().port);
    server.run().await?;

    // Cleanup
    drop(mdns_handle);

    Ok(())
}


