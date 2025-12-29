//! WebRTC module for peer connections and video streaming

mod peer;
mod tracks;

use std::collections::HashMap;
use std::sync::Arc;

use anyhow::{anyhow, Result};
use tracing::{debug, info};
use webrtc::api::media_engine::MediaEngine;
use webrtc::api::APIBuilder;
use webrtc::ice_transport::ice_candidate::RTCIceCandidateInit;
use webrtc::ice_transport::ice_server::RTCIceServer;
use webrtc::peer_connection::configuration::RTCConfiguration;
use webrtc::peer_connection::sdp::session_description::RTCSessionDescription;
use webrtc::peer_connection::RTCPeerConnection;
use webrtc::rtp_transceiver::rtp_codec::RTCRtpCodecCapability;
use webrtc::track::track_local::track_local_static_rtp::TrackLocalStaticRTP;

pub use tracks::{create_window_track, H264RtpPacketizer};

/// Manages WebRTC peer connections and video tracks
pub struct WebRtcManager {
    /// Current peer connection (single client for now)
    peer_connection: Option<Arc<RTCPeerConnection>>,
    /// Active video tracks by window ID
    window_tracks: HashMap<u32, Arc<TrackLocalStaticRTP>>,
    /// API for creating peer connections
    api: webrtc::api::API,
}

impl WebRtcManager {
    pub fn new() -> Self {
        // Create media engine with H264 support
        let mut media_engine = MediaEngine::default();

        // Register H264 codec
        let _ = media_engine.register_default_codecs();

        // Build API
        let api = APIBuilder::new()
            .with_media_engine(media_engine)
            .build();

        Self {
            peer_connection: None,
            window_tracks: HashMap::new(),
            api,
        }
    }

    /// Handle WebRTC offer from client
    pub async fn handle_offer(&mut self, sdp: &str) -> Result<String> {
        info!("Processing WebRTC offer");

        // Create RTCConfiguration with STUN servers
        let config = RTCConfiguration {
            ice_servers: vec![RTCIceServer {
                urls: vec!["stun:stun.l.google.com:19302".to_string()],
                ..Default::default()
            }],
            ..Default::default()
        };

        // Create new peer connection
        let peer_connection = Arc::new(self.api.new_peer_connection(config).await?);

        // Set up event handlers
        peer_connection.on_ice_connection_state_change(Box::new(move |state| {
            info!("ICE connection state changed: {:?}", state);
            Box::pin(async {})
        }));

        peer_connection.on_peer_connection_state_change(Box::new(move |state| {
            info!("Peer connection state changed: {:?}", state);
            Box::pin(async {})
        }));

        // Parse and set remote description (offer)
        let offer = RTCSessionDescription::offer(sdp.to_string())?;
        peer_connection.set_remote_description(offer).await?;

        // Create answer
        let answer = peer_connection.create_answer(None).await?;

        // Set local description
        peer_connection.set_local_description(answer.clone()).await?;

        // Store peer connection
        self.peer_connection = Some(peer_connection);

        info!("WebRTC answer created");
        Ok(answer.sdp)
    }

    /// Add ICE candidate from client
    pub async fn add_ice_candidate(&mut self, candidate: crate::server::websocket::IceCandidate) -> Result<()> {
        let peer_connection = self
            .peer_connection
            .as_ref()
            .ok_or_else(|| anyhow!("No peer connection established"))?;

        let ice_candidate = RTCIceCandidateInit {
            candidate: candidate.candidate,
            sdp_mid: candidate.sdp_mid,
            sdp_mline_index: candidate.sdp_m_line_index,
            username_fragment: None,
        };

        peer_connection.add_ice_candidate(ice_candidate).await?;
        debug!("Added ICE candidate");

        Ok(())
    }

    /// Add a video track for a window
    pub async fn add_window_track(&mut self, window_id: u32) -> Result<()> {
        let peer_connection = self
            .peer_connection
            .as_ref()
            .ok_or_else(|| anyhow!("No peer connection established"))?;

        // Check if track already exists
        if self.window_tracks.contains_key(&window_id) {
            debug!("Track already exists for window {}", window_id);
            return Ok(());
        }

        // Create video track
        let track = Arc::new(TrackLocalStaticRTP::new(
            RTCRtpCodecCapability {
                mime_type: "video/H264".to_string(),
                clock_rate: 90000,
                channels: 0,
                sdp_fmtp_line: "level-asymmetry-allowed=1;packetization-mode=1;profile-level-id=42e01f".to_string(),
                rtcp_feedback: vec![],
            },
            format!("window-{}", window_id),
            "blink-stream".to_string(),
        ));

        // Add track to peer connection
        let _sender = peer_connection
            .add_track(Arc::clone(&track) as Arc<dyn webrtc::track::track_local::TrackLocal + Send + Sync>)
            .await?;

        self.window_tracks.insert(window_id, track);
        info!("Added video track for window {}", window_id);

        Ok(())
    }

    /// Remove a video track for a window
    pub async fn remove_window_track(&mut self, window_id: u32) -> Result<()> {
        if let Some(_track) = self.window_tracks.remove(&window_id) {
            // Track removal from peer connection would require keeping sender reference
            // For now just remove from our map
            info!("Removed video track for window {}", window_id);
        }
        Ok(())
    }

    /// Get a track for writing frames
    pub fn get_track(&self, window_id: u32) -> Option<Arc<TrackLocalStaticRTP>> {
        self.window_tracks.get(&window_id).cloned()
    }

    /// Check if peer connection is established
    pub fn is_connected(&self) -> bool {
        self.peer_connection.is_some()
    }
}

impl Default for WebRtcManager {
    fn default() -> Self {
        Self::new()
    }
}
