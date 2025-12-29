import 'package:blink/models/server.dart';
import 'package:blink/models/remote_window.dart';
import 'package:blink/models/connection_state.dart';

/// Factory functions for creating test data

/// Create a test StreamServer with sensible defaults
StreamServer makeServer({
  String? id,
  String name = 'Test Server',
  String host = '192.168.1.100',
  int port = 8080,
  String? version,
  DateTime? lastSeen,
  bool isManualEntry = false,
}) {
  return StreamServer(
    id: id ?? '$host:$port',
    name: name,
    host: host,
    port: port,
    version: version,
    lastSeen: lastSeen ?? DateTime.now(),
    isManualEntry: isManualEntry,
  );
}

/// Create a test RemoteWindow with sensible defaults
RemoteWindow makeWindow({
  int id = 1,
  String title = 'Test Window',
  String appName = 'TestApp',
  double x = 0,
  double y = 0,
  double width = 1920,
  double height = 1080,
  bool isMinimized = false,
  bool isOnScreen = true,
}) {
  return RemoteWindow(
    id: id,
    title: title,
    appName: appName,
    bounds: WindowBounds(x: x, y: y, width: width, height: height),
    isMinimized: isMinimized,
    isOnScreen: isOnScreen,
  );
}

/// Create a StreamConnectionState with sensible defaults
StreamConnectionState makeConnectionState({
  ConnectionPhase phase = ConnectionPhase.disconnected,
  StreamServer? server,
  List<RemoteWindow>? availableWindows,
  List<RemoteWindow>? subscribedWindows,
  String? activeWindowId,
  String? error,
  DateTime? connectedAt,
}) {
  return StreamConnectionState(
    phase: phase,
    server: server,
    availableWindows: availableWindows ?? const [],
    subscribedWindows: subscribedWindows ?? const [],
    activeWindowId: activeWindowId,
    error: error,
    connectedAt: connectedAt,
  );
}

/// Create a window_list message as received from server
Map<String, dynamic> makeWindowListMessage(List<RemoteWindow> windows) {
  return {
    'type': 'window_list',
    'windows': windows.map((w) => w.toJson()).toList(),
  };
}

/// Create a window_closed message as received from server
Map<String, dynamic> makeWindowClosedMessage(int windowId) {
  return {
    'type': 'window_closed',
    'id': windowId,
  };
}

/// Create a subscribe message as sent to server
Map<String, dynamic> makeSubscribeMessage(List<int> windowIds) {
  return {
    'type': 'subscribe',
    'window_ids': windowIds,
  };
}

/// Create an offer message for WebRTC signaling
Map<String, dynamic> makeOfferMessage(String sdp) {
  return {
    'type': 'offer',
    'sdp': sdp,
  };
}

/// Create an answer message for WebRTC signaling
Map<String, dynamic> makeAnswerMessage(String sdp) {
  return {
    'type': 'answer',
    'sdp': sdp,
  };
}

/// Create an ICE candidate message for WebRTC signaling
Map<String, dynamic> makeIceCandidateMessage({
  required String candidate,
  String? sdpMid,
  int? sdpMLineIndex,
}) {
  return {
    'type': 'ice',
    'candidate': {
      'candidate': candidate,
      'sdpMid': sdpMid,
      'sdpMLineIndex': sdpMLineIndex,
    },
  };
}

/// Create a mouse click event as sent to server
Map<String, dynamic> makeClickEvent({
  required int windowId,
  required double x,
  required double y,
  String button = 'left',
}) {
  return {
    'type': 'mouse',
    'window_id': windowId,
    'action': 'click',
    'button': button,
    'x': x,
    'y': y,
  };
}

/// Create a mouse scroll event as sent to server
Map<String, dynamic> makeScrollEvent({
  required int windowId,
  required double x,
  required double y,
  required double deltaX,
  required double deltaY,
}) {
  return {
    'type': 'mouse',
    'window_id': windowId,
    'action': 'scroll',
    'x': x,
    'y': y,
    'scroll_delta_x': deltaX,
    'scroll_delta_y': deltaY,
  };
}

/// Create a key press event as sent to server
Map<String, dynamic> makeKeyPressEvent({
  required int windowId,
  required int keyCode,
  List<String> modifiers = const [],
}) {
  return {
    'type': 'key',
    'window_id': windowId,
    'action': 'press',
    'key_code': keyCode,
    'modifiers': modifiers,
  };
}

/// Create a text input event as sent to server
Map<String, dynamic> makeTextInputEvent({
  required int windowId,
  required String text,
}) {
  return {
    'type': 'text',
    'window_id': windowId,
    'text': text,
  };
}

/// Sample server JSON for testing deserialization
Map<String, dynamic> sampleServerJson({
  String id = '192.168.1.100:8080',
  String name = 'Test Server',
  String host = '192.168.1.100',
  int port = 8080,
  String? version = '1.0.0',
  bool isManualEntry = false,
}) {
  return {
    'id': id,
    'name': name,
    'host': host,
    'port': port,
    'version': version,
    'last_seen': DateTime.now().toIso8601String(),
    'is_manual_entry': isManualEntry,
  };
}

/// Sample window JSON for testing deserialization
Map<String, dynamic> sampleWindowJson({
  int id = 1,
  String title = 'Test Window',
  String app = 'TestApp',
  double x = 0,
  double y = 0,
  double width = 1920,
  double height = 1080,
}) {
  return {
    'id': id,
    'title': title,
    'app': app,
    'bounds': {
      'x': x,
      'y': y,
      'width': width,
      'height': height,
    },
    'is_minimized': false,
    'is_on_screen': true,
  };
}

