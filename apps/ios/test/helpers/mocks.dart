import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:blink/models/server.dart';
import 'package:blink/models/remote_window.dart';
import 'package:blink/models/connection_state.dart';
import 'package:blink/services/discovery_service.dart';
import 'package:blink/services/stream_service.dart';
import 'package:blink/services/preferences_service.dart';

/// Mock WebSocket sink that captures sent messages
class MockWebSocketSink implements WebSocketSink {
  final List<String> messages = [];
  bool isClosed = false;

  String get lastMessage => messages.last;
  
  @override
  void add(dynamic data) {
    if (!isClosed) {
      messages.add(data as String);
    }
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future addStream(Stream stream) async {
    await for (final data in stream) {
      add(data);
    }
  }

  @override
  Future close([int? closeCode, String? closeReason]) async {
    isClosed = true;
  }

  @override
  Future get done => Future.value();

  void clear() {
    messages.clear();
  }
}

/// Mock WebSocket channel for testing
class MockWebSocketChannel with StreamChannelMixin implements WebSocketChannel {
  final MockWebSocketSink _sink = MockWebSocketSink();
  final StreamController<dynamic> _streamController = StreamController<dynamic>.broadcast();

  @override
  WebSocketSink get sink => _sink;

  @override
  Stream get stream => _streamController.stream;

  @override
  int? get closeCode => null;

  @override
  String? get closeReason => null;

  @override
  String? get protocol => null;

  @override
  Future<void> get ready => Future.value();

  /// Simulate receiving a message from the server
  void receiveMessage(String message) {
    _streamController.add(message);
  }

  /// Simulate an error
  void receiveError(Object error) {
    _streamController.addError(error);
  }

  /// Close the channel
  void closeChannel() {
    _streamController.close();
    _sink.close();
  }

  /// Get all sent messages
  List<String> get sentMessages => _sink.messages;

  /// Get the last sent message
  String get lastSentMessage => _sink.lastMessage;
}

/// Mock discovery service for testing - extends real DiscoveryService
class MockDiscoveryService extends DiscoveryService {
  final Map<String, StreamServer> _mockServers = {};
  bool _mockIsDiscovering = false;
  String? _mockError;

  @override
  List<StreamServer> get servers => _mockServers.values.toList()
    ..sort((a, b) => (b.lastSeen ?? DateTime(0)).compareTo(a.lastSeen ?? DateTime(0)));

  @override
  bool get isDiscovering => _mockIsDiscovering;

  @override
  String? get error => _mockError;

  @override
  Future<void> startDiscovery() async {
    _mockIsDiscovering = true;
    _mockError = null;
    notifyListeners();
  }

  @override
  Future<void> stopDiscovery() async {
    _mockIsDiscovering = false;
    notifyListeners();
  }

  @override
  void addManualServer(String host, {int port = 8080, String? name}) {
    final server = StreamServer.manual(host: host, port: port, name: name);
    _mockServers[server.id] = server;
    notifyListeners();
  }

  @override
  void removeServer(String serverId) {
    _mockServers.remove(serverId);
    notifyListeners();
  }

  @override
  void refreshServer(String serverId) {
    final server = _mockServers[serverId];
    if (server != null) {
      _mockServers[serverId] = server.copyWith(lastSeen: DateTime.now());
      notifyListeners();
    }
  }

  /// Simulate discovering a server
  void simulateServerFound(StreamServer server) {
    _mockServers[server.id] = server;
    notifyListeners();
  }

  /// Simulate losing a server
  void simulateServerLost(String serverId) {
    _mockServers.remove(serverId);
    notifyListeners();
  }

  /// Simulate an error
  void simulateError(String error) {
    _mockError = error;
    _mockIsDiscovering = false;
    notifyListeners();
  }
}

/// Mock stream service for testing - extends real StreamService
class MockStreamService extends StreamService {
  StreamConnectionState _mockState = StreamConnectionState.initial;
  final Map<String, RTCVideoRenderer> _mockRenderers = {};

  @override
  StreamConnectionState get state => _mockState;

  @override
  Map<String, RTCVideoRenderer> get renderers => Map.unmodifiable(_mockRenderers);

  @override
  Future<void> connect(StreamServer server) async {
    _mockState = _mockState.copyWith(
      phase: ConnectionPhase.connecting,
      server: server,
    );
    notifyListeners();
  }

  @override
  Future<void> disconnect() async {
    _mockState = StreamConnectionState.initial;
    notifyListeners();
  }

  @override
  Future<void> subscribeToWindows(List<int> windowIds) async {
    final subscribedWindows = _mockState.availableWindows
        .where((w) => windowIds.contains(w.id))
        .toList();

    // Build the new state - need to handle null activeWindowId carefully
    final newActiveWindowId = subscribedWindows.isNotEmpty 
        ? subscribedWindows.first.id.toString() 
        : null;
    
    _mockState = StreamConnectionState(
      phase: _mockState.phase,
      server: _mockState.server,
      availableWindows: _mockState.availableWindows,
      subscribedWindows: subscribedWindows,
      activeWindowId: newActiveWindowId,
      error: _mockState.error,
      connectedAt: _mockState.connectedAt,
    );
    notifyListeners();
  }

  @override
  void setActiveWindow(String windowId) {
    _mockState = _mockState.copyWith(activeWindowId: windowId);
    notifyListeners();
  }

  @override
  RTCVideoRenderer? getRenderer(String windowId) => _mockRenderers[windowId];

  /// Simulate state change
  void simulateStateChange(StreamConnectionState newState) {
    _mockState = newState;
    notifyListeners();
  }

  /// Simulate connection success
  void simulateConnected(StreamServer server, {List<RemoteWindow>? availableWindows}) {
    _mockState = StreamConnectionState(
      phase: ConnectionPhase.connected,
      server: server,
      connectedAt: DateTime.now(),
      availableWindows: availableWindows ?? const [],
    );
    notifyListeners();
  }

  /// Simulate connection error
  void simulateError(String error) {
    _mockState = _mockState.copyWith(
      phase: ConnectionPhase.error,
      error: error,
    );
    notifyListeners();
  }

  /// Simulate receiving window list
  void simulateWindowList(List<RemoteWindow> windows) {
    _mockState = _mockState.copyWith(availableWindows: windows);
    notifyListeners();
  }

  /// Simulate a window being closed
  void simulateWindowClosed(int windowId) {
    final updatedWindows = _mockState.subscribedWindows
        .where((w) => w.id != windowId)
        .toList();
    _mockState = _mockState.copyWith(subscribedWindows: updatedWindows);
    notifyListeners();
  }
}

/// Mock preferences service for testing - extends real PreferencesService
class MockPreferencesService extends PreferencesService {
  List<StreamServer> _mockRecentServers = [];
  StreamServer? _mockPreferredServer;
  bool _mockAutoConnect = false;

  @override
  List<StreamServer> get recentServers => List.unmodifiable(_mockRecentServers);
  
  @override
  StreamServer? get preferredServer => _mockPreferredServer;
  
  @override
  bool get autoConnect => _mockAutoConnect;

  @override
  Future<void> init() async {
    // No-op for mock
  }

  @override
  Future<void> addRecentServer(StreamServer server) async {
    _mockRecentServers.removeWhere((s) => s.id == server.id);
    _mockRecentServers.insert(0, server.copyWith(lastSeen: DateTime.now()));
    notifyListeners();
  }

  @override
  Future<void> removeRecentServer(String serverId) async {
    _mockRecentServers.removeWhere((s) => s.id == serverId);
    notifyListeners();
  }

  @override
  Future<void> clearRecentServers() async {
    _mockRecentServers.clear();
    notifyListeners();
  }

  @override
  Future<void> setPreferredServer(StreamServer? server) async {
    _mockPreferredServer = server;
    notifyListeners();
  }

  @override
  Future<void> setAutoConnect(bool value) async {
    _mockAutoConnect = value;
    notifyListeners();
  }
}

/// A testable input service that allows dependency injection of the sink
class TestableInputService extends ChangeNotifier {
  WebSocketSink? _sink;
  bool _isConnected = false;

  bool get isConnected => _isConnected;

  /// Connect with an actual server (production use)
  Future<void> connect(StreamServer server) async {
    throw UnimplementedError('Use connectWithSink for testing');
  }

  /// Connect with a mock sink for testing
  void connectWithSink(WebSocketSink sink) {
    _sink = sink;
    _isConnected = true;
    notifyListeners();
  }

  Future<void> disconnect() async {
    await _sink?.close();
    _sink = null;
    _isConnected = false;
    notifyListeners();
  }

  /// Get the sink for testing verification
  WebSocketSink? get sink => _sink;
}
