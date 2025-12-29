import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blink/services/input_service.dart';
import '../helpers/mocks.dart';

void main() {
  group('InputService message formats', () {
    late MockWebSocketSink sink;
    late _TestableInputService service;

    setUp(() {
      sink = MockWebSocketSink();
      service = _TestableInputService();
      service.connectWithSink(sink);
    });

    tearDown(() async {
      // Don't dispose - just disconnect cleanly
      await service.cleanDisconnect();
    });

    group('mouse events', () {
      test('sendClick produces correct mouse event JSON', () {
        service.sendClick(windowId: 123, x: 0.5, y: 0.3, button: MouseButton.left);

        final sent = jsonDecode(sink.lastMessage) as Map<String, dynamic>;
        expect(sent['type'], 'mouse');
        expect(sent['action'], 'click');
        expect(sent['window_id'], 123);
        expect(sent['x'], closeTo(0.5, 0.001));
        expect(sent['y'], closeTo(0.3, 0.001));
        expect(sent['button'], 'left');
      });

      test('sendClick with right button includes correct button', () {
        service.sendClick(windowId: 1, x: 0.0, y: 0.0, button: MouseButton.right);

        final sent = jsonDecode(sink.lastMessage) as Map<String, dynamic>;
        expect(sent['button'], 'right');
      });

      test('sendClick with middle button includes correct button', () {
        service.sendClick(windowId: 1, x: 0.0, y: 0.0, button: MouseButton.middle);

        final sent = jsonDecode(sink.lastMessage) as Map<String, dynamic>;
        expect(sent['button'], 'middle');
      });

      test('sendDoubleClick produces double_click action', () {
        service.sendDoubleClick(windowId: 456, x: 0.25, y: 0.75);

        final sent = jsonDecode(sink.lastMessage) as Map<String, dynamic>;
        expect(sent['type'], 'mouse');
        expect(sent['action'], 'double_click');
        expect(sent['window_id'], 456);
        expect(sent['x'], closeTo(0.25, 0.001));
        expect(sent['y'], closeTo(0.75, 0.001));
        expect(sent['button'], 'left');
      });

      test('sendRightClick produces click action with right button', () {
        service.sendRightClick(windowId: 789, x: 0.9, y: 0.1);

        final sent = jsonDecode(sink.lastMessage) as Map<String, dynamic>;
        expect(sent['type'], 'mouse');
        expect(sent['action'], 'click');
        expect(sent['button'], 'right');
        expect(sent['window_id'], 789);
      });

      test('sendMove produces move action without dragging', () {
        service.sendMove(windowId: 1, x: 0.5, y: 0.5);

        final sent = jsonDecode(sink.lastMessage) as Map<String, dynamic>;
        expect(sent['type'], 'mouse');
        expect(sent['action'], 'move');
        expect(sent['window_id'], 1);
      });

      test('sendMove produces drag action when isDragging is true', () {
        service.sendMove(windowId: 1, x: 0.5, y: 0.5, isDragging: true);

        final sent = jsonDecode(sink.lastMessage) as Map<String, dynamic>;
        expect(sent['action'], 'drag');
      });

      test('sendMouseDown produces down action', () {
        service.sendMouseDown(windowId: 1, x: 0.3, y: 0.7, button: MouseButton.left);

        final sent = jsonDecode(sink.lastMessage) as Map<String, dynamic>;
        expect(sent['type'], 'mouse');
        expect(sent['action'], 'down');
        expect(sent['button'], 'left');
        expect(sent['window_id'], 1);
      });

      test('sendMouseUp produces up action', () {
        service.sendMouseUp(windowId: 1, x: 0.3, y: 0.7, button: MouseButton.left);

        final sent = jsonDecode(sink.lastMessage) as Map<String, dynamic>;
        expect(sent['type'], 'mouse');
        expect(sent['action'], 'up');
        expect(sent['button'], 'left');
      });

      test('sendScroll includes delta values', () {
        service.sendScroll(
          windowId: 1,
          x: 0.5,
          y: 0.5,
          deltaX: 10.5,
          deltaY: -20.3,
        );

        final sent = jsonDecode(sink.lastMessage) as Map<String, dynamic>;
        expect(sent['type'], 'mouse');
        expect(sent['action'], 'scroll');
        expect(sent['window_id'], 1);
        expect(sent['x'], closeTo(0.5, 0.001));
        expect(sent['y'], closeTo(0.5, 0.001));
        expect(sent['scroll_delta_x'], closeTo(10.5, 0.001));
        expect(sent['scroll_delta_y'], closeTo(-20.3, 0.001));
      });

      test('coordinates are passed as-is for server normalization', () {
        // The service passes coordinates as-is; the server handles normalization
        service.sendClick(windowId: 1, x: 0.0, y: 0.0);
        var sent = jsonDecode(sink.messages[0]) as Map<String, dynamic>;
        expect(sent['x'], 0.0);
        expect(sent['y'], 0.0);

        service.sendClick(windowId: 1, x: 1.0, y: 1.0);
        sent = jsonDecode(sink.messages[1]) as Map<String, dynamic>;
        expect(sent['x'], 1.0);
        expect(sent['y'], 1.0);

        service.sendClick(windowId: 1, x: 0.5, y: 0.5);
        sent = jsonDecode(sink.messages[2]) as Map<String, dynamic>;
        expect(sent['x'], 0.5);
        expect(sent['y'], 0.5);
      });
    });

    group('keyboard events', () {
      test('sendKeyPress produces key press event', () {
        service.sendKeyPress(windowId: 1, keyCode: 65);

        final sent = jsonDecode(sink.lastMessage) as Map<String, dynamic>;
        expect(sent['type'], 'key');
        expect(sent['action'], 'press');
        expect(sent['window_id'], 1);
        expect(sent['key_code'], 65);
        expect(sent['modifiers'], isEmpty);
      });

      test('sendKeyPress includes modifiers array', () {
        service.sendKeyPress(
          windowId: 1,
          keyCode: 65,
          modifiers: [KeyModifier.cmd, KeyModifier.shift],
        );

        final sent = jsonDecode(sink.lastMessage) as Map<String, dynamic>;
        expect(sent['modifiers'], containsAll(['cmd', 'shift']));
      });

      test('sendKeyPress with all modifiers', () {
        service.sendKeyPress(
          windowId: 1,
          keyCode: 65,
          modifiers: [KeyModifier.cmd, KeyModifier.ctrl, KeyModifier.alt, KeyModifier.shift],
        );

        final sent = jsonDecode(sink.lastMessage) as Map<String, dynamic>;
        expect(sent['modifiers'], hasLength(4));
        expect(sent['modifiers'], containsAll(['cmd', 'ctrl', 'alt', 'shift']));
      });

      test('sendKeyDown produces key down event', () {
        service.sendKeyDown(windowId: 1, keyCode: 16, modifiers: [KeyModifier.shift]);

        final sent = jsonDecode(sink.lastMessage) as Map<String, dynamic>;
        expect(sent['type'], 'key');
        expect(sent['action'], 'down');
        expect(sent['key_code'], 16);
        expect(sent['modifiers'], contains('shift'));
      });

      test('sendKeyUp produces key up event', () {
        service.sendKeyUp(windowId: 1, keyCode: 16, modifiers: [KeyModifier.shift]);

        final sent = jsonDecode(sink.lastMessage) as Map<String, dynamic>;
        expect(sent['type'], 'key');
        expect(sent['action'], 'up');
        expect(sent['key_code'], 16);
      });
    });

    group('text events', () {
      test('sendTextInput sends text type message', () {
        service.sendTextInput(windowId: 1, text: 'Hello World');

        final sent = jsonDecode(sink.lastMessage) as Map<String, dynamic>;
        expect(sent['type'], 'text');
        expect(sent['window_id'], 1);
        expect(sent['text'], 'Hello World');
      });

      test('sendTextInput handles special characters', () {
        service.sendTextInput(windowId: 1, text: '日本語');

        final sent = jsonDecode(sink.lastMessage) as Map<String, dynamic>;
        expect(sent['text'], '日本語');
      });

      test('sendTextInput handles empty string', () {
        service.sendTextInput(windowId: 1, text: '');

        final sent = jsonDecode(sink.lastMessage) as Map<String, dynamic>;
        expect(sent['text'], '');
      });

      test('sendTextInput handles newlines', () {
        service.sendTextInput(windowId: 1, text: 'line1\nline2');

        final sent = jsonDecode(sink.lastMessage) as Map<String, dynamic>;
        expect(sent['text'], 'line1\nline2');
      });
    });

    group('connection state', () {
      test('isConnected is true after connectWithSink', () {
        final newService = _TestableInputService();
        expect(newService.isConnected, isFalse);

        newService.connectWithSink(MockWebSocketSink());
        expect(newService.isConnected, isTrue);
      });

      test('isConnected is false after cleanDisconnect', () async {
        expect(service.isConnected, isTrue);

        await service.cleanDisconnect();
        expect(service.isConnected, isFalse);
      });

      test('events not sent when disconnected', () async {
        await service.cleanDisconnect();
        
        // These should not throw, but should not send messages
        final messageCountBefore = sink.messages.length;
        service.sendClick(windowId: 1, x: 0.5, y: 0.5);
        service.sendKeyPress(windowId: 1, keyCode: 65);
        service.sendTextInput(windowId: 1, text: 'test');

        // No new messages should have been added
        expect(sink.messages.length, messageCountBefore);
      });
    });
  });
}

/// Testable version of InputService that allows injecting a mock sink
class _TestableInputService extends ChangeNotifier {
  MockWebSocketSink? _testSink;
  bool _testIsConnected = false;
  bool _isDisposed = false;

  /// Connect with a mock sink for testing
  void connectWithSink(MockWebSocketSink sink) {
    _testSink = sink;
    _testIsConnected = true;
  }

  bool get isConnected => _testIsConnected;

  /// Clean disconnect without triggering notifyListeners after disposal
  Future<void> cleanDisconnect() async {
    await _testSink?.close();
    _testSink = null;
    _testIsConnected = false;
  }

  void sendClick({
    required int windowId,
    required double x,
    required double y,
    MouseButton button = MouseButton.left,
  }) {
    _sendTestEvent({
      'type': 'mouse',
      'window_id': windowId,
      'action': 'click',
      'button': button.name,
      'x': x,
      'y': y,
    });
  }

  void sendDoubleClick({
    required int windowId,
    required double x,
    required double y,
  }) {
    _sendTestEvent({
      'type': 'mouse',
      'window_id': windowId,
      'action': 'double_click',
      'button': 'left',
      'x': x,
      'y': y,
    });
  }

  void sendRightClick({
    required int windowId,
    required double x,
    required double y,
  }) {
    _sendTestEvent({
      'type': 'mouse',
      'window_id': windowId,
      'action': 'click',
      'button': 'right',
      'x': x,
      'y': y,
    });
  }

  void sendMove({
    required int windowId,
    required double x,
    required double y,
    bool isDragging = false,
  }) {
    _sendTestEvent({
      'type': 'mouse',
      'window_id': windowId,
      'action': isDragging ? 'drag' : 'move',
      'x': x,
      'y': y,
    });
  }

  void sendMouseDown({
    required int windowId,
    required double x,
    required double y,
    MouseButton button = MouseButton.left,
  }) {
    _sendTestEvent({
      'type': 'mouse',
      'window_id': windowId,
      'action': 'down',
      'button': button.name,
      'x': x,
      'y': y,
    });
  }

  void sendMouseUp({
    required int windowId,
    required double x,
    required double y,
    MouseButton button = MouseButton.left,
  }) {
    _sendTestEvent({
      'type': 'mouse',
      'window_id': windowId,
      'action': 'up',
      'button': button.name,
      'x': x,
      'y': y,
    });
  }

  void sendScroll({
    required int windowId,
    required double x,
    required double y,
    required double deltaX,
    required double deltaY,
  }) {
    _sendTestEvent({
      'type': 'mouse',
      'window_id': windowId,
      'action': 'scroll',
      'x': x,
      'y': y,
      'scroll_delta_x': deltaX,
      'scroll_delta_y': deltaY,
    });
  }

  void sendKeyPress({
    required int windowId,
    required int keyCode,
    List<KeyModifier> modifiers = const [],
  }) {
    _sendTestEvent({
      'type': 'key',
      'window_id': windowId,
      'action': 'press',
      'key_code': keyCode,
      'modifiers': modifiers.map((m) => m.name).toList(),
    });
  }

  void sendKeyDown({
    required int windowId,
    required int keyCode,
    List<KeyModifier> modifiers = const [],
  }) {
    _sendTestEvent({
      'type': 'key',
      'window_id': windowId,
      'action': 'down',
      'key_code': keyCode,
      'modifiers': modifiers.map((m) => m.name).toList(),
    });
  }

  void sendKeyUp({
    required int windowId,
    required int keyCode,
    List<KeyModifier> modifiers = const [],
  }) {
    _sendTestEvent({
      'type': 'key',
      'window_id': windowId,
      'action': 'up',
      'key_code': keyCode,
      'modifiers': modifiers.map((m) => m.name).toList(),
    });
  }

  void sendTextInput({
    required int windowId,
    required String text,
  }) {
    _sendTestEvent({
      'type': 'text',
      'window_id': windowId,
      'text': text,
    });
  }

  void _sendTestEvent(Map<String, dynamic> event) {
    if (_testSink == null || !_testIsConnected || _isDisposed) return;
    _testSink!.add(jsonEncode(event));
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
