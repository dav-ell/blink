import 'server.dart';
import 'remote_window.dart';

/// Overall connection state for the streaming session
class StreamConnectionState {
  final ConnectionPhase phase;
  final StreamServer? server;
  final List<RemoteWindow> availableWindows;
  final List<RemoteWindow> subscribedWindows;
  final String? activeWindowId;
  final String? error;
  final DateTime? connectedAt;

  const StreamConnectionState({
    this.phase = ConnectionPhase.disconnected,
    this.server,
    this.availableWindows = const [],
    this.subscribedWindows = const [],
    this.activeWindowId,
    this.error,
    this.connectedAt,
  });

  /// Initial disconnected state
  static const StreamConnectionState initial = StreamConnectionState();

  /// Whether we're in a connected state
  bool get isConnected => phase == ConnectionPhase.connected;

  /// Whether we're trying to connect
  bool get isConnecting =>
      phase == ConnectionPhase.connecting ||
      phase == ConnectionPhase.authenticating ||
      phase == ConnectionPhase.negotiating;

  /// Whether we have an error
  bool get hasError => error != null;

  /// Duration since connection was established
  Duration? get connectionDuration {
    if (connectedAt == null) return null;
    return DateTime.now().difference(connectedAt!);
  }

  /// Active window object
  RemoteWindow? get activeWindow {
    if (activeWindowId == null) return null;
    try {
      return subscribedWindows.firstWhere(
        (w) => w.id.toString() == activeWindowId,
      );
    } catch (_) {
      return subscribedWindows.isNotEmpty ? subscribedWindows.first : null;
    }
  }

  StreamConnectionState copyWith({
    ConnectionPhase? phase,
    StreamServer? server,
    List<RemoteWindow>? availableWindows,
    List<RemoteWindow>? subscribedWindows,
    String? activeWindowId,
    String? error,
    DateTime? connectedAt,
    bool clearError = false,
    bool clearServer = false,
  }) {
    return StreamConnectionState(
      phase: phase ?? this.phase,
      server: clearServer ? null : (server ?? this.server),
      availableWindows: availableWindows ?? this.availableWindows,
      subscribedWindows: subscribedWindows ?? this.subscribedWindows,
      activeWindowId: activeWindowId ?? this.activeWindowId,
      error: clearError ? null : (error ?? this.error),
      connectedAt: connectedAt ?? this.connectedAt,
    );
  }

  @override
  String toString() => 'StreamConnectionState(phase: $phase, server: ${server?.name})';
}

/// Connection phase enum
enum ConnectionPhase {
  /// Not connected to any server
  disconnected,

  /// Discovering servers via mDNS
  discovering,

  /// Establishing connection to server
  connecting,

  /// Authenticating with pairing code
  authenticating,

  /// Negotiating WebRTC connection
  negotiating,

  /// Fully connected and streaming
  connected,

  /// Reconnecting after connection loss
  reconnecting,

  /// Connection failed
  error,
}

/// Human-readable status messages for each phase
extension ConnectionPhaseExtension on ConnectionPhase {
  String get statusMessage {
    switch (this) {
      case ConnectionPhase.disconnected:
        return 'Not connected';
      case ConnectionPhase.discovering:
        return 'Looking for servers...';
      case ConnectionPhase.connecting:
        return 'Connecting...';
      case ConnectionPhase.authenticating:
        return 'Authenticating...';
      case ConnectionPhase.negotiating:
        return 'Setting up stream...';
      case ConnectionPhase.connected:
        return 'Connected';
      case ConnectionPhase.reconnecting:
        return 'Reconnecting...';
      case ConnectionPhase.error:
        return 'Connection failed';
    }
  }

  bool get showSpinner {
    switch (this) {
      case ConnectionPhase.discovering:
      case ConnectionPhase.connecting:
      case ConnectionPhase.authenticating:
      case ConnectionPhase.negotiating:
      case ConnectionPhase.reconnecting:
        return true;
      default:
        return false;
    }
  }
}

