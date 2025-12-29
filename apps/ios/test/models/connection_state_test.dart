import 'package:flutter_test/flutter_test.dart';
import 'package:blink/models/connection_state.dart';
import '../helpers/fixtures.dart';

void main() {
  group('StreamConnectionState', () {
    group('initial state', () {
      test('initial state is disconnected', () {
        const state = StreamConnectionState.initial;

        expect(state.phase, ConnectionPhase.disconnected);
        expect(state.server, isNull);
        expect(state.availableWindows, isEmpty);
        expect(state.subscribedWindows, isEmpty);
        expect(state.activeWindowId, isNull);
        expect(state.error, isNull);
        expect(state.connectedAt, isNull);
      });
    });

    group('isConnected', () {
      test('isConnected is true only for connected phase', () {
        expect(
          makeConnectionState(phase: ConnectionPhase.connected).isConnected,
          isTrue,
        );

        for (final phase in ConnectionPhase.values) {
          if (phase != ConnectionPhase.connected) {
            expect(
              makeConnectionState(phase: phase).isConnected,
              isFalse,
              reason: '$phase should not be connected',
            );
          }
        }
      });
    });

    group('isConnecting', () {
      test('isConnecting is true for intermediate phases', () {
        final connectingPhases = [
          ConnectionPhase.connecting,
          ConnectionPhase.authenticating,
          ConnectionPhase.negotiating,
        ];

        for (final phase in connectingPhases) {
          expect(
            makeConnectionState(phase: phase).isConnecting,
            isTrue,
            reason: '$phase should be connecting',
          );
        }
      });

      test('isConnecting is false for terminal phases', () {
        final terminalPhases = [
          ConnectionPhase.disconnected,
          ConnectionPhase.connected,
          ConnectionPhase.error,
        ];

        for (final phase in terminalPhases) {
          expect(
            makeConnectionState(phase: phase).isConnecting,
            isFalse,
            reason: '$phase should not be connecting',
          );
        }
      });
    });

    group('hasError', () {
      test('hasError is true when error is set', () {
        final state = makeConnectionState(error: 'Connection failed');

        expect(state.hasError, isTrue);
      });

      test('hasError is false when error is null', () {
        final state = makeConnectionState(error: null);

        expect(state.hasError, isFalse);
      });
    });

    group('connectionDuration', () {
      test('connectionDuration returns duration since connectedAt', () {
        final connectedAt = DateTime.now().subtract(const Duration(minutes: 5));
        final state = makeConnectionState(connectedAt: connectedAt);

        final duration = state.connectionDuration;

        expect(duration, isNotNull);
        expect(duration!.inMinutes, greaterThanOrEqualTo(5));
      });

      test('connectionDuration returns null when not connected', () {
        final state = makeConnectionState(connectedAt: null);

        expect(state.connectionDuration, isNull);
      });
    });

    group('activeWindow', () {
      test('activeWindow returns correct window from subscribed list', () {
        final window1 = makeWindow(id: 1, title: 'Window 1');
        final window2 = makeWindow(id: 2, title: 'Window 2');

        final state = makeConnectionState(
          subscribedWindows: [window1, window2],
          activeWindowId: '2',
        );

        expect(state.activeWindow, equals(window2));
      });

      test('activeWindow returns first window when id not found', () {
        final window1 = makeWindow(id: 1);
        final window2 = makeWindow(id: 2);

        final state = makeConnectionState(
          subscribedWindows: [window1, window2],
          activeWindowId: '999', // Non-existent
        );

        expect(state.activeWindow, equals(window1));
      });

      test('activeWindow returns null when no subscribed windows', () {
        final state = makeConnectionState(
          subscribedWindows: [],
          activeWindowId: '1',
        );

        expect(state.activeWindow, isNull);
      });

      test('activeWindow returns null when activeWindowId is null', () {
        final state = makeConnectionState(
          subscribedWindows: [makeWindow(id: 1)],
          activeWindowId: null,
        );

        expect(state.activeWindow, isNull);
      });
    });

    group('copyWith', () {
      test('copyWith preserves unmodified fields', () {
        final server = makeServer();
        final original = makeConnectionState(
          phase: ConnectionPhase.connected,
          server: server,
          error: 'old error',
        );

        final copied = original.copyWith(phase: ConnectionPhase.error);

        expect(copied.phase, ConnectionPhase.error);
        expect(copied.server, server);
        expect(copied.error, 'old error');
      });

      test('copyWith with clearError removes error', () {
        final state = makeConnectionState(error: 'Some error');

        final cleared = state.copyWith(clearError: true);

        expect(cleared.error, isNull);
      });

      test('copyWith with clearServer removes server', () {
        final state = makeConnectionState(server: makeServer());

        final cleared = state.copyWith(clearServer: true);

        expect(cleared.server, isNull);
      });

      test('copyWith can update multiple fields', () {
        final state = makeConnectionState(
          phase: ConnectionPhase.disconnected,
          error: 'old error',
        );

        final updated = state.copyWith(
          phase: ConnectionPhase.connected,
          clearError: true,
          connectedAt: DateTime.now(),
        );

        expect(updated.phase, ConnectionPhase.connected);
        expect(updated.error, isNull);
        expect(updated.connectedAt, isNotNull);
      });
    });

    test('toString produces readable output', () {
      final server = makeServer(name: 'TestServer');
      final state = makeConnectionState(
        phase: ConnectionPhase.connected,
        server: server,
      );

      expect(state.toString(), contains('connected'));
      expect(state.toString(), contains('TestServer'));
    });
  });

  group('ConnectionPhase', () {
    group('statusMessage extension', () {
      test('all phases have a statusMessage', () {
        for (final phase in ConnectionPhase.values) {
          expect(phase.statusMessage, isNotEmpty, reason: '$phase should have statusMessage');
        }
      });

      test('statusMessage values are correct', () {
        expect(ConnectionPhase.disconnected.statusMessage, 'Not connected');
        expect(ConnectionPhase.discovering.statusMessage, 'Looking for servers...');
        expect(ConnectionPhase.connecting.statusMessage, 'Connecting...');
        expect(ConnectionPhase.authenticating.statusMessage, 'Authenticating...');
        expect(ConnectionPhase.negotiating.statusMessage, 'Setting up stream...');
        expect(ConnectionPhase.connected.statusMessage, 'Connected');
        expect(ConnectionPhase.reconnecting.statusMessage, 'Reconnecting...');
        expect(ConnectionPhase.error.statusMessage, 'Connection failed');
      });
    });

    group('showSpinner extension', () {
      test('showSpinner is true for loading phases', () {
        final loadingPhases = [
          ConnectionPhase.discovering,
          ConnectionPhase.connecting,
          ConnectionPhase.authenticating,
          ConnectionPhase.negotiating,
          ConnectionPhase.reconnecting,
        ];

        for (final phase in loadingPhases) {
          expect(phase.showSpinner, isTrue, reason: '$phase should show spinner');
        }
      });

      test('showSpinner is false for terminal phases', () {
        final terminalPhases = [
          ConnectionPhase.disconnected,
          ConnectionPhase.connected,
          ConnectionPhase.error,
        ];

        for (final phase in terminalPhases) {
          expect(phase.showSpinner, isFalse, reason: '$phase should not show spinner');
        }
      });
    });
  });
}

