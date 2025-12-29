import 'package:flutter/foundation.dart';
import '../models/server.dart';
import '../models/connection_state.dart';
import '../services/stream_service.dart';
import '../services/input_service.dart';
import '../services/discovery_service.dart';
import '../services/preferences_service.dart';

/// Provider for managing connection state and coordinating services
class ConnectionProvider extends ChangeNotifier {
  final StreamService _streamService;
  final InputService _inputService;
  final DiscoveryService _discoveryService;
  final PreferencesService _preferencesService;

  ConnectionProvider({
    required StreamService streamService,
    required InputService inputService,
    required DiscoveryService discoveryService,
    required PreferencesService preferencesService,
  })  : _streamService = streamService,
        _inputService = inputService,
        _discoveryService = discoveryService,
        _preferencesService = preferencesService {
    // Listen to stream service changes
    _streamService.addListener(_onStreamStateChanged);
    _discoveryService.addListener(notifyListeners);
  }

  /// Current connection state
  StreamConnectionState get state => _streamService.state;

  /// Discovered servers
  List<StreamServer> get discoveredServers => _discoveryService.servers;

  /// Recent servers
  List<StreamServer> get recentServers => _preferencesService.recentServers;

  /// Whether discovery is active
  bool get isDiscovering => _discoveryService.isDiscovering;

  /// Start discovering servers
  Future<void> startDiscovery() async {
    await _discoveryService.startDiscovery();
  }

  /// Stop discovering servers
  Future<void> stopDiscovery() async {
    await _discoveryService.stopDiscovery();
  }

  /// Connect to a server
  Future<void> connectToServer(StreamServer server) async {
    await _streamService.connect(server);
    await _inputService.connect(server);
    await _preferencesService.addRecentServer(server);
  }

  /// Disconnect from current server
  Future<void> disconnect() async {
    await _streamService.disconnect();
    await _inputService.disconnect();
  }

  /// Add a manual server
  void addManualServer(String host, {int port = 8080, String? name}) {
    _discoveryService.addManualServer(host, port: port, name: name);
  }

  /// Subscribe to specific windows
  Future<void> subscribeToWindows(List<int> windowIds) async {
    await _streamService.subscribeToWindows(windowIds);
  }

  /// Set active window
  void setActiveWindow(String windowId) {
    _streamService.setActiveWindow(windowId);
  }

  void _onStreamStateChanged() {
    notifyListeners();
  }

  @override
  void dispose() {
    _streamService.removeListener(_onStreamStateChanged);
    _discoveryService.removeListener(notifyListeners);
    super.dispose();
  }
}

