import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../services/stream_service.dart';

/// Provider for accessing video renderers
class VideoStreamProvider extends ChangeNotifier {
  final StreamService _streamService;

  VideoStreamProvider({required StreamService streamService})
      : _streamService = streamService {
    _streamService.addListener(_onStreamChanged);
  }

  /// Get all video renderers
  Map<String, RTCVideoRenderer> get renderers => _streamService.renderers;

  /// Get renderer for specific window
  RTCVideoRenderer? getRenderer(String windowId) {
    return _streamService.getRenderer(windowId);
  }

  /// Check if we have a renderer for a window
  bool hasRenderer(String windowId) {
    return _streamService.renderers.containsKey(windowId);
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

