import 'package:flutter_test/flutter_test.dart';
import 'package:blink/providers/connection_provider.dart';
import 'package:blink/models/connection_state.dart';
import 'package:blink/models/server.dart';
import 'package:blink/services/input_service.dart';
import '../helpers/mocks.dart';
import '../helpers/fixtures.dart';

void main() {
  group('ConnectionProvider', () {
    late MockStreamService streamService;
    late TestableInputService inputService;
    late MockDiscoveryService discoveryService;
    late MockPreferencesService preferencesService;
    late ConnectionProvider provider;

    setUp(() {
      streamService = MockStreamService();
      inputService = TestableInputService();
      discoveryService = MockDiscoveryService();
      preferencesService = MockPreferencesService();

      provider = ConnectionProvider(
        streamService: streamService,
        inputService: inputService,
        discoveryService: discoveryService,
        preferencesService: preferencesService,
      );
    });

    tearDown(() {
      provider.dispose();
    });

    group('state exposure', () {
      test('state reflects underlying stream service state', () {
        expect(provider.state.phase, ConnectionPhase.disconnected);

        final server = makeServer();
        streamService.simulateConnected(server);

        expect(provider.state.phase, ConnectionPhase.connected);
        expect(provider.state.server, server);
      });

      test('discoveredServers reflects discovery service servers', () {
        expect(provider.discoveredServers, isEmpty);

        discoveryService.simulateServerFound(makeServer(host: '192.168.1.1'));
        discoveryService.simulateServerFound(makeServer(host: '192.168.1.2'));

        expect(provider.discoveredServers, hasLength(2));
      });

      test('recentServers reflects preferences service', () async {
        expect(provider.recentServers, isEmpty);

        final server = makeServer();
        await preferencesService.addRecentServer(server);

        expect(provider.recentServers, hasLength(1));
      });

      test('isDiscovering reflects discovery service state', () async {
        expect(provider.isDiscovering, isFalse);

        await discoveryService.startDiscovery();

        expect(provider.isDiscovering, isTrue);
      });
    });

    group('connectToServer', () {
      test('calls stream service connect', () async {
        final server = makeServer();

        await provider.connectToServer(server);

        // Stream service state should reflect connection attempt
        expect(streamService.state.phase, ConnectionPhase.connecting);
        expect(streamService.state.server, server);
      });

      test('calls input service connect', () async {
        final server = makeServer();

        await provider.connectToServer(server);

        expect(inputService.connectCalled, isTrue);
        expect(inputService.lastConnectedServer, server);
      });

      test('adds server to recent servers', () async {
        final server = makeServer();

        await provider.connectToServer(server);

        expect(preferencesService.recentServers, contains(server));
      });
    });

    group('disconnect', () {
      test('calls stream service disconnect', () async {
        final server = makeServer();
        await provider.connectToServer(server);

        await provider.disconnect();

        expect(streamService.state.phase, ConnectionPhase.disconnected);
      });

      test('calls input service disconnect', () async {
        final server = makeServer();
        await provider.connectToServer(server);

        await provider.disconnect();

        expect(inputService.disconnectCalled, isTrue);
      });
    });

    group('discovery', () {
      test('startDiscovery delegates to discovery service', () async {
        await provider.startDiscovery();

        expect(provider.isDiscovering, isTrue);
      });

      test('stopDiscovery delegates to discovery service', () async {
        await provider.startDiscovery();
        await provider.stopDiscovery();

        expect(provider.isDiscovering, isFalse);
      });
    });

    group('addManualServer', () {
      test('delegates to discovery service', () {
        provider.addManualServer('10.0.0.1', port: 9000, name: 'Manual');

        expect(provider.discoveredServers, hasLength(1));
        expect(provider.discoveredServers.first.host, '10.0.0.1');
        expect(provider.discoveredServers.first.port, 9000);
      });
    });

    group('subscribeToWindows', () {
      test('delegates to stream service', () async {
        streamService.simulateConnected(makeServer(), availableWindows: [
          makeWindow(id: 1),
          makeWindow(id: 2),
        ]);

        await provider.subscribeToWindows([1, 2]);

        expect(streamService.state.subscribedWindows, hasLength(2));
      });
    });

    group('setActiveWindow', () {
      test('delegates to stream service', () {
        provider.setActiveWindow('42');

        expect(streamService.state.activeWindowId, '42');
      });
    });

    group('notifications', () {
      int notificationCount = 0;

      setUp(() {
        notificationCount = 0;
        provider.addListener(() {
          notificationCount++;
        });
      });

      test('notifies listeners when stream state changes', () {
        final countBefore = notificationCount;

        streamService.simulateConnected(makeServer());

        expect(notificationCount, greaterThan(countBefore));
      });

      test('notifies listeners when discovery state changes', () async {
        final countBefore = notificationCount;

        await discoveryService.startDiscovery();

        expect(notificationCount, greaterThan(countBefore));
      });

      test('notifies listeners when servers discovered', () {
        final countBefore = notificationCount;

        discoveryService.simulateServerFound(makeServer());

        expect(notificationCount, greaterThan(countBefore));
      });
    });
  });
}

/// Testable input service that tracks method calls
class TestableInputService extends InputService {
  bool connectCalled = false;
  bool disconnectCalled = false;
  StreamServer? lastConnectedServer;

  @override
  Future<void> connect(StreamServer server) async {
    connectCalled = true;
    lastConnectedServer = server;
    // Don't call super - we don't want actual WebSocket connection in tests
  }

  @override
  Future<void> disconnect() async {
    disconnectCalled = true;
    // Don't call super - we don't want actual WebSocket disconnection in tests
  }
}

