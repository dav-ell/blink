import 'package:flutter_test/flutter_test.dart';
import '../helpers/mocks.dart';
import '../helpers/fixtures.dart';

void main() {
  group('DiscoveryService', () {
    late MockDiscoveryService service;

    setUp(() {
      service = MockDiscoveryService();
    });

    tearDown(() {
      service.dispose();
    });

    group('server management', () {
      test('servers list is initially empty', () {
        expect(service.servers, isEmpty);
      });

      test('discovered services appear in servers list', () {
        final server = makeServer(host: '192.168.1.100', port: 8080);
        
        service.simulateServerFound(server);
        
        expect(service.servers, hasLength(1));
        expect(service.servers.first.host, '192.168.1.100');
      });

      test('multiple discoveries add to servers list', () {
        service.simulateServerFound(makeServer(host: '192.168.1.100'));
        service.simulateServerFound(makeServer(host: '192.168.1.101'));
        service.simulateServerFound(makeServer(host: '192.168.1.102'));
        
        expect(service.servers, hasLength(3));
      });

      test('lost services are removed from list', () {
        final server = makeServer(host: '192.168.1.100', port: 8080);
        service.simulateServerFound(server);
        expect(service.servers, hasLength(1));
        
        service.simulateServerLost(server.id);
        
        expect(service.servers, isEmpty);
      });

      test('manual servers can be added', () {
        service.addManualServer('10.0.0.1', port: 9000, name: 'My Server');
        
        expect(service.servers, hasLength(1));
        expect(service.servers.first.host, '10.0.0.1');
        expect(service.servers.first.port, 9000);
        expect(service.servers.first.name, 'My Server');
        expect(service.servers.first.isManualEntry, isTrue);
      });

      test('manual servers persist across discovery cycles', () async {
        service.addManualServer('10.0.0.1');
        
        // Start and stop discovery
        await service.startDiscovery();
        await service.stopDiscovery();
        
        // Manual server should still be there
        expect(service.servers, hasLength(1));
        expect(service.servers.first.host, '10.0.0.1');
      });

      test('removeServer removes specific server', () {
        service.addManualServer('10.0.0.1');
        service.addManualServer('10.0.0.2');
        expect(service.servers, hasLength(2));
        
        final serverToRemove = service.servers.firstWhere((s) => s.host == '10.0.0.1');
        service.removeServer(serverToRemove.id);
        
        expect(service.servers, hasLength(1));
        expect(service.servers.first.host, '10.0.0.2');
      });

      test('refreshServer updates lastSeen', () async {
        service.addManualServer('10.0.0.1');
        final serverId = service.servers.first.id;
        final originalLastSeen = service.servers.first.lastSeen;
        
        // Wait a tiny bit to ensure time difference
        await Future.delayed(const Duration(milliseconds: 10));
        service.refreshServer(serverId);
        
        expect(service.servers.first.lastSeen, isNot(equals(originalLastSeen)));
      });

      test('servers sorted by lastSeen descending', () {
        // Add servers with different lastSeen times
        final oldServer = makeServer(
          host: '10.0.0.1',
          lastSeen: DateTime.now().subtract(const Duration(hours: 1)),
        );
        final newServer = makeServer(
          host: '10.0.0.2',
          lastSeen: DateTime.now(),
        );
        
        service.simulateServerFound(oldServer);
        service.simulateServerFound(newServer);
        
        // Most recent should be first
        expect(service.servers.first.host, '10.0.0.2');
        expect(service.servers.last.host, '10.0.0.1');
      });
    });

    group('discovery state', () {
      test('isDiscovering is false initially', () {
        expect(service.isDiscovering, isFalse);
      });

      test('startDiscovery sets isDiscovering to true', () async {
        await service.startDiscovery();
        
        expect(service.isDiscovering, isTrue);
      });

      test('stopDiscovery sets isDiscovering to false', () async {
        await service.startDiscovery();
        await service.stopDiscovery();
        
        expect(service.isDiscovering, isFalse);
      });

      test('error is null initially', () {
        expect(service.error, isNull);
      });

      test('simulateError sets error message and stops discovery', () {
        service.simulateError('Network unavailable');
        
        expect(service.error, 'Network unavailable');
        expect(service.isDiscovering, isFalse);
      });

      test('startDiscovery clears previous error', () async {
        service.simulateError('Previous error');
        expect(service.error, isNotNull);
        
        await service.startDiscovery();
        
        expect(service.error, isNull);
      });
    });

    group('notifications', () {
      int notificationCount = 0;

      setUp(() {
        notificationCount = 0;
        service.addListener(() {
          notificationCount++;
        });
      });

      test('startDiscovery notifies listeners', () async {
        await service.startDiscovery();
        
        expect(notificationCount, greaterThan(0));
      });

      test('stopDiscovery notifies listeners', () async {
        await service.startDiscovery();
        final countAfterStart = notificationCount;
        
        await service.stopDiscovery();
        
        expect(notificationCount, greaterThan(countAfterStart));
      });

      test('simulateServerFound notifies listeners', () {
        service.simulateServerFound(makeServer());
        
        expect(notificationCount, 1);
      });

      test('simulateServerLost notifies listeners', () {
        final server = makeServer();
        service.simulateServerFound(server);
        final countAfterFound = notificationCount;
        
        service.simulateServerLost(server.id);
        
        expect(notificationCount, greaterThan(countAfterFound));
      });

      test('addManualServer notifies listeners', () {
        service.addManualServer('10.0.0.1');
        
        expect(notificationCount, 1);
      });

      test('removeServer notifies listeners', () {
        service.addManualServer('10.0.0.1');
        final countAfterAdd = notificationCount;
        
        service.removeServer(service.servers.first.id);
        
        expect(notificationCount, greaterThan(countAfterAdd));
      });
    });
  });
}

