import 'package:flutter/foundation.dart';
import '../models/remote_window.dart';
import '../services/stream_service.dart';

/// Provider for managing window selection and state
class WindowsProvider extends ChangeNotifier {
  final StreamService _streamService;

  WindowsProvider({required StreamService streamService})
      : _streamService = streamService {
    _streamService.addListener(_onStreamChanged);
  }

  /// Available windows from server
  List<RemoteWindow> get availableWindows => _streamService.state.availableWindows;

  /// Currently subscribed/streaming windows
  List<RemoteWindow> get subscribedWindows => _streamService.state.subscribedWindows;

  /// Currently active window
  RemoteWindow? get activeWindow => _streamService.state.activeWindow;

  /// Active window ID
  String? get activeWindowId => _streamService.state.activeWindowId;

  /// Subscribe to selected windows
  Future<void> subscribeToWindows(List<int> windowIds) async {
    await _streamService.subscribeToWindows(windowIds);
  }

  /// Set the active window
  void setActiveWindow(String windowId) {
    _streamService.setActiveWindow(windowId);
  }

  /// Switch to next window (for swipe gestures)
  void nextWindow() {
    final windows = subscribedWindows;
    if (windows.isEmpty) return;

    final currentIndex = windows.indexWhere(
      (w) => w.id.toString() == activeWindowId,
    );
    
    final nextIndex = (currentIndex + 1) % windows.length;
    setActiveWindow(windows[nextIndex].id.toString());
  }

  /// Switch to previous window (for swipe gestures)
  void previousWindow() {
    final windows = subscribedWindows;
    if (windows.isEmpty) return;

    final currentIndex = windows.indexWhere(
      (w) => w.id.toString() == activeWindowId,
    );
    
    final prevIndex = currentIndex <= 0 ? windows.length - 1 : currentIndex - 1;
    setActiveWindow(windows[prevIndex].id.toString());
  }

  void _onStreamChanged() {
    notifyListeners();
  }

  @override
  void dispose() {
    _streamService.removeListener(_onStreamChanged);
    super.dispose();
  }
}

