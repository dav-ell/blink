import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/server.dart';

// #region agent log
void _debugLogInput(String location, String message, Map<String, dynamic> data, String hypothesisId) {
  try {
    final logEntry = jsonEncode({
      'location': location,
      'message': message,
      'data': data,
      'hypothesisId': hypothesisId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'sessionId': 'debug-session',
    });
    File('/Users/davell/Documents/github/blink/.cursor/debug.log')
        .writeAsStringSync('$logEntry\n', mode: FileMode.append, flush: true);
  } catch (_) {}
}
// #endregion

/// Service for sending input events to the stream server
class InputService extends ChangeNotifier {
  WebSocketChannel? _channel;
  bool _isConnected = false;

  bool get isConnected => _isConnected;

  /// Connect to the input WebSocket
  Future<void> connect(StreamServer server) async {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(server.inputUrl));
      _isConnected = true;
      notifyListeners();
      
      // Listen for errors
      _channel!.stream.listen(
        (data) {
          // Handle any responses from server
          debugPrint('Input response: $data');
        },
        onError: (error) {
          debugPrint('Input error: $error');
          _isConnected = false;
          notifyListeners();
        },
        onDone: () {
          _isConnected = false;
          notifyListeners();
        },
      );
    } catch (e) {
      debugPrint('Failed to connect input channel: $e');
      _isConnected = false;
      notifyListeners();
    }
  }

  /// Disconnect from the input WebSocket
  Future<void> disconnect() async {
    await _channel?.sink.close();
    _channel = null;
    _isConnected = false;
    notifyListeners();
  }

  /// Send a mouse click event
  void sendClick({
    required int windowId,
    required double x,
    required double y,
    MouseButton button = MouseButton.left,
  }) {
    _sendEvent({
      'type': 'mouse',
      'window_id': windowId,
      'action': 'click',
      'button': button.name,
      'x': x,
      'y': y,
    });
  }

  /// Send a double click event
  void sendDoubleClick({
    required int windowId,
    required double x,
    required double y,
  }) {
    _sendEvent({
      'type': 'mouse',
      'window_id': windowId,
      'action': 'double_click',
      'button': 'left',
      'x': x,
      'y': y,
    });
  }

  /// Send a right click event
  void sendRightClick({
    required int windowId,
    required double x,
    required double y,
  }) {
    _sendEvent({
      'type': 'mouse',
      'window_id': windowId,
      'action': 'click',
      'button': 'right',
      'x': x,
      'y': y,
    });
  }

  /// Send a mouse move event
  void sendMove({
    required int windowId,
    required double x,
    required double y,
    bool isDragging = false,
  }) {
    _sendEvent({
      'type': 'mouse',
      'window_id': windowId,
      'action': isDragging ? 'drag' : 'move',
      'x': x,
      'y': y,
    });
  }

  /// Send a mouse down event (for drag start)
  void sendMouseDown({
    required int windowId,
    required double x,
    required double y,
    MouseButton button = MouseButton.left,
  }) {
    _sendEvent({
      'type': 'mouse',
      'window_id': windowId,
      'action': 'down',
      'button': button.name,
      'x': x,
      'y': y,
    });
  }

  /// Send a mouse up event (for drag end)
  void sendMouseUp({
    required int windowId,
    required double x,
    required double y,
    MouseButton button = MouseButton.left,
  }) {
    _sendEvent({
      'type': 'mouse',
      'window_id': windowId,
      'action': 'up',
      'button': button.name,
      'x': x,
      'y': y,
    });
  }

  /// Send a scroll event
  void sendScroll({
    required int windowId,
    required double x,
    required double y,
    required double deltaX,
    required double deltaY,
  }) {
    _sendEvent({
      'type': 'mouse',
      'window_id': windowId,
      'action': 'scroll',
      'x': x,
      'y': y,
      'scroll_delta_x': deltaX,
      'scroll_delta_y': deltaY,
    });
  }

  /// Send a key press event
  void sendKeyPress({
    required int windowId,
    required int keyCode,
    List<KeyModifier> modifiers = const [],
  }) {
    _sendEvent({
      'type': 'key',
      'window_id': windowId,
      'action': 'press',
      'key_code': keyCode,
      'modifiers': modifiers.map((m) => m.name).toList(),
    });
  }

  /// Send a key down event
  void sendKeyDown({
    required int windowId,
    required int keyCode,
    List<KeyModifier> modifiers = const [],
  }) {
    _sendEvent({
      'type': 'key',
      'window_id': windowId,
      'action': 'down',
      'key_code': keyCode,
      'modifiers': modifiers.map((m) => m.name).toList(),
    });
  }

  /// Send a key up event
  void sendKeyUp({
    required int windowId,
    required int keyCode,
    List<KeyModifier> modifiers = const [],
  }) {
    _sendEvent({
      'type': 'key',
      'window_id': windowId,
      'action': 'up',
      'key_code': keyCode,
      'modifiers': modifiers.map((m) => m.name).toList(),
    });
  }

  /// Send text input (for typing)
  void sendTextInput({
    required int windowId,
    required String text,
  }) {
    _sendEvent({
      'type': 'text',
      'window_id': windowId,
      'text': text,
    });
  }

  void _sendEvent(Map<String, dynamic> event) {
    // #region agent log
    _debugLogInput('input_service.dart:_sendEvent', 'Sending event', {
      'eventType': event['type'],
      'channelNull': _channel == null,
      'isConnected': _isConnected,
      'event': event,
    }, 'D');
    // #endregion
    
    if (_channel == null || !_isConnected) {
      // #region agent log
      _debugLogInput('input_service.dart:_sendEvent:blocked', 'Event blocked - not connected', {
        'channelNull': _channel == null,
        'isConnected': _isConnected,
        'eventType': event['type'],
      }, 'D');
      // #endregion
      debugPrint('Cannot send event: not connected');
      return;
    }

    try {
      _channel!.sink.add(jsonEncode(event));
      // #region agent log
      _debugLogInput('input_service.dart:_sendEvent:sent', 'Event sent successfully', {
        'eventType': event['type'],
      }, 'D');
      // #endregion
    } catch (e) {
      // #region agent log
      _debugLogInput('input_service.dart:_sendEvent:error', 'Failed to send event', {
        'error': e.toString(),
        'eventType': event['type'],
      }, 'D');
      // #endregion
      debugPrint('Failed to send event: $e');
    }
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}

/// Mouse button types
enum MouseButton {
  left,
  right,
  middle,
}

/// Keyboard modifiers
enum KeyModifier {
  cmd,
  ctrl,
  alt,
  shift,
}

