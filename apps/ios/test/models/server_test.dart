import 'package:flutter_test/flutter_test.dart';
import 'package:blink/models/server.dart';
import '../helpers/fixtures.dart';

void main() {
  group('StreamServer', () {
    group('JSON serialization', () {
      test('JSON round-trip preserves all fields', () {
        final server = makeServer(
          name: 'My Mac',
          host: '10.0.0.50',
          port: 9090,
          version: '2.0.0',
          isManualEntry: true,
        );

        final json = server.toJson();
        final restored = StreamServer.fromJson(json);

        expect(restored.id, server.id);
        expect(restored.name, server.name);
        expect(restored.host, server.host);
        expect(restored.port, server.port);
        expect(restored.version, server.version);
        expect(restored.isManualEntry, server.isManualEntry);
      });

      test('fromJson handles all fields correctly', () {
        final json = sampleServerJson(
          id: 'custom-id',
          name: 'Custom Server',
          host: '172.16.0.1',
          port: 8888,
          version: '1.5.0',
          isManualEntry: true,
        );

        final server = StreamServer.fromJson(json);

        expect(server.id, 'custom-id');
        expect(server.name, 'Custom Server');
        expect(server.host, '172.16.0.1');
        expect(server.port, 8888);
        expect(server.version, '1.5.0');
        expect(server.isManualEntry, true);
      });

      test('toJson includes all fields', () {
        final server = makeServer(
          name: 'Test',
          host: '192.168.1.1',
          port: 8080,
          version: '1.0.0',
        );

        final json = server.toJson();

        expect(json, containsPair('id', '192.168.1.1:8080'));
        expect(json, containsPair('name', 'Test'));
        expect(json, containsPair('host', '192.168.1.1'));
        expect(json, containsPair('port', 8080));
        expect(json, containsPair('version', '1.0.0'));
        expect(json, contains('last_seen'));
        expect(json, containsPair('is_manual_entry', false));
      });
    });

    group('factory constructors', () {
      test('fromMdns extracts TXT records correctly', () {
        final server = StreamServer.fromMdns(
          name: 'discovered-name',
          host: '192.168.1.100',
          port: 8080,
          txtRecords: {
            'name': 'Custom Name from TXT',
            'version': '3.0.0',
          },
        );

        expect(server.name, 'Custom Name from TXT');
        expect(server.version, '3.0.0');
        expect(server.host, '192.168.1.100');
        expect(server.port, 8080);
        expect(server.isManualEntry, false);
      });

      test('fromMdns uses service name when TXT name missing', () {
        final server = StreamServer.fromMdns(
          name: 'service-name',
          host: '192.168.1.100',
          port: 8080,
          txtRecords: null,
        );

        expect(server.name, 'service-name');
      });

      test('manual creates server with isManualEntry true', () {
        final server = StreamServer.manual(
          host: '10.0.0.1',
          port: 9000,
          name: 'My Server',
        );

        expect(server.isManualEntry, true);
        expect(server.name, 'My Server');
        expect(server.id, '10.0.0.1:9000');
      });

      test('manual uses host as name when name not provided', () {
        final server = StreamServer.manual(
          host: '10.0.0.1',
          port: 9000,
        );

        expect(server.name, '10.0.0.1');
      });
    });

    group('URL generators', () {
      test('signalingUrl produces valid WebSocket URL', () {
        final server = makeServer(host: '192.168.1.50', port: 8080);

        expect(server.signalingUrl, 'ws://192.168.1.50:8080/signaling');
      });

      test('windowsUrl produces valid WebSocket URL', () {
        final server = makeServer(host: '192.168.1.50', port: 8080);

        expect(server.windowsUrl, 'ws://192.168.1.50:8080/windows');
      });

      test('inputUrl produces valid WebSocket URL', () {
        final server = makeServer(host: '192.168.1.50', port: 8080);

        expect(server.inputUrl, 'ws://192.168.1.50:8080/input');
      });

      test('healthUrl produces valid HTTP URL', () {
        final server = makeServer(host: '192.168.1.50', port: 8080);

        expect(server.healthUrl, 'http://192.168.1.50:8080/health');
      });

      test('displayAddress shows host:port', () {
        final server = makeServer(host: '10.0.0.1', port: 9000);

        expect(server.displayAddress, '10.0.0.1:9000');
      });
    });

    group('equality', () {
      test('equality is based on id only', () {
        final server1 = makeServer(host: '192.168.1.1', port: 8080, name: 'A');
        final server2 = makeServer(host: '192.168.1.1', port: 8080, name: 'B');
        final server3 = makeServer(host: '192.168.1.2', port: 8080, name: 'A');

        expect(server1, equals(server2)); // Same id
        expect(server1, isNot(equals(server3))); // Different id
      });

      test('hashCode is based on id', () {
        final server1 = makeServer(host: '192.168.1.1', port: 8080, name: 'A');
        final server2 = makeServer(host: '192.168.1.1', port: 8080, name: 'B');

        expect(server1.hashCode, equals(server2.hashCode));
      });
    });

    group('copyWith', () {
      test('copyWith preserves unmodified fields', () {
        final original = makeServer(
          name: 'Original',
          host: '192.168.1.1',
          port: 8080,
          version: '1.0.0',
        );

        final copied = original.copyWith(name: 'Updated');

        expect(copied.name, 'Updated');
        expect(copied.host, original.host);
        expect(copied.port, original.port);
        expect(copied.version, original.version);
        expect(copied.id, original.id);
      });

      test('copyWith can update lastSeen', () {
        final original = makeServer();
        final newTime = DateTime(2024, 1, 1);

        final copied = original.copyWith(lastSeen: newTime);

        expect(copied.lastSeen, newTime);
      });
    });

    test('toString produces readable output', () {
      final server = makeServer(name: 'MyMac', host: '192.168.1.100', port: 8080);

      expect(server.toString(), contains('MyMac'));
      expect(server.toString(), contains('192.168.1.100:8080'));
    });
  });
}

