import 'package:flutter_test/flutter_test.dart';
import 'package:blink/models/connection_state.dart';
import 'package:blink/models/remote_window.dart';
import '../helpers/mocks.dart';
import '../helpers/fixtures.dart';

void main() {
  group('StreamService state transitions', () {
    late MockStreamService service;

    setUp(() {
      service = MockStreamService();
    });

    test('initial state is disconnected', () {
      expect(service.state.phase, ConnectionPhase.disconnected);
      expect(service.state.server, isNull);
      expect(service.state.isConnected, isFalse);
    });

    test('connect transitions to connecting state', () async {
      final server = makeServer();
      
      await service.connect(server);
      
      expect(service.state.phase, ConnectionPhase.connecting);
      expect(service.state.server, server);
    });

    test('simulateConnected transitions to connected state', () {
      final server = makeServer();
      
      service.simulateConnected(server);
      
      expect(service.state.phase, ConnectionPhase.connected);
      expect(service.state.server, server);
      expect(service.state.connectedAt, isNotNull);
      expect(service.state.isConnected, isTrue);
    });

    test('simulateError transitions to error state with message', () {
      final server = makeServer();
      service.simulateConnected(server);
      
      service.simulateError('Connection lost');
      
      expect(service.state.phase, ConnectionPhase.error);
      expect(service.state.error, 'Connection lost');
      expect(service.state.hasError, isTrue);
    });

    test('disconnect resets to initial state', () async {
      final server = makeServer();
      service.simulateConnected(server);
      expect(service.state.isConnected, isTrue);
      
      await service.disconnect();
      
      expect(service.state, StreamConnectionState.initial);
      expect(service.state.phase, ConnectionPhase.disconnected);
      expect(service.state.server, isNull);
    });
  });

  group('StreamService window management', () {
    late MockStreamService service;

    setUp(() {
      service = MockStreamService();
      final server = makeServer();
      service.simulateConnected(server, availableWindows: [
        makeWindow(id: 1, title: 'Window 1'),
        makeWindow(id: 2, title: 'Window 2'),
        makeWindow(id: 3, title: 'Window 3'),
      ]);
    });

    test('simulateWindowList updates availableWindows', () {
      final windows = [
        makeWindow(id: 10, title: 'New Window 1'),
        makeWindow(id: 20, title: 'New Window 2'),
      ];
      
      service.simulateWindowList(windows);
      
      expect(service.state.availableWindows, hasLength(2));
      expect(service.state.availableWindows[0].id, 10);
      expect(service.state.availableWindows[1].id, 20);
    });

    test('subscribeToWindows updates subscribedWindows from available', () async {
      await service.subscribeToWindows([1, 2]);
      
      expect(service.state.subscribedWindows, hasLength(2));
      expect(service.state.subscribedWindows.map((w) => w.id), containsAll([1, 2]));
    });

    test('subscribeToWindows sets activeWindowId to first subscribed', () async {
      await service.subscribeToWindows([2, 3]);
      
      expect(service.state.activeWindowId, '2');
    });

    test('subscribeToWindows with empty list clears subscriptions', () async {
      await service.subscribeToWindows([1]);
      expect(service.state.subscribedWindows, isNotEmpty);
      
      await service.subscribeToWindows([]);
      
      expect(service.state.subscribedWindows, isEmpty);
      expect(service.state.activeWindowId, isNull);
    });

    test('setActiveWindow updates activeWindowId', () {
      service.setActiveWindow('42');
      
      expect(service.state.activeWindowId, '42');
    });

    test('simulateWindowClosed removes from subscribedWindows', () async {
      await service.subscribeToWindows([1, 2, 3]);
      expect(service.state.subscribedWindows, hasLength(3));
      
      service.simulateWindowClosed(2);
      
      expect(service.state.subscribedWindows, hasLength(2));
      expect(service.state.subscribedWindows.map((w) => w.id), isNot(contains(2)));
    });

    test('getRenderer returns null for unknown window', () {
      expect(service.getRenderer('unknown'), isNull);
    });
  });

  group('StreamService notifies listeners', () {
    late MockStreamService service;
    int notificationCount = 0;

    setUp(() {
      service = MockStreamService();
      notificationCount = 0;
      service.addListener(() {
        notificationCount++;
      });
    });

    tearDown(() {
      service.dispose();
    });

    test('connect notifies listeners', () async {
      await service.connect(makeServer());
      
      expect(notificationCount, greaterThan(0));
    });

    test('disconnect notifies listeners', () async {
      await service.connect(makeServer());
      final countAfterConnect = notificationCount;
      
      await service.disconnect();
      
      expect(notificationCount, greaterThan(countAfterConnect));
    });

    test('simulateStateChange notifies listeners', () {
      service.simulateStateChange(StreamConnectionState.initial);
      
      expect(notificationCount, 1);
    });

    test('subscribeToWindows notifies listeners', () async {
      service.simulateConnected(makeServer(), availableWindows: [makeWindow(id: 1)]);
      final countBefore = notificationCount;
      
      await service.subscribeToWindows([1]);
      
      expect(notificationCount, greaterThan(countBefore));
    });

    test('setActiveWindow notifies listeners', () {
      final countBefore = notificationCount;
      
      service.setActiveWindow('1');
      
      expect(notificationCount, greaterThan(countBefore));
    });
  });
}

