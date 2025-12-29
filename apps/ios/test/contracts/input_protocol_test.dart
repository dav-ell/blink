import 'package:flutter_test/flutter_test.dart';
import '../helpers/fixtures.dart';

/// These tests verify the exact JSON format expected by the server.
/// Update these if the API contract changes.
void main() {
  group('Mouse event protocol', () {
    test('click event matches schema', () {
      final event = makeClickEvent(
        windowId: 1,
        x: 0.5,
        y: 0.5,
        button: 'left',
      );

      expect(event, {
        'type': 'mouse',
        'window_id': 1,
        'action': 'click',
        'button': 'left',
        'x': 0.5,
        'y': 0.5,
      });
    });

    test('click event with right button', () {
      final event = makeClickEvent(
        windowId: 1,
        x: 0.25,
        y: 0.75,
        button: 'right',
      );

      expect(event['button'], 'right');
      expect(event['action'], 'click');
    });

    test('scroll event includes delta fields', () {
      final event = makeScrollEvent(
        windowId: 1,
        x: 0.5,
        y: 0.5,
        deltaX: 10.0,
        deltaY: -20.0,
      );

      expect(event, {
        'type': 'mouse',
        'window_id': 1,
        'action': 'scroll',
        'x': 0.5,
        'y': 0.5,
        'scroll_delta_x': 10.0,
        'scroll_delta_y': -20.0,
      });
    });

    test('scroll event delta can be negative', () {
      final event = makeScrollEvent(
        windowId: 1,
        x: 0.0,
        y: 0.0,
        deltaX: -100.5,
        deltaY: -50.5,
      );

      expect(event['scroll_delta_x'], -100.5);
      expect(event['scroll_delta_y'], -50.5);
    });

    test('coordinates use normalized 0-1 range', () {
      // Edge case: top-left corner
      final topLeft = makeClickEvent(windowId: 1, x: 0.0, y: 0.0);
      expect(topLeft['x'], 0.0);
      expect(topLeft['y'], 0.0);

      // Edge case: bottom-right corner
      final bottomRight = makeClickEvent(windowId: 1, x: 1.0, y: 1.0);
      expect(bottomRight['x'], 1.0);
      expect(bottomRight['y'], 1.0);

      // Center
      final center = makeClickEvent(windowId: 1, x: 0.5, y: 0.5);
      expect(center['x'], 0.5);
      expect(center['y'], 0.5);
    });

    test('window_id is integer', () {
      final event = makeClickEvent(windowId: 12345, x: 0.0, y: 0.0);
      expect(event['window_id'], isA<int>());
      expect(event['window_id'], 12345);
    });
  });

  group('Keyboard event protocol', () {
    test('key press event matches schema', () {
      final event = makeKeyPressEvent(
        windowId: 1,
        keyCode: 65,
        modifiers: [],
      );

      expect(event, {
        'type': 'key',
        'window_id': 1,
        'action': 'press',
        'key_code': 65,
        'modifiers': <String>[],
      });
    });

    test('modifiers are lowercase strings', () {
      final event = makeKeyPressEvent(
        windowId: 1,
        keyCode: 65,
        modifiers: ['cmd', 'shift', 'ctrl', 'alt'],
      );

      final modifiers = event['modifiers'] as List;
      for (final mod in modifiers) {
        expect(mod, equals(mod.toString().toLowerCase()));
      }
    });

    test('modifiers array can be empty', () {
      final event = makeKeyPressEvent(windowId: 1, keyCode: 65);
      expect(event['modifiers'], isEmpty);
      expect(event['modifiers'], isA<List>());
    });

    test('keyCode is integer', () {
      final event = makeKeyPressEvent(windowId: 1, keyCode: 13);
      expect(event['key_code'], isA<int>());
      expect(event['key_code'], 13);
    });

    test('action is press for keypress events', () {
      final event = makeKeyPressEvent(windowId: 1, keyCode: 65);
      expect(event['action'], 'press');
    });
  });

  group('Text event protocol', () {
    test('text input event matches schema', () {
      final event = makeTextInputEvent(
        windowId: 1,
        text: 'Hello',
      );

      expect(event, {
        'type': 'text',
        'window_id': 1,
        'text': 'Hello',
      });
    });

    test('text can contain unicode characters', () {
      final event = makeTextInputEvent(windowId: 1, text: '日本語🎉');
      expect(event['text'], '日本語🎉');
    });

    test('text can be empty string', () {
      final event = makeTextInputEvent(windowId: 1, text: '');
      expect(event['text'], '');
    });

    test('text can contain newlines', () {
      final event = makeTextInputEvent(windowId: 1, text: 'line1\nline2\nline3');
      expect(event['text'], contains('\n'));
    });

    test('text can contain special characters', () {
      final event = makeTextInputEvent(windowId: 1, text: '<script>alert("xss")</script>');
      expect(event['text'], '<script>alert("xss")</script>');
    });
  });
}

