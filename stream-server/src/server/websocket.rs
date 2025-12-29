//! WebSocket connection handling

use std::sync::Arc;

use anyhow::{anyhow, Result};
use futures_util::{SinkExt, StreamExt};
use serde::{Deserialize, Serialize};
use tokio::net::TcpStream;
use tokio_tungstenite::{accept_async, tungstenite::Message};
use tracing::{debug, error, info, warn};

use super::ServerState;
use crate::capture::WindowInfo;
use crate::input::{KeyEvent, MouseEvent, TextEvent};

/// ICE candidate with full WebRTC fields
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct IceCandidate {
    /// The SDP candidate string
    pub candidate: String,
    /// The SDP media stream identification tag
    #[serde(default)]
    pub sdp_mid: Option<String>,
    /// The index of the media description in the SDP
    #[serde(default, alias = "sdpMLineIndex")]
    pub sdp_m_line_index: Option<u16>,
}

/// Incoming WebSocket message types
#[derive(Debug, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum IncomingMessage {
    /// WebRTC offer from client (initial connection)
    Offer { sdp: String },
    /// WebRTC answer from client (response to server's renegotiation offer)
    Answer { sdp: String },
    /// ICE candidate from client
    Ice { candidate: IceCandidate },
    /// Subscribe to window streams
    Subscribe { window_ids: Vec<u32> },
    /// Update viewport for a window (crop region for zoom)
    Viewport {
        window_id: u32,
        /// Left edge (0.0 = left, 1.0 = right)
        x: f32,
        /// Top edge (0.0 = top, 1.0 = bottom)
        y: f32,
        /// Width as fraction of source (1.0 = full width)
        width: f32,
        /// Height as fraction of source (1.0 = full height)
        height: f32,
    },
    /// Mouse input event
    Mouse(MouseEvent),
    /// Keyboard input event
    Key(KeyEvent),
    /// Text input event (for typing text)
    Text(TextEvent),
    /// Request window list
    GetWindows,
}

/// Outgoing WebSocket message types
#[derive(Debug, Serialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum OutgoingMessage {
    /// WebRTC answer to client (response to client's offer)
    Answer { sdp: String },
    /// WebRTC offer to client (renegotiation - server initiated)
    Offer { sdp: String },
    /// ICE candidate to client
    Ice { candidate: IceCandidate },
    /// List of available windows
    WindowList { windows: Vec<WindowInfo> },
    /// Window closed notification
    WindowClosed { id: u32 },
    /// Error response
    Error { message: String },
}

/// Handle a WebSocket connection
pub async fn handle_connection(stream: TcpStream, state: Arc<ServerState>) -> Result<()> {
    let ws_stream = accept_async(stream).await?;
    let (mut write, mut read) = ws_stream.split();

    info!("WebSocket connection established");

    // Send initial window list
    let windows = state.capture_manager.get_windows();
    let msg = OutgoingMessage::WindowList { windows };
    let json = serde_json::to_string(&msg)?;
    write.send(Message::Text(json)).await?;

    // Process incoming messages
    while let Some(msg) = read.next().await {
        match msg {
            Ok(Message::Text(text)) => {
                debug!("Received message: {}", text);
                match serde_json::from_str::<IncomingMessage>(&text) {
                    Ok(incoming) => {
                        if let Err(e) = handle_message(incoming, &state, &mut write).await {
                            error!("Error handling message: {}", e);
                            let error_msg = OutgoingMessage::Error {
                                message: e.to_string(),
                            };
                            let json = serde_json::to_string(&error_msg)?;
                            write.send(Message::Text(json)).await?;
                        }
                    }
                    Err(e) => {
                        warn!("Failed to parse message: {}", e);
                        let error_msg = OutgoingMessage::Error {
                            message: format!("Invalid message format: {}", e),
                        };
                        let json = serde_json::to_string(&error_msg)?;
                        write.send(Message::Text(json)).await?;
                    }
                }
            }
            Ok(Message::Binary(_)) => {
                warn!("Received unexpected binary message");
            }
            Ok(Message::Ping(data)) => {
                write.send(Message::Pong(data)).await?;
            }
            Ok(Message::Pong(_)) => {}
            Ok(Message::Close(_)) => {
                info!("WebSocket connection closed by client");
                break;
            }
            Ok(Message::Frame(_)) => {}
            Err(e) => {
                error!("WebSocket error: {}", e);
                break;
            }
        }
    }

    info!("WebSocket connection ended");
    Ok(())
}

/// Handle a parsed incoming message
async fn handle_message<S>(
    message: IncomingMessage,
    state: &ServerState,
    write: &mut S,
) -> Result<()>
where
    S: SinkExt<Message> + Unpin,
    S::Error: std::error::Error + Send + Sync + 'static,
{
    match message {
        IncomingMessage::Offer { sdp } => {
            info!("Received WebRTC offer");
            let answer_sdp = state.webrtc_manager.write().await.handle_offer(&sdp).await?;
            let response = OutgoingMessage::Answer { sdp: answer_sdp };
            let json = serde_json::to_string(&response)?;
            write
                .send(Message::Text(json))
                .await
                .map_err(|e| anyhow!("Send error: {}", e))?;
        }

        IncomingMessage::Answer { sdp } => {
            info!("Received renegotiation answer from client");
            state.webrtc_manager.write().await.handle_renegotiation_answer(&sdp).await?;
        }

        IncomingMessage::Ice { candidate } => {
            debug!("Received ICE candidate: {:?}", candidate);
            state.webrtc_manager.write().await.add_ice_candidate(candidate).await?;
        }

        IncomingMessage::Subscribe { window_ids } => {
            info!("Subscribe request for windows: {:?}", window_ids);
            
            for window_id in window_ids {
                state.capture_manager.start_capture(window_id)?;
                
                // Add track and get renegotiation offer if needed
                if let Some(offer_sdp) = state.webrtc_manager.write().await.add_window_track(window_id).await? {
                    // Send renegotiation offer to client
                    let response = OutgoingMessage::Offer { sdp: offer_sdp };
                    let json = serde_json::to_string(&response)?;
                    write
                        .send(Message::Text(json))
                        .await
                        .map_err(|e| anyhow!("Send error: {}", e))?;
                    info!("Sent renegotiation offer to client for window {}", window_id);
                    
                    // Request a keyframe so client gets fresh decoder state after renegotiation
                    if let Err(e) = crate::capture::request_keyframe(window_id) {
                        debug!("Could not request keyframe for {}: {}", window_id, e);
                    }
                }
            }
        }

        IncomingMessage::Viewport { window_id, x, y, width, height } => {
            debug!("Viewport update for window {}: x={}, y={}, w={}, h={}", 
                   window_id, x, y, width, height);
            
            let viewport = crate::video::Viewport { x, y, width, height };
            state.set_viewport(window_id, viewport);
            
            // Request a keyframe when viewport changes significantly
            // This ensures the client gets a fresh frame with the new crop
            if let Err(e) = crate::capture::request_keyframe(window_id) {
                debug!("Could not request keyframe for viewport change: {}", e);
            }
        }

        IncomingMessage::Mouse(event) => {
            debug!("Mouse event: {:?}", event);
            state.input_injector.inject_mouse(&event)?;
        }

        IncomingMessage::Key(event) => {
            debug!("Key event: {:?}", event);
            state.input_injector.inject_key(&event)?;
        }

        IncomingMessage::Text(event) => {
            debug!("Text event: {:?}", event);
            state.input_injector.inject_text(&event)?;
        }

        IncomingMessage::GetWindows => {
            let windows = state.capture_manager.get_windows();
            let response = OutgoingMessage::WindowList { windows };
            let json = serde_json::to_string(&response)?;
            write
                .send(Message::Text(json))
                .await
                .map_err(|e| anyhow!("Send error: {}", e))?;
        }
    }

    Ok(())
}
