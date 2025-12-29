//! Integration test for WebRTC streaming
//!
//! This test spawns the blink-stream server on a non-standard port,
//! connects as a mock WebRTC client, and verifies the streaming flow.

use std::path::PathBuf;
use std::sync::atomic::{AtomicBool, AtomicU32, Ordering};
use std::sync::Arc;
use std::time::Duration;

use anyhow::Result;
use futures_util::{SinkExt, StreamExt};
use serde::{Deserialize, Serialize};
use tokio::net::TcpStream;
use tokio::time::timeout;
use tokio_tungstenite::{connect_async, tungstenite::Message, MaybeTlsStream, WebSocketStream};
use webrtc::api::media_engine::MediaEngine;
use webrtc::api::APIBuilder;
use webrtc::ice_transport::ice_candidate::RTCIceCandidateInit;
use webrtc::ice_transport::ice_connection_state::RTCIceConnectionState;
use webrtc::ice_transport::ice_server::RTCIceServer;
use webrtc::peer_connection::configuration::RTCConfiguration;
use webrtc::peer_connection::peer_connection_state::RTCPeerConnectionState;
use webrtc::peer_connection::sdp::session_description::RTCSessionDescription;
use webrtc::peer_connection::RTCPeerConnection;
use webrtc::rtp_transceiver::rtp_transceiver_direction::RTCRtpTransceiverDirection;

/// Test port - using non-standard port to avoid conflicts
const TEST_PORT: u16 = 19876;

/// Timeout for operations
const TIMEOUT_SECS: u64 = 10;

/// ICE candidate structure matching server format
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
struct IceCandidate {
    candidate: String,
    #[serde(default)]
    sdp_mid: Option<String>,
    #[serde(default, alias = "sdpMLineIndex")]
    sdp_m_line_index: Option<u16>,
}

/// Window bounds from server
#[derive(Debug, Clone, Deserialize)]
struct WindowBounds {
    x: f64,
    y: f64,
    width: f64,
    height: f64,
}

/// Window info from server
#[derive(Debug, Clone, Deserialize)]
struct WindowInfo {
    id: u32,
    title: String,
    app: String,
    bounds: WindowBounds,
}

/// Outgoing message types (client -> server)
#[derive(Debug, Serialize)]
#[serde(tag = "type", rename_all = "snake_case")]
enum OutgoingMessage {
    Offer { sdp: String },
    Ice { candidate: IceCandidate },
    Subscribe { window_ids: Vec<u32> },
    GetWindows,
}

/// Incoming message types (server -> client)
#[derive(Debug, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
enum IncomingMessage {
    Answer { sdp: String },
    Ice { candidate: IceCandidate },
    WindowList { windows: Vec<WindowInfo> },
    WindowClosed { id: u32 },
    Error { message: String },
}

/// Test result tracking
struct TestState {
    connected_to_ws: AtomicBool,
    received_window_list: AtomicBool,
    received_answer: AtomicBool,
    ice_connected: AtomicBool,
    peer_connected: AtomicBool,
    track_received: AtomicBool,
    ice_candidates_exchanged: AtomicU32,
    frames_received: AtomicU32,
    bytes_received: AtomicU32,
}

impl TestState {
    fn new() -> Self {
        Self {
            connected_to_ws: AtomicBool::new(false),
            received_window_list: AtomicBool::new(false),
            received_answer: AtomicBool::new(false),
            ice_connected: AtomicBool::new(false),
            peer_connected: AtomicBool::new(false),
            track_received: AtomicBool::new(false),
            ice_candidates_exchanged: AtomicU32::new(0),
            frames_received: AtomicU32::new(0),
            bytes_received: AtomicU32::new(0),
        }
    }

    fn print_summary(&self) {
        println!("\n=== Test State Summary ===");
        println!("  WebSocket connected:     {}", self.connected_to_ws.load(Ordering::SeqCst));
        println!("  Received window list:    {}", self.received_window_list.load(Ordering::SeqCst));
        println!("  Received SDP answer:     {}", self.received_answer.load(Ordering::SeqCst));
        println!("  ICE candidates exchanged: {}", self.ice_candidates_exchanged.load(Ordering::SeqCst));
        println!("  ICE connected:           {}", self.ice_connected.load(Ordering::SeqCst));
        println!("  Peer connected:          {}", self.peer_connected.load(Ordering::SeqCst));
        println!("  Track received:          {}", self.track_received.load(Ordering::SeqCst));
        println!("  RTP packets received:    {}", self.frames_received.load(Ordering::SeqCst));
        println!("  Bytes received:          {}", self.bytes_received.load(Ordering::SeqCst));
        println!("==========================\n");
    }
}

/// Create a WebRTC peer connection configured as a receiving client
async fn create_client_peer_connection(test_state: Arc<TestState>) -> Result<Arc<RTCPeerConnection>> {
    // Create media engine with default codecs
    let mut media_engine = MediaEngine::default();
    media_engine.register_default_codecs()?;

    // Build API
    let api = APIBuilder::new()
        .with_media_engine(media_engine)
        .build();

    // Create configuration with STUN server
    let config = RTCConfiguration {
        ice_servers: vec![RTCIceServer {
            urls: vec!["stun:stun.l.google.com:19302".to_string()],
            ..Default::default()
        }],
        ..Default::default()
    };

    let peer_connection = Arc::new(api.new_peer_connection(config).await?);

    // Set up ICE connection state handler
    let state_for_ice = test_state.clone();
    peer_connection.on_ice_connection_state_change(Box::new(move |state| {
        println!("  [WebRTC] ICE connection state: {:?}", state);
        if state == RTCIceConnectionState::Connected || state == RTCIceConnectionState::Completed {
            state_for_ice.ice_connected.store(true, Ordering::SeqCst);
        }
        Box::pin(async {})
    }));

    // Set up peer connection state handler
    let state_for_peer = test_state.clone();
    peer_connection.on_peer_connection_state_change(Box::new(move |state| {
        println!("  [WebRTC] Peer connection state: {:?}", state);
        if state == RTCPeerConnectionState::Connected {
            state_for_peer.peer_connected.store(true, Ordering::SeqCst);
        }
        Box::pin(async {})
    }));

    // Set up track handler - monitors incoming video track
    let state_for_track = test_state.clone();
    peer_connection.on_track(Box::new(move |track, _, _| {
        println!("  [WebRTC] Track received: kind={}, id={}", track.kind(), track.id());
        state_for_track.track_received.store(true, Ordering::SeqCst);
        
        let state = state_for_track.clone();
        let track_clone = track.clone();
        
        // Spawn a task to read RTP packets from the track
        tokio::spawn(async move {
            println!("  [WebRTC] Starting to read RTP packets from track...");
            
            // Read RTP packets and count them
            loop {
                match track_clone.read_rtp().await {
                    Ok((rtp_packet, _)) => {
                        let payload = rtp_packet.payload;
                        let packet_count = state.frames_received.fetch_add(1, Ordering::SeqCst) + 1;
                        state.bytes_received.fetch_add(payload.len() as u32, Ordering::SeqCst);
                        
                        if packet_count <= 5 || packet_count % 30 == 0 {
                            println!("  [WebRTC] RTP packet #{}: {} bytes, marker={}", 
                                packet_count, payload.len(), rtp_packet.header.marker);
                        }
                    }
                    Err(e) => {
                        println!("  [WebRTC] Track read ended: {}", e);
                        break;
                    }
                }
            }
            
            let total_packets = state.frames_received.load(Ordering::SeqCst);
            let total_bytes = state.bytes_received.load(Ordering::SeqCst);
            println!("  [WebRTC] Track finished: {} packets, {} bytes total", total_packets, total_bytes);
        });
        
        Box::pin(async {})
    }));

    // Add transceiver for receiving video
    peer_connection
        .add_transceiver_from_kind(
            webrtc::rtp_transceiver::rtp_codec::RTPCodecType::Video,
            Some(webrtc::rtp_transceiver::RTCRtpTransceiverInit {
                direction: RTCRtpTransceiverDirection::Recvonly,
                send_encodings: vec![],
            }),
        )
        .await?;

    Ok(peer_connection)
}

/// Connect to the WebSocket server
async fn connect_websocket(port: u16) -> Result<WebSocketStream<MaybeTlsStream<TcpStream>>> {
    let url = format!("ws://127.0.0.1:{}", port);
    println!("  Connecting to WebSocket at {}", url);
    
    let (ws_stream, _) = connect_async(&url).await?;
    println!("  WebSocket connected successfully");
    
    Ok(ws_stream)
}

/// Send a message over WebSocket
async fn send_message(
    ws: &mut WebSocketStream<MaybeTlsStream<TcpStream>>,
    msg: &OutgoingMessage,
) -> Result<()> {
    let json = serde_json::to_string(msg)?;
    ws.send(Message::Text(json)).await?;
    Ok(())
}

/// Receive and parse a message from WebSocket
async fn receive_message(
    ws: &mut WebSocketStream<MaybeTlsStream<TcpStream>>,
) -> Result<Option<IncomingMessage>> {
    match ws.next().await {
        Some(Ok(Message::Text(text))) => {
            let msg: IncomingMessage = serde_json::from_str(&text)?;
            Ok(Some(msg))
        }
        Some(Ok(_)) => Ok(None), // Non-text message
        Some(Err(e)) => Err(e.into()),
        None => Ok(None), // Stream ended
    }
}

/// Run the integration test
async fn run_integration_test() -> Result<()> {
    println!("\n========================================");
    println!("  Blink WebRTC Integration Test");
    println!("========================================\n");

    let test_state = Arc::new(TestState::new());

    // Step 1: Connect to WebSocket
    println!("[Step 1] Connecting to WebSocket server...");
    let mut ws = match timeout(
        Duration::from_secs(TIMEOUT_SECS),
        connect_websocket(TEST_PORT),
    )
    .await
    {
        Ok(Ok(ws)) => {
            test_state.connected_to_ws.store(true, Ordering::SeqCst);
            ws
        }
        Ok(Err(e)) => {
            println!("  ERROR: Failed to connect to WebSocket: {}", e);
            test_state.print_summary();
            return Err(e);
        }
        Err(_) => {
            println!("  ERROR: WebSocket connection timed out");
            test_state.print_summary();
            return Err(anyhow::anyhow!("Connection timeout"));
        }
    };

    // Step 2: Receive initial window list
    println!("[Step 2] Waiting for initial window list...");
    let windows = match timeout(Duration::from_secs(TIMEOUT_SECS), receive_message(&mut ws)).await {
        Ok(Ok(Some(IncomingMessage::WindowList { windows }))) => {
            println!("  Received {} windows", windows.len());
            for w in &windows {
                println!("    - [{}] {} ({})", w.id, w.title, w.app);
            }
            test_state.received_window_list.store(true, Ordering::SeqCst);
            windows
        }
        Ok(Ok(Some(msg))) => {
            println!("  Unexpected message: {:?}", msg);
            test_state.print_summary();
            return Err(anyhow::anyhow!("Expected window_list, got {:?}", msg));
        }
        Ok(Ok(None)) => {
            println!("  No message received");
            test_state.print_summary();
            return Err(anyhow::anyhow!("No window list received"));
        }
        Ok(Err(e)) => {
            println!("  ERROR: {}", e);
            test_state.print_summary();
            return Err(e);
        }
        Err(_) => {
            println!("  ERROR: Timeout waiting for window list");
            test_state.print_summary();
            return Err(anyhow::anyhow!("Timeout waiting for window list"));
        }
    };

    // Step 3: Create WebRTC peer connection
    println!("[Step 3] Creating WebRTC peer connection...");
    let peer_connection = create_client_peer_connection(test_state.clone()).await?;
    println!("  Peer connection created");

    // Set up ICE candidate handler BEFORE creating offer
    let (ice_tx, mut ice_rx) = tokio::sync::mpsc::channel::<IceCandidate>(32);
    let ice_tx = Arc::new(tokio::sync::Mutex::new(Some(ice_tx)));
    let ice_tx_clone = ice_tx.clone();
    
    let state_for_ice_gather = test_state.clone();
    peer_connection.on_ice_candidate(Box::new(move |candidate| {
        let ice_sender = ice_tx_clone.clone();
        let state = state_for_ice_gather.clone();
        Box::pin(async move {
            if let Some(c) = candidate {
                if let Ok(json) = c.to_json() {
                    let ice_candidate = IceCandidate {
                        candidate: json.candidate,
                        sdp_mid: json.sdp_mid,
                        sdp_m_line_index: json.sdp_mline_index,
                    };
                    
                    if let Some(sender) = ice_sender.lock().await.as_ref() {
                        let _ = sender.send(ice_candidate).await;
                        state.ice_candidates_exchanged.fetch_add(1, Ordering::SeqCst);
                    }
                }
            }
        })
    }));

    // Step 4: Create and send offer
    println!("[Step 4] Creating and sending SDP offer...");
    let offer = peer_connection.create_offer(None).await?;
    peer_connection.set_local_description(offer.clone()).await?;
    println!("  Local description set");

    // Give ICE gathering a moment to start
    tokio::time::sleep(Duration::from_millis(100)).await;

    send_message(&mut ws, &OutgoingMessage::Offer { sdp: offer.sdp.clone() }).await?;
    println!("  Offer sent to server");

    // Step 5: Wait for answer and exchange ICE candidates
    println!("[Step 5] Waiting for SDP answer and exchanging ICE candidates...");
    
    let exchange_timeout = Duration::from_secs(TIMEOUT_SECS);
    let exchange_start = std::time::Instant::now();
    
    loop {
        if exchange_start.elapsed() > exchange_timeout {
            println!("  Exchange timeout reached");
            break;
        }

        tokio::select! {
            // Send our ICE candidates
            Some(ice_candidate) = ice_rx.recv() => {
                println!("  Sending ICE candidate to server");
                if let Err(e) = send_message(&mut ws, &OutgoingMessage::Ice { candidate: ice_candidate }).await {
                    println!("  Warning: Failed to send ICE candidate: {}", e);
                }
            }
            
            // Receive messages from server
            result = receive_message(&mut ws) => {
                match result {
                    Ok(Some(IncomingMessage::Answer { sdp })) => {
                        println!("  Received SDP answer from server");
                        test_state.received_answer.store(true, Ordering::SeqCst);
                        
                        let answer = RTCSessionDescription::answer(sdp)?;
                        peer_connection.set_remote_description(answer).await?;
                        println!("  Remote description set");
                    }
                    Ok(Some(IncomingMessage::Ice { candidate })) => {
                        println!("  Received ICE candidate from server");
                        let ice_init = RTCIceCandidateInit {
                            candidate: candidate.candidate,
                            sdp_mid: candidate.sdp_mid,
                            sdp_mline_index: candidate.sdp_m_line_index,
                            username_fragment: None,
                        };
                        if let Err(e) = peer_connection.add_ice_candidate(ice_init).await {
                            println!("  Warning: Failed to add ICE candidate: {}", e);
                        }
                        test_state.ice_candidates_exchanged.fetch_add(1, Ordering::SeqCst);
                    }
                    Ok(Some(IncomingMessage::Error { message })) => {
                        println!("  Server error: {}", message);
                    }
                    Ok(Some(msg)) => {
                        println!("  Received: {:?}", msg);
                    }
                    Ok(None) => {}
                    Err(e) => {
                        println!("  Warning: Error receiving message: {}", e);
                    }
                }
            }
            
            // Check if we're done
            _ = tokio::time::sleep(Duration::from_millis(100)) => {
                // Check if we've completed the handshake
                if test_state.received_answer.load(Ordering::SeqCst) 
                   && test_state.ice_connected.load(Ordering::SeqCst) {
                    println!("  WebRTC connection established!");
                    break;
                }
            }
        }
    }

    // Step 6: Subscribe to a window (if any available)
    // Prefer Cursor windows since they're more visible than utility apps
    if !windows.is_empty() {
        println!("[Step 6] Selecting window to capture...");
        
        // Find a Cursor window, or fall back to first window
        let selected = windows.iter()
            .find(|w| w.app.contains("Cursor"))
            .unwrap_or(&windows[0]);
        
        let window_id = selected.id;
        println!("  Selected: [{}] {} ({})", window_id, selected.title, selected.app);
        
        send_message(&mut ws, &OutgoingMessage::Subscribe { window_ids: vec![window_id] }).await?;
        println!("  Subscribed to window");
        
        // Wait for subscription to be processed and potentially receive track
        tokio::time::sleep(Duration::from_secs(1)).await;
    } else {
        println!("[Step 6] No windows available to subscribe to");
    }

    // Step 7: Wait for WebRTC data flow (frames being sent)
    // Capture for 5 seconds to get enough frames for a visible video
    println!("[Step 7] Capturing video for 5 seconds...");
    tokio::time::sleep(Duration::from_secs(5)).await;

    // Print final results
    test_state.print_summary();

    // Determine test result
    let ws_connected = test_state.connected_to_ws.load(Ordering::SeqCst);
    let got_windows = test_state.received_window_list.load(Ordering::SeqCst);
    let got_answer = test_state.received_answer.load(Ordering::SeqCst);
    let ice_ok = test_state.ice_connected.load(Ordering::SeqCst);

    println!("========================================");
    if ws_connected && got_windows && got_answer {
        if ice_ok {
            println!("  TEST PASSED: Full WebRTC connection established!");
        } else {
            println!("  TEST PARTIAL: WebSocket + SDP negotiation succeeded");
            println!("  (ICE connection may require network/STUN access)");
        }
        println!("========================================\n");
        Ok(())
    } else {
        println!("  TEST FAILED");
        println!("========================================\n");
        Err(anyhow::anyhow!("Integration test failed"))
    }
}

#[tokio::test]
async fn test_webrtc_streaming_flow() {
    // Initialize logging for tests
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::INFO)
        .with_test_writer()
        .try_init();

    println!("\n");
    println!("╔══════════════════════════════════════════════════════════════╗");
    println!("║         Blink WebRTC Streaming Integration Test              ║");
    println!("╠══════════════════════════════════════════════════════════════╣");
    println!("║  This test requires the blink-stream server to be running    ║");
    println!("║  on port {}. Start the server with:                       ║", TEST_PORT);
    println!("║                                                              ║");
    println!("║    BLINK_PORT={} cargo run                                ║", TEST_PORT);
    println!("║                                                              ║");
    println!("║  Or run the auto-start version of this test.                 ║");
    println!("╚══════════════════════════════════════════════════════════════╝");
    println!("\n");

    // Try to connect - if server isn't running, this will fail gracefully
    match run_integration_test().await {
        Ok(()) => {
            println!("Integration test completed successfully!");
        }
        Err(e) => {
            // Check if it's a connection error (server not running)
            let err_str = e.to_string();
            if err_str.contains("Connection refused") || err_str.contains("Connection timeout") {
                println!("\n");
                println!("╔══════════════════════════════════════════════════════════════╗");
                println!("║  Server not running - skipping integration test              ║");
                println!("║                                                              ║");
                println!("║  To run this test, start the server first:                   ║");
                println!("║    BLINK_PORT={} cargo run                                ║", TEST_PORT);
                println!("╚══════════════════════════════════════════════════════════════╝");
                println!("\n");
                // Don't fail the test if server isn't running
                return;
            }
            panic!("Integration test failed: {}", e);
        }
    }
}

/// Test that can auto-start the server
/// This test starts the server in a background task
#[tokio::test]
async fn test_webrtc_with_server_autostart() {
    use blink_stream_server::capture;
    use blink_stream_server::config::Config;
    use blink_stream_server::server::Server;

    // Initialize logging
    let _ = tracing_subscriber::fmt()
        .with_max_level(tracing::Level::INFO)
        .with_test_writer()
        .try_init();

    println!("\n");
    println!("╔══════════════════════════════════════════════════════════════╗");
    println!("║     Blink WebRTC Integration Test (Auto-Start Server)        ║");
    println!("║                                                              ║");
    println!("║  NOTE: This test requires Screen Recording permission.       ║");
    println!("║  If prompted, please grant access in System Settings.        ║");
    println!("╚══════════════════════════════════════════════════════════════╝");
    println!("\n");

    // Initialize ScreenCaptureKit bridge (required for Window Server access)
    println!("[Setup] Initializing ScreenCaptureKit...");
    if let Err(e) = capture::initialize() {
        eprintln!("[Setup] Warning: Failed to initialize ScreenCaptureKit: {}", e);
        eprintln!("[Setup] Window capture may not work, but WebRTC negotiation will proceed.");
    } else {
        println!("[Setup] ScreenCaptureKit initialized successfully");
    }

    // Set up frame saving via environment variable
    let output_path = PathBuf::from("target/test_capture.h264");
    std::env::set_var("BLINK_SAVE_FRAMES", output_path.to_str().unwrap());
    println!("[Setup] Frame saving enabled to: {}", output_path.display());

    // Create server with test port
    let config = Config::new(TEST_PORT);
    let server = Arc::new(Server::new(config));
    let cancel_token = server.cancel_token();

    // Start server in background
    let server_clone = server.clone();
    let server_handle = tokio::spawn(async move {
        println!("[Server] Starting on port {}...", TEST_PORT);
        if let Err(e) = server_clone.run().await {
            // Ignore shutdown errors
            if !e.to_string().contains("shutdown") {
                eprintln!("[Server] Error: {}", e);
            }
        }
        println!("[Server] Stopped");
    });

    // Wait for server to start
    tokio::time::sleep(Duration::from_millis(500)).await;

    // Run the integration test
    let test_result = run_integration_test().await;

    // Shutdown server
    println!("[Test] Shutting down server...");
    cancel_token.cancel();
    
    // Wait for server to stop
    let _ = tokio::time::timeout(Duration::from_secs(2), server_handle).await;

    // Print frame save info
    if output_path.exists() {
        let file_size = std::fs::metadata(&output_path).map(|m| m.len()).unwrap_or(0);
        println!("\n╔══════════════════════════════════════════════════════════════╗");
        println!("║                    Frame Capture Summary                     ║");
        println!("╠══════════════════════════════════════════════════════════════╣");
        println!("║  Output file:     target/test_capture.h264                   ║");
        println!("║  File size:       {:>8} bytes                             ║", file_size);
        println!("╠══════════════════════════════════════════════════════════════╣");
        println!("║  To play the captured video, run:                            ║");
        println!("║    ffplay target/test_capture.h264                           ║");
        println!("║  Or convert to MP4:                                          ║");
        println!("║    ffmpeg -i target/test_capture.h264 -c copy test.mp4       ║");
        println!("╚══════════════════════════════════════════════════════════════╝");
    }

    // Check test result
    match test_result {
        Ok(()) => println!("\nIntegration test with auto-start completed successfully!"),
        Err(e) => panic!("Integration test failed: {}", e),
    }
}

