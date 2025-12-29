//! Video track management for WebRTC streaming
//! 
//! Implements H.264 RTP packetization according to RFC 6184

use std::sync::Arc;
use std::sync::atomic::{AtomicU16, Ordering};

use anyhow::Result;
use tracing::{debug, trace};
use webrtc::rtp_transceiver::rtp_codec::RTCRtpCodecCapability;
use webrtc::track::track_local::track_local_static_rtp::TrackLocalStaticRTP;
use webrtc::track::track_local::TrackLocalWriter;
use webrtc::rtp::packet::Packet;
use webrtc::rtp::header::Header;

/// Maximum RTP payload size (MTU - IP/UDP/RTP headers)
const MAX_RTP_PAYLOAD_SIZE: usize = 1200;

/// H.264 NAL unit start code
const NAL_START_CODE: [u8; 4] = [0x00, 0x00, 0x00, 0x01];
const NAL_START_CODE_3: [u8; 3] = [0x00, 0x00, 0x01];

/// H.264 NAL unit types
const NAL_TYPE_MASK: u8 = 0x1F;
const NAL_TYPE_FU_A: u8 = 28;

/// RTP packetizer for H.264 video
pub struct H264RtpPacketizer {
    sequence_number: AtomicU16,
}

impl H264RtpPacketizer {
    pub fn new() -> Self {
        Self {
            sequence_number: AtomicU16::new(0),
        }
    }
    
    fn next_seq(&self) -> u16 {
        self.sequence_number.fetch_add(1, Ordering::SeqCst)
    }
    
    /// Packetize H.264 Annex-B data into RTP packets and write to track
    pub async fn packetize_and_send(
        &self,
        track: &TrackLocalStaticRTP,
        annex_b_data: &[u8],
        timestamp: u32,
    ) -> Result<()> {
        // Parse NAL units from Annex-B format
        let nal_units = parse_annex_b(annex_b_data);
        
        if nal_units.is_empty() {
            return Ok(());
        }
        
        let total_nals = nal_units.len();
        
        for (idx, nal) in nal_units.iter().enumerate() {
            let is_last_nal = idx == total_nals - 1;
            self.send_nal_unit(track, nal, timestamp, is_last_nal).await?;
        }
        
        trace!("Sent {} NAL units, timestamp={}", total_nals, timestamp);
        Ok(())
    }
    
    /// Send a single NAL unit, fragmenting if necessary
    async fn send_nal_unit(
        &self,
        track: &TrackLocalStaticRTP,
        nal: &[u8],
        timestamp: u32,
        is_last_nal: bool,
    ) -> Result<()> {
        if nal.is_empty() {
            return Ok(());
        }
        
        if nal.len() <= MAX_RTP_PAYLOAD_SIZE {
            // Single NAL unit packet - fits in one RTP packet
            let marker = is_last_nal; // Marker bit indicates end of access unit
            self.send_rtp_packet(track, nal, timestamp, marker).await?;
        } else {
            // FU-A fragmentation required
            self.send_fragmented_nal(track, nal, timestamp, is_last_nal).await?;
        }
        
        Ok(())
    }
    
    /// Send NAL unit using FU-A fragmentation
    async fn send_fragmented_nal(
        &self,
        track: &TrackLocalStaticRTP,
        nal: &[u8],
        timestamp: u32,
        is_last_nal: bool,
    ) -> Result<()> {
        let nal_header = nal[0];
        let nal_type = nal_header & NAL_TYPE_MASK;
        let nri = nal_header & 0x60; // NAL ref idc
        
        // FU indicator: same NRI, type = 28 (FU-A)
        let fu_indicator = nri | NAL_TYPE_FU_A;
        
        // Payload starts after NAL header
        let payload = &nal[1..];
        let max_fragment_size = MAX_RTP_PAYLOAD_SIZE - 2; // -2 for FU indicator + FU header
        
        let mut offset = 0;
        let mut is_first = true;
        
        while offset < payload.len() {
            let remaining = payload.len() - offset;
            let fragment_size = remaining.min(max_fragment_size);
            let is_last = offset + fragment_size >= payload.len();
            
            // FU header: S=start, E=end, R=0, Type=nal_type
            let fu_header = if is_first {
                0x80 | nal_type // Start bit set
            } else if is_last {
                0x40 | nal_type // End bit set
            } else {
                nal_type // Neither start nor end
            };
            
            // Build FU-A packet
            let mut fu_packet = Vec::with_capacity(2 + fragment_size);
            fu_packet.push(fu_indicator);
            fu_packet.push(fu_header);
            fu_packet.extend_from_slice(&payload[offset..offset + fragment_size]);
            
            // Marker bit only on last fragment of last NAL
            let marker = is_last && is_last_nal;
            
            self.send_rtp_packet(track, &fu_packet, timestamp, marker).await?;
            
            offset += fragment_size;
            is_first = false;
        }
        
        Ok(())
    }
    
    /// Send a single RTP packet
    async fn send_rtp_packet(
        &self,
        track: &TrackLocalStaticRTP,
        payload: &[u8],
        timestamp: u32,
        marker: bool,
    ) -> Result<()> {
        let packet = Packet {
            header: Header {
                version: 2,
                padding: false,
                extension: false,
                marker,
                payload_type: 96, // Dynamic payload type for H264
                sequence_number: self.next_seq(),
                timestamp,
                ssrc: 0, // Will be set by track
                ..Default::default()
            },
            payload: payload.to_vec().into(),
        };
        
        track.write_rtp(&packet).await?;
        Ok(())
    }
}

impl Default for H264RtpPacketizer {
    fn default() -> Self {
        Self::new()
    }
}

/// Parse Annex-B formatted H.264 data into individual NAL units
fn parse_annex_b(data: &[u8]) -> Vec<&[u8]> {
    let mut nal_units = Vec::new();
    let mut i = 0;
    
    // Find first start code
    while i < data.len() {
        if let Some(start) = find_start_code(data, i) {
            let nal_start = if data[start..].starts_with(&NAL_START_CODE) {
                start + 4
            } else {
                start + 3
            };
            
            // Find next start code or end of data
            let nal_end = if let Some(next) = find_start_code(data, nal_start) {
                next
            } else {
                data.len()
            };
            
            if nal_start < nal_end {
                nal_units.push(&data[nal_start..nal_end]);
            }
            
            i = nal_end;
        } else {
            break;
        }
    }
    
    nal_units
}

/// Find the next Annex-B start code (0x000001 or 0x00000001)
fn find_start_code(data: &[u8], start: usize) -> Option<usize> {
    if start + 3 > data.len() {
        return None;
    }
    
    for i in start..data.len() - 2 {
        if data[i] == 0 && data[i + 1] == 0 {
            if data[i + 2] == 1 {
                return Some(i);
            } else if i + 3 < data.len() && data[i + 2] == 0 && data[i + 3] == 1 {
                return Some(i);
            }
        }
    }
    
    None
}

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

/// Write RTP packet to track (legacy function for compatibility)
pub async fn write_rtp_to_track(
    track: &TrackLocalStaticRTP,
    payload: &[u8],
    timestamp: u32,
) -> Result<()> {
    let packet = Packet {
        header: Header {
            version: 2,
            padding: false,
            extension: false,
            marker: true,
            payload_type: 96,
            sequence_number: 0,
            timestamp,
            ssrc: 0,
            ..Default::default()
        },
        payload: payload.to_vec().into(),
    };

    track.write_rtp(&packet).await?;
    debug!("Wrote RTP packet with {} bytes", payload.len());

    Ok(())
}
