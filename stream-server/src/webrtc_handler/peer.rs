//! WebRTC peer connection management

use std::sync::Arc;

use webrtc::peer_connection::RTCPeerConnection;

/// Peer connection wrapper with additional state
pub struct PeerState {
    pub connection: Arc<RTCPeerConnection>,
    pub client_id: String,
}

impl PeerState {
    pub fn new(connection: Arc<RTCPeerConnection>, client_id: String) -> Self {
        Self {
            connection,
            client_id,
        }
    }
}
