import 'package:flutter_test/flutter_test.dart';
import 'package:blink/models/remote_window.dart';
import '../helpers/fixtures.dart';

void main() {
  group('RemoteWindow', () {
    group('JSON serialization', () {
      test('JSON round-trip preserves all fields', () {
        final window = makeWindow(
          id: 123,
          title: 'Cursor - my-project',
          appName: 'Cursor',
          width: 1920,
          height: 1080,
          x: 100,
          y: 50,
          isMinimized: false,
          isOnScreen: true,
        );

        final json = window.toJson();
        final restored = RemoteWindow.fromJson(json);

        expect(restored.id, window.id);
        expect(restored.title, window.title);
        expect(restored.appName, window.appName);
        expect(restored.bounds.width, window.bounds.width);
        expect(restored.bounds.height, window.bounds.height);
        expect(restored.bounds.x, window.bounds.x);
        expect(restored.bounds.y, window.bounds.y);
        expect(restored.isMinimized, window.isMinimized);
        expect(restored.isOnScreen, window.isOnScreen);
      });

      test('fromJson handles all fields from server', () {
        final json = sampleWindowJson(
          id: 456,
          title: 'Terminal - zsh',
          app: 'Terminal',
          width: 800,
          height: 600,
        );

        final window = RemoteWindow.fromJson(json);

        expect(window.id, 456);
        expect(window.title, 'Terminal - zsh');
        expect(window.appName, 'Terminal');
        expect(window.bounds.width, 800);
        expect(window.bounds.height, 600);
      });

      test('handles missing optional fields gracefully', () {
        final json = {
          'id': 1,
          // title missing - should default
          // app missing - should default
          // bounds missing - should use defaults
        };

        final window = RemoteWindow.fromJson(json);

        expect(window.id, 1);
        expect(window.title, 'Untitled'); // Default value
        expect(window.appName, 'Unknown'); // Default value
        expect(window.bounds.width, 1920); // Default value
        expect(window.bounds.height, 1080); // Default value
      });

      test('toJson produces correct structure', () {
        final window = makeWindow(id: 789, title: 'Test', appName: 'App');

        final json = window.toJson();

        expect(json['id'], 789);
        expect(json['title'], 'Test');
        expect(json['app'], 'App');
        expect(json['bounds'], isA<Map>());
        expect(json['is_minimized'], false);
        expect(json['is_on_screen'], true);
      });
    });

    group('computed properties', () {
      test('aspectRatio calculates correctly for landscape', () {
        final window = makeWindow(width: 1920, height: 1080);

        expect(window.aspectRatio, closeTo(16 / 9, 0.01));
      });

      test('aspectRatio calculates correctly for portrait', () {
        final window = makeWindow(width: 1080, height: 1920);

        expect(window.aspectRatio, closeTo(9 / 16, 0.01));
      });

      test('aspectRatio defaults to 16:9 when height is 0', () {
        final window = RemoteWindow(
          id: 1,
          title: 'Test',
          appName: 'App',
          bounds: const WindowBounds(width: 100, height: 0),
        );

        expect(window.aspectRatio, closeTo(16 / 9, 0.01));
      });

      test('displayName combines app and title when different', () {
        final window = makeWindow(title: 'my-project', appName: 'Cursor');

        expect(window.displayName, 'Cursor - my-project');
      });

      test('displayName uses title only when it contains app name', () {
        final window = makeWindow(title: 'Cursor - my-project', appName: 'Cursor');

        expect(window.displayName, 'Cursor - my-project');
      });

      test('shortName truncates long titles', () {
        final window = makeWindow(title: 'This is a very long window title that should be truncated');

        expect(window.shortName.length, lessThanOrEqualTo(20));
        expect(window.shortName, endsWith('...'));
      });

      test('shortName keeps short titles unchanged', () {
        final window = makeWindow(title: 'Short');

        expect(window.shortName, 'Short');
      });
    });

    group('equality', () {
      test('equality is based on id only', () {
        final window1 = makeWindow(id: 1, title: 'A');
        final window2 = makeWindow(id: 1, title: 'B');
        final window3 = makeWindow(id: 2, title: 'A');

        expect(window1, equals(window2));
        expect(window1, isNot(equals(window3)));
      });

      test('hashCode is based on id', () {
        final window1 = makeWindow(id: 1, title: 'A');
        final window2 = makeWindow(id: 1, title: 'B');

        expect(window1.hashCode, equals(window2.hashCode));
      });
    });

    test('toString produces readable output', () {
      final window = makeWindow(id: 123, title: 'Test Window', appName: 'App');

      expect(window.toString(), contains('123'));
      expect(window.toString(), contains('Test Window'));
      expect(window.toString(), contains('App'));
    });
  });

  group('WindowBounds', () {
    test('JSON round-trip preserves all fields', () {
      const bounds = WindowBounds(x: 100, y: 200, width: 800, height: 600);

      final json = bounds.toJson();
      final restored = WindowBounds.fromJson(json);

      expect(restored.x, bounds.x);
      expect(restored.y, bounds.y);
      expect(restored.width, bounds.width);
      expect(restored.height, bounds.height);
    });

    test('fromJson handles missing fields with defaults', () {
      final bounds = WindowBounds.fromJson({});

      expect(bounds.x, 0);
      expect(bounds.y, 0);
      expect(bounds.width, 1920);
      expect(bounds.height, 1080);
    });

    test('fromJson handles integer values', () {
      final bounds = WindowBounds.fromJson({
        'x': 100,
        'y': 200,
        'width': 800,
        'height': 600,
      });

      expect(bounds.x, 100.0);
      expect(bounds.y, 200.0);
      expect(bounds.width, 800.0);
      expect(bounds.height, 600.0);
    });

    test('toString produces readable output', () {
      const bounds = WindowBounds(x: 10, y: 20, width: 800, height: 600);

      expect(bounds.toString(), contains('800'));
      expect(bounds.toString(), contains('600'));
    });
  });
}

