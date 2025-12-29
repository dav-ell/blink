//! WebSocket server module

pub mod mdns;
pub mod websocket;

use std::sync::Arc;

use anyhow::Result;
use tokio::net::TcpListener;
use tokio::sync::RwLock;
use tracing::{error, info};

use crate::capture::CaptureManager;
use crate::config::Config;
use crate::input::InputInjector;
use crate::webrtc_handler::WebRtcManager;

/// Shared server state
pub struct ServerState {
    pub capture_manager: CaptureManager,
    pub webrtc_manager: RwLock<WebRtcManager>,
    pub input_injector: InputInjector,
}

impl ServerState {
    pub fn new() -> Self {
        Self {
            capture_manager: CaptureManager::new(),
            webrtc_manager: RwLock::new(WebRtcManager::new()),
            input_injector: InputInjector::new(),
        }
    }
}

impl Default for ServerState {
    fn default() -> Self {
        Self::new()
    }
}

/// Main WebSocket server
pub struct Server {
    config: Config,
    state: Arc<ServerState>,
}

impl Server {
    pub fn new(config: Config) -> Self {
        Self {
            config,
            state: Arc::new(ServerState::new()),
        }
    }

    pub fn config(&self) -> &Config {
        &self.config
    }

    pub async fn run(&self) -> Result<()> {
        let addr = format!("0.0.0.0:{}", self.config.port);
        let listener = TcpListener::bind(&addr).await?;

        info!("WebSocket server listening on {}", addr);

        loop {
            match listener.accept().await {
                Ok((stream, addr)) => {
                    info!("New connection from {}", addr);
                    let state = Arc::clone(&self.state);
                    tokio::spawn(async move {
                        if let Err(e) = websocket::handle_connection(stream, state).await {
                            error!("Connection error from {}: {}", addr, e);
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
