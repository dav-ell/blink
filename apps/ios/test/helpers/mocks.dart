import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:blink/models/server.dart';
import 'package:blink/models/remote_window.dart';
import 'package:blink/models/connection_state.dart';

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

/// Mock discovery service for testing
class MockDiscoveryService extends ChangeNotifier {
  final Map<String, StreamServer> _servers = {};
  bool _isDiscovering = false;
  String? _error;

  List<StreamServer> get servers => _servers.values.toList()
    ..sort((a, b) => (b.lastSeen ?? DateTime(0)).compareTo(a.lastSeen ?? DateTime(0)));

  bool get isDiscovering => _isDiscovering;

  String? get error => _error;

  Future<void> startDiscovery() async {
    _isDiscovering = true;
    _error = null;
    notifyListeners();
  }

  Future<void> stopDiscovery() async {
    _isDiscovering = false;
    notifyListeners();
  }

  void addManualServer(String host, {int port = 8080, String? name}) {
    final server = StreamServer.manual(host: host, port: port, name: name);
    _servers[server.id] = server;
    notifyListeners();
  }

  void removeServer(String serverId) {
    _servers.remove(serverId);
    notifyListeners();
  }

  void refreshServer(String serverId) {
    final server = _servers[serverId];
    if (server != null) {
      _servers[serverId] = server.copyWith(lastSeen: DateTime.now());
      notifyListeners();
    }
  }

  /// Simulate discovering a server
  void simulateServerFound(StreamServer server) {
    _servers[server.id] = server;
    notifyListeners();
  }

  /// Simulate losing a server
  void simulateServerLost(String serverId) {
    _servers.remove(serverId);
    notifyListeners();
  }

  /// Simulate an error
  void simulateError(String error) {
    _error = error;
    _isDiscovering = false;
    notifyListeners();
  }
}

/// Mock stream service for testing
class MockStreamService extends ChangeNotifier {
  StreamConnectionState _state = StreamConnectionState.initial;
  final Map<String, dynamic> _renderers = {};

  StreamConnectionState get state => _state;

  Map<String, dynamic> get renderers => Map.unmodifiable(_renderers);

  Future<void> connect(StreamServer server) async {
    _state = _state.copyWith(
      phase: ConnectionPhase.connecting,
      server: server,
    );
    notifyListeners();
  }

  Future<void> disconnect() async {
    _state = StreamConnectionState.initial;
    notifyListeners();
  }

  Future<void> subscribeToWindows(List<int> windowIds) async {
    final subscribedWindows = _state.availableWindows
        .where((w) => windowIds.contains(w.id))
        .toList();

    // Build the new state - need to handle null activeWindowId carefully
    final newActiveWindowId = subscribedWindows.isNotEmpty 
        ? subscribedWindows.first.id.toString() 
        : null;
    
    _state = StreamConnectionState(
      phase: _state.phase,
      server: _state.server,
      availableWindows: _state.availableWindows,
      subscribedWindows: subscribedWindows,
      activeWindowId: newActiveWindowId,
      error: _state.error,
      connectedAt: _state.connectedAt,
    );
    notifyListeners();
  }

  void setActiveWindow(String windowId) {
    _state = _state.copyWith(activeWindowId: windowId);
    notifyListeners();
  }

  dynamic getRenderer(String windowId) => _renderers[windowId];

  /// Simulate state change
  void simulateStateChange(StreamConnectionState newState) {
    _state = newState;
    notifyListeners();
  }

  /// Simulate connection success
  void simulateConnected(StreamServer server, {List<RemoteWindow>? availableWindows}) {
    _state = StreamConnectionState(
      phase: ConnectionPhase.connected,
      server: server,
      connectedAt: DateTime.now(),
      availableWindows: availableWindows ?? const [],
    );
    notifyListeners();
  }

  /// Simulate connection error
  void simulateError(String error) {
    _state = _state.copyWith(
      phase: ConnectionPhase.error,
      error: error,
    );
    notifyListeners();
  }

  /// Simulate receiving window list
  void simulateWindowList(List<RemoteWindow> windows) {
    _state = _state.copyWith(availableWindows: windows);
    notifyListeners();
  }

  /// Simulate a window being closed
  void simulateWindowClosed(int windowId) {
    final updatedWindows = _state.subscribedWindows
        .where((w) => w.id != windowId)
        .toList();
    _state = _state.copyWith(subscribedWindows: updatedWindows);
    notifyListeners();
  }
}

/// Mock preferences service for testing
class MockPreferencesService extends ChangeNotifier {
  List<StreamServer> _recentServers = [];
  StreamServer? _preferredServer;
  bool _autoConnect = false;

  List<StreamServer> get recentServers => List.unmodifiable(_recentServers);
  StreamServer? get preferredServer => _preferredServer;
  bool get autoConnect => _autoConnect;

  Future<void> init() async {
    // No-op for mock
  }

  Future<void> addRecentServer(StreamServer server) async {
    _recentServers.removeWhere((s) => s.id == server.id);
    _recentServers.insert(0, server.copyWith(lastSeen: DateTime.now()));
    notifyListeners();
  }

  Future<void> removeRecentServer(String serverId) async {
    _recentServers.removeWhere((s) => s.id == serverId);
    notifyListeners();
  }

  Future<void> clearRecentServers() async {
    _recentServers.clear();
    notifyListeners();
  }

  Future<void> setPreferredServer(StreamServer? server) async {
    _preferredServer = server;
    notifyListeners();
  }

  Future<void> setAutoConnect(bool value) async {
    _autoConnect = value;
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
