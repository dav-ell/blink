import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/server.dart';
import '../models/remote_window.dart';
import '../models/connection_state.dart';

/// Service for managing WebRTC streaming connection
class StreamService extends ChangeNotifier {
  StreamServer? _server;
  WebSocketChannel? _signalingChannel;
  WebSocketChannel? _windowsChannel;
  RTCPeerConnection? _peerConnection;
  
  StreamConnectionState _state = StreamConnectionState.initial;
  final Map<String, RTCVideoRenderer> _renderers = {};
  final Map<String, MediaStream> _streams = {};
  
  StreamSubscription? _signalingSubscription;
  StreamSubscription? _windowsSubscription;
  
  /// Track count for testing - increments when video tracks are received
  int _receivedTrackCount = 0;

  /// Current connection state
  StreamConnectionState get state => _state;

  /// Video renderers for each window (keyed by window ID)
  Map<String, RTCVideoRenderer> get renderers => Map.unmodifiable(_renderers);

  /// Number of video tracks received (for testing verification)
  int get receivedTrackCount => _receivedTrackCount;
  
  /// Whether any video tracks have been received
  bool get hasReceivedVideo => _receivedTrackCount > 0;

  /// Connect to a stream server
  Future<void> connect(StreamServer server) async {
    if (_state.isConnecting || _state.isConnected) {
      await disconnect();
    }

    _server = server;
    _updateState(_state.copyWith(
      phase: ConnectionPhase.connecting,
      server: server,
      clearError: true,
    ));

    try {
      // Connect to signaling WebSocket
      _signalingChannel = WebSocketChannel.connect(Uri.parse(server.signalingUrl));
      
      _signalingSubscription = _signalingChannel!.stream.listen(
        _handleSignalingMessage,
        onError: (error) => _handleError('Signaling error: $error'),
        onDone: () => _handleDisconnect('Signaling connection closed'),
      );

      // Connect to windows WebSocket
      _windowsChannel = WebSocketChannel.connect(Uri.parse(server.windowsUrl));
      
      _windowsSubscription = _windowsChannel!.stream.listen(
        _handleWindowsMessage,
        onError: (error) => _handleError('Windows channel error: $error'),
      );

      // Create peer connection
      await _createPeerConnection();

      _updateState(_state.copyWith(
        phase: ConnectionPhase.negotiating,
      ));

      // Send offer to server
      await _createAndSendOffer();

    } catch (e) {
      _handleError('Connection failed: $e');
    }
  }

  /// Disconnect from the server
  Future<void> disconnect() async {
    _signalingSubscription?.cancel();
    _windowsSubscription?.cancel();
    
    await _signalingChannel?.sink.close();
    await _windowsChannel?.sink.close();
    
    await _peerConnection?.close();
    
    for (final renderer in _renderers.values) {
      await renderer.dispose();
    }
    
    _signalingChannel = null;
    _windowsChannel = null;
    _peerConnection = null;
    _renderers.clear();
    _streams.clear();
    _server = null;
    _receivedTrackCount = 0;

    _updateState(StreamConnectionState.initial);
  }

  /// Subscribe to specific windows
  Future<void> subscribeToWindows(List<int> windowIds) async {
    if (_windowsChannel == null) return;

    final message = jsonEncode({
      'type': 'subscribe',
      'window_ids': windowIds,
    });
    
    _windowsChannel!.sink.add(message);

    // Update subscribed windows based on available windows
    final subscribedWindows = _state.availableWindows
        .where((w) => windowIds.contains(w.id))
        .toList();

    _updateState(_state.copyWith(
      subscribedWindows: subscribedWindows,
      activeWindowId: subscribedWindows.isNotEmpty 
          ? subscribedWindows.first.id.toString() 
          : null,
    ));
  }

  /// Switch to a different active window
  void setActiveWindow(String windowId) {
    _updateState(_state.copyWith(activeWindowId: windowId));
  }

  /// Get renderer for a specific window
  RTCVideoRenderer? getRenderer(String windowId) {
    return _renderers[windowId];
  }

  Future<void> _createPeerConnection() async {
    final configuration = <String, dynamic>{
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ],
      'sdpSemantics': 'unified-plan',
    };

    _peerConnection = await createPeerConnection(configuration);

    _peerConnection!.onIceCandidate = (candidate) {
      if (candidate.candidate != null) {
        _sendSignaling({
          'type': 'ice',
          'candidate': candidate.toMap(),
        });
      }
    };

    _peerConnection!.onTrack = (event) {
      _handleTrack(event);
    };

    _peerConnection!.onConnectionState = (state) {
      debugPrint('Connection state: $state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _updateState(_state.copyWith(
          phase: ConnectionPhase.connected,
          connectedAt: DateTime.now(),
        ));
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
                 state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        _handleDisconnect('Peer connection $state');
      }
    };
  }

  Future<void> _createAndSendOffer() async {
    if (_peerConnection == null) return;

    // Add transceivers for receiving video
    await _peerConnection!.addTransceiver(
      kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
      init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
    );

    final offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);

    _sendSignaling({
      'type': 'offer',
      'sdp': offer.sdp,
    });
  }

  void _sendSignaling(Map<String, dynamic> message) {
    _signalingChannel?.sink.add(jsonEncode(message));
  }

  // #region agent log
  void _debugLog(String hypothesisId, String location, String message, Map<String, dynamic> data) {
    final payload = {
      'hypothesisId': hypothesisId,
      'location': location,
      'message': message,
      'data': data,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'sessionId': 'debug-session',
    };
    // Fire and forget - use unawaited async to avoid catchError type issues
    () async {
      try {
        final uri = Uri.parse('http://192.168.1.113:7258/ingest/606a0860-3796-4c1f-8a76-f60d9d7088f7');
        final client = HttpClient();
        final req = await client.postUrl(uri);
        req.headers.contentType = ContentType.json;
        req.write(jsonEncode(payload));
        await req.close();
      } catch (_) {}
    }();
  }
  // #endregion

  void _handleSignalingMessage(dynamic data) async {
    try {
      final message = jsonDecode(data as String) as Map<String, dynamic>;
      final type = message['type'] as String?;
      
      // #region agent log
      debugPrint('[DEBUG] Signaling message received: type=$type');
      // #endregion

      switch (type) {
        case 'answer':
          final answer = RTCSessionDescription(
            message['sdp'] as String,
            'answer',
          );
          // #region agent log
          _debugLog('C', 'stream_service:answer', 'Setting remote description (answer SDP)', {
            'sdp_length': answer.sdp?.length ?? 0,
            'has_video': answer.sdp?.contains('m=video') ?? false,
          });
          // #endregion
          await _peerConnection?.setRemoteDescription(answer);
          break;

        case 'offer':
          // Server-initiated renegotiation (new tracks added)
          debugPrint('[DEBUG] Received OFFER from server for renegotiation');
          final offer = RTCSessionDescription(
            message['sdp'] as String,
            'offer',
          );
          // #region agent log
          debugPrint('[DEBUG] Offer SDP length: ${offer.sdp?.length}, has_video: ${offer.sdp?.contains('m=video')}');
          _debugLog('FIX', 'stream_service:offer', 'Received renegotiation offer from server', {
            'sdp_length': offer.sdp?.length ?? 0,
            'has_video': offer.sdp?.contains('m=video') ?? false,
          });
          // #endregion
          
          await _peerConnection?.setRemoteDescription(offer);
          debugPrint('[DEBUG] Set remote description with offer');
          final answer = await _peerConnection?.createAnswer();
          if (answer != null) {
            await _peerConnection?.setLocalDescription(answer);
            _sendSignaling({
              'type': 'answer',
              'sdp': answer.sdp,
            });
            debugPrint('[DEBUG] Sent renegotiation answer back to server');
            // #region agent log
            _debugLog('FIX', 'stream_service:offer', 'Sent renegotiation answer to server', {
              'sdp_length': answer.sdp?.length ?? 0,
            });
            // #endregion
          }
          break;

        case 'ice':
          final candidateMap = message['candidate'] as Map<String, dynamic>;
          final candidate = RTCIceCandidate(
            candidateMap['candidate'] as String?,
            candidateMap['sdpMid'] as String?,
            candidateMap['sdpMLineIndex'] as int?,
          );
          await _peerConnection?.addCandidate(candidate);
          break;

        case 'error':
          _handleError(message['message'] as String? ?? 'Unknown error');
          break;
      }
    } catch (e) {
      debugPrint('Error handling signaling message: $e');
    }
  }

  void _handleWindowsMessage(dynamic data) {
    try {
      final message = jsonDecode(data as String) as Map<String, dynamic>;
      final type = message['type'] as String?;
      
      // #region agent log
      debugPrint('[DEBUG] Windows channel message: type=$type');
      // #endregion

      switch (type) {
        case 'window_list':
          final windowsList = (message['windows'] as List)
              .map((w) => RemoteWindow.fromJson(w as Map<String, dynamic>))
              .toList();
          _updateState(_state.copyWith(availableWindows: windowsList));
          break;

        case 'window_closed':
          final windowId = message['id'] as int;
          final updatedWindows = _state.subscribedWindows
              .where((w) => w.id != windowId)
              .toList();
          _updateState(_state.copyWith(subscribedWindows: updatedWindows));
          
          // Clean up renderer for closed window
          final renderer = _renderers.remove(windowId.toString());
          renderer?.dispose();
          break;
          
        // Handle signaling messages that may come on windows channel (renegotiation)
        case 'offer':
        case 'answer':
        case 'ice':
          debugPrint('[DEBUG] Forwarding signaling message from windows channel: $type');
          _handleSignalingMessage(data);
          break;
      }
    } catch (e) {
      debugPrint('Error handling windows message: $e');
    }
  }

  void _handleTrack(RTCTrackEvent event) async {
    // #region agent log
    debugPrint('[DEBUG] onTrack fired! kind=${event.track.kind}, id=${event.track.id}, streams=${event.streams.length}');
    _debugLog('D', 'stream_service:onTrack', 'onTrack callback fired', {
      'track_kind': event.track.kind,
      'track_id': event.track.id,
      'streams_count': event.streams.length,
      'has_transceiver': event.transceiver != null,
      'mid': event.transceiver?.mid,
    });
    // #endregion

    if (event.track.kind != 'video') return;

    final stream = event.streams.isNotEmpty ? event.streams[0] : null;
    if (stream == null) {
      // #region agent log
      _debugLog('D', 'stream_service:onTrack', 'No stream in track event', {
        'track_id': event.track.id,
      });
      // #endregion
      return;
    }

    // Extract window ID from track ID (format: "window-{id}") or fall back to mid/stream.id
    String windowId;
    final trackId = event.track.id ?? '';
    if (trackId.startsWith('window-')) {
      windowId = trackId.substring(7); // Remove "window-" prefix
    } else {
      windowId = event.transceiver?.mid ?? stream.id;
    }
    
    debugPrint('[DEBUG] Extracted windowId: $windowId from trackId: $trackId');

    // Increment track count for testing
    _receivedTrackCount++;

    // #region agent log
    _debugLog('D', 'stream_service:onTrack', 'Creating renderer for video track', {
      'window_id': windowId,
      'stream_id': stream.id,
      'track_count': _receivedTrackCount,
    });
    // #endregion

    // Create renderer for this track
    final renderer = RTCVideoRenderer();
    await renderer.initialize();
    renderer.srcObject = stream;

    _renderers[windowId] = renderer;
    _streams[windowId] = stream;

    notifyListeners();
  }

  void _handleError(String error) {
    debugPrint('Stream error: $error');
    _updateState(_state.copyWith(
      phase: ConnectionPhase.error,
      error: error,
    ));
  }

  void _handleDisconnect(String reason) {
    debugPrint('Disconnected: $reason');
    
    if (_state.isConnected) {
      // Try to reconnect
      _updateState(_state.copyWith(
        phase: ConnectionPhase.reconnecting,
      ));
      
      // Attempt reconnection after delay
      Future.delayed(const Duration(seconds: 2), () {
        if (_server != null && _state.phase == ConnectionPhase.reconnecting) {
          connect(_server!);
        }
      });
    } else {
      _updateState(_state.copyWith(
        phase: ConnectionPhase.disconnected,
        clearServer: true,
      ));
    }
  }

  void _updateState(StreamConnectionState newState) {
    _state = newState;
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}

