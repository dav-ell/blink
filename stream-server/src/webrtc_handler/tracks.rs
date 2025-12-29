//! Video track management for WebRTC streaming

use std::sync::Arc;

use anyhow::Result;
use tracing::debug;
use webrtc::rtp_transceiver::rtp_codec::RTCRtpCodecCapability;
use webrtc::track::track_local::track_local_static_rtp::TrackLocalStaticRTP;
use webrtc::track::track_local::TrackLocalWriter;

/// Create a new video track for a window
pub fn create_window_track(window_id: u32) -> Arc<TrackLocalStaticRTP> {
    Arc::new(TrackLocalStaticRTP::new(
        RTCRtpCodecCapability {
            mime_type: "video/H264".to_string(),
            clock_rate: 90000,
            channels: 0,
            sdp_fmtp_line: "level-asymmetry-allowed=1;packetization-mode=1;profile-level-id=42e01f"
                .to_string(),
            rtcp_feedback: vec![],
        },
        format!("window-{}", window_id),
        "blink-stream".to_string(),
    ))
}

/// Write RTP packet to track
pub async fn write_rtp_to_track(
    track: &TrackLocalStaticRTP,
    payload: &[u8],
    timestamp: u32,
) -> Result<()> {
    use webrtc::rtp::packet::Packet;

    // Create RTP packet
    let packet = Packet {
        header: webrtc::rtp::header::Header {
            version: 2,
            padding: false,
            extension: false,
            marker: true,
            payload_type: 96, // Dynamic payload type for H264
            sequence_number: 0, // Will be set by track
            timestamp,
            ssrc: 0, // Will be set by track
            ..Default::default()
        },
        payload: payload.to_vec().into(),
    };

    track.write_rtp(&packet).await?;
    debug!("Wrote RTP packet with {} bytes", payload.len());

    Ok(())
}
