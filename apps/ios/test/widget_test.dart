// Basic Flutter widget test for the Blink app.
//
// Note: Full widget tests require mocking SharedPreferences and other
// platform dependencies. These are smoke tests to verify basic imports.

import 'package:flutter_test/flutter_test.dart';
import 'package:blink/models/connection_state.dart';
import 'package:blink/models/server.dart';
import 'package:blink/models/remote_window.dart';

void main() {
  group('Model tests', () {
    test('ConnectionPhase extension works', () {
      expect(ConnectionPhase.disconnected.statusMessage, 'Not connected');
      expect(ConnectionPhase.connecting.statusMessage, 'Connecting...');
      expect(ConnectionPhase.connected.statusMessage, 'Connected');
    });

    test('StreamServer can be created', () {
      final server = StreamServer.manual(
        host: '192.168.1.100',
        port: 8080,
        name: 'Test Server',
      );
      expect(server.host, '192.168.1.100');
      expect(server.port, 8080);
      expect(server.name, 'Test Server');
    });

    test('RemoteWindow can be created from JSON', () {
      final json = {
        'id': 123,
        'title': 'Test Window',
        'app': 'TestApp',
        'bounds': {'x': 0.0, 'y': 0.0, 'width': 800.0, 'height': 600.0},
      };
      final window = RemoteWindow.fromJson(json);
      expect(window.id, 123);
      expect(window.title, 'Test Window');
      expect(window.appName, 'TestApp');
    });

    test('StreamConnectionState initial state is disconnected', () {
      const state = StreamConnectionState.initial;
      expect(state.phase, ConnectionPhase.disconnected);
      expect(state.isConnected, false);
      expect(state.server, null);
    });
  });
}
