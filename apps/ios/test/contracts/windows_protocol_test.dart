import 'package:flutter_test/flutter_test.dart';
import 'package:blink/models/remote_window.dart';
import '../helpers/fixtures.dart';

/// These tests verify the window management message formats.
/// Update these if the windows protocol changes.
void main() {
  group('Windows protocol', () {
    group('subscribe message', () {
      test('subscribe message format', () {
        final message = makeSubscribeMessage([1, 2, 3]);

        expect(message, {
          'type': 'subscribe',
          'window_ids': [1, 2, 3],
        });
      });

      test('subscribe with single window', () {
        final message = makeSubscribeMessage([42]);

        expect(message['window_ids'], [42]);
      });

      test('subscribe with empty list', () {
        final message = makeSubscribeMessage([]);

        expect(message['window_ids'], isEmpty);
        expect(message['window_ids'], isA<List>());
      });

      test('window_ids are integers', () {
        final message = makeSubscribeMessage([1, 2, 3]);
        final ids = message['window_ids'] as List;

        for (final id in ids) {
          expect(id, isA<int>());
        }
      });
    });

    group('window_list message', () {
      test('window_list message format', () {
        final windows = [
          makeWindow(id: 1, title: 'Window 1'),
          makeWindow(id: 2, title: 'Window 2'),
        ];
        final message = makeWindowListMessage(windows);

        expect(message['type'], 'window_list');
        expect(message['windows'], isA<List>());
        expect(message['windows'], hasLength(2));
      });

      test('window_list with empty windows', () {
        final message = makeWindowListMessage([]);

        expect(message['type'], 'window_list');
        expect(message['windows'], isEmpty);
      });

      test('window object structure in list', () {
        final windows = [makeWindow(
          id: 123,
          title: 'Test Window',
          appName: 'TestApp',
          width: 1920,
          height: 1080,
        )];
        final message = makeWindowListMessage(windows);
        final windowJson = (message['windows'] as List)[0] as Map<String, dynamic>;

        expect(windowJson['id'], 123);
        expect(windowJson['title'], 'Test Window');
        expect(windowJson['app'], 'TestApp');
        expect(windowJson['bounds'], isA<Map>());
        expect(windowJson['bounds']['width'], 1920);
        expect(windowJson['bounds']['height'], 1080);
      });
    });

    group('window_closed message', () {
      test('window_closed message format', () {
        final message = makeWindowClosedMessage(42);

        expect(message, {
          'type': 'window_closed',
          'id': 42,
        });
      });

      test('window id is integer', () {
        final message = makeWindowClosedMessage(12345);
        
        expect(message['id'], isA<int>());
        expect(message['id'], 12345);
      });
    });

    group('window data parsing', () {
      test('RemoteWindow.fromJson handles complete data', () {
        final json = sampleWindowJson(
          id: 1,
          title: 'Cursor - project',
          app: 'Cursor',
          width: 1920,
          height: 1080,
        );

        final window = RemoteWindow.fromJson(json);

        expect(window.id, 1);
        expect(window.title, 'Cursor - project');
        expect(window.appName, 'Cursor');
        expect(window.bounds.width, 1920);
        expect(window.bounds.height, 1080);
      });

      test('RemoteWindow.fromJson handles minimal data', () {
        final json = {'id': 1};

        final window = RemoteWindow.fromJson(json);

        expect(window.id, 1);
        expect(window.title, 'Untitled');
        expect(window.appName, 'Unknown');
      });

      test('RemoteWindow.toJson produces valid server format', () {
        final window = makeWindow(
          id: 42,
          title: 'Test',
          appName: 'App',
        );

        final json = window.toJson();

        expect(json['id'], 42);
        expect(json['title'], 'Test');
        expect(json['app'], 'App'); // Note: 'app' not 'appName'
        expect(json['bounds'], isA<Map>());
        expect(json['is_minimized'], isA<bool>());
        expect(json['is_on_screen'], isA<bool>());
      });
    });
  });
}

