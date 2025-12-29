import 'package:blink/models/server.dart';
import 'package:blink/models/remote_window.dart';
import 'package:blink/services/discovery_service.dart';
import 'package:blink/services/stream_service.dart';
import 'package:blink/services/input_service.dart';
import 'package:blink/services/preferences_service.dart';
import 'package:blink/providers/connection_provider.dart';
import 'package:blink/providers/windows_provider.dart';
import 'package:blink/providers/stream_provider.dart' show VideoStreamProvider;
import 'package:blink/providers/theme_provider.dart';
import 'package:blink/core/service_locator.dart';
import '../test/helpers/mocks.dart';

/// Test server for mocking
final testServer = StreamServer.manual(
  host: '192.168.1.100',
  port: 8080,
  name: 'Test Mac',
);

/// Test windows for mocking
final testWindows = [
  RemoteWindow.fromJson({
    'id': 1,
    'title': 'Finder',
    'app': 'Finder',
    'bounds': {'x': 0.0, 'y': 0.0, 'width': 800.0, 'height': 600.0},
  }),
  RemoteWindow.fromJson({
    'id': 2,
    'title': 'Safari - Apple',
    'app': 'Safari',
    'bounds': {'x': 100.0, 'y': 100.0, 'width': 1200.0, 'height': 800.0},
  }),
  RemoteWindow.fromJson({
    'id': 3,
    'title': 'Terminal',
    'app': 'Terminal',
    'bounds': {'x': 200.0, 'y': 200.0, 'width': 600.0, 'height': 400.0},
  }),
];

/// Mock services instances for test control
late MockDiscoveryService mockDiscoveryService;
late MockStreamService mockStreamService;
late MockPreferencesService mockPreferencesService;
late MockInputService mockInputService;

/// Setup service locator with mock services for integration testing
/// 
/// This uses the same getIt instance as the main app to ensure
/// proper integration with the app's dependency injection.
Future<void> setupTestServiceLocator({
  bool withRecentServer = true,
  bool withWindows = true,
}) async {
  // Reset any existing registrations
  await resetServiceLocator();

  // Create mock services
  mockPreferencesService = MockPreferencesService();
  mockDiscoveryService = MockDiscoveryService();
  mockStreamService = MockStreamService();
  mockInputService = MockInputService();

  // Initialize mock preferences
  await mockPreferencesService.init();
  
  // Pre-populate with a recent server if requested
  if (withRecentServer) {
    await mockPreferencesService.addRecentServer(testServer);
  }

  // Register services using the main app's getIt instance
  getIt.registerSingleton<PreferencesService>(mockPreferencesService);
  getIt.registerSingleton<DiscoveryService>(mockDiscoveryService);
  getIt.registerSingleton<StreamService>(mockStreamService);
  getIt.registerSingleton<InputService>(mockInputService);

  // Register providers
  getIt.registerLazySingleton<ConnectionProvider>(
    () => ConnectionProvider(
      streamService: getIt<StreamService>(),
      inputService: getIt<InputService>(),
      discoveryService: getIt<DiscoveryService>(),
      preferencesService: getIt<PreferencesService>(),
    ),
  );

  getIt.registerLazySingleton<WindowsProvider>(
    () => WindowsProvider(
      streamService: getIt<StreamService>(),
    ),
  );

  getIt.registerLazySingleton<VideoStreamProvider>(
    () => VideoStreamProvider(
      streamService: getIt<StreamService>(),
    ),
  );

  getIt.registerFactory<ThemeProvider>(
    () => ThemeProvider(),
  );
}

/// Simulate successful connection with available windows
void simulateSuccessfulConnection() {
  mockStreamService.simulateConnected(
    testServer,
    availableWindows: testWindows,
  );
}

/// Simulate connection failure
void simulateConnectionError(String error) {
  mockStreamService.simulateError(error);
}

/// Reset service locator after tests
Future<void> resetTestServiceLocator() async {
  await resetServiceLocator();
}

/// Mock input service for testing
class MockInputService extends InputService {
  bool _mockIsConnected = false;
  final List<Map<String, dynamic>> sentEvents = [];

  @override
  bool get isConnected => _mockIsConnected;

  @override
  Future<void> connect(StreamServer server) async {
    _mockIsConnected = true;
    notifyListeners();
  }

  @override
  Future<void> disconnect() async {
    _mockIsConnected = false;
    notifyListeners();
  }

  @override
  void sendClick({
    required int windowId,
    required double x,
    required double y,
    MouseButton button = MouseButton.left,
  }) {
    sentEvents.add({
      'type': 'click',
      'windowId': windowId,
      'x': x,
      'y': y,
      'button': button,
    });
  }

  @override
  void sendMove({
    required int windowId,
    required double x,
    required double y,
    bool isDragging = false,
  }) {
    sentEvents.add({
      'type': 'move',
      'windowId': windowId,
      'x': x,
      'y': y,
      'isDragging': isDragging,
    });
  }

  @override
  void sendKeyPress({
    required int windowId,
    required int keyCode,
    List<KeyModifier> modifiers = const [],
  }) {
    sentEvents.add({
      'type': 'keyPress',
      'windowId': windowId,
      'keyCode': keyCode,
      'modifiers': modifiers,
    });
  }

  @override
  void sendTextInput({
    required int windowId,
    required String text,
  }) {
    sentEvents.add({
      'type': 'textInput',
      'windowId': windowId,
      'text': text,
    });
  }

  @override
  void sendScroll({
    required int windowId,
    required double x,
    required double y,
    required double deltaX,
    required double deltaY,
  }) {
    sentEvents.add({
      'type': 'scroll',
      'windowId': windowId,
      'x': x,
      'y': y,
      'deltaX': deltaX,
      'deltaY': deltaY,
    });
  }

  void clearEvents() {
    sentEvents.clear();
  }
}

