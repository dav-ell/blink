import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../theme/remote_theme.dart';

/// Wrapper widget for displaying WebRTC video stream
class WindowVideo extends StatelessWidget {
  final RTCVideoRenderer? renderer;
  final bool showPlaceholder;
  final String? windowTitle;

  const WindowVideo({
    super.key,
    required this.renderer,
    this.showPlaceholder = true,
    this.windowTitle,
  });

  // #region agent log
  void _debugLog(String hypothesisId, String location, String message, Map<String, dynamic> data) {
    final payload = {
      'hypothesisId': hypothesisId,
      'location': location,
      'message': message,
      'data': data,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'sessionId': 'debug-session',
    };
    // Fire and forget - use unawaited async to avoid catchError type issues
    () async {
      try {
        final uri = Uri.parse('http://192.168.1.113:7258/ingest/606a0860-3796-4c1f-8a76-f60d9d7088f7');
        final client = HttpClient();
        final req = await client.postUrl(uri);
        req.headers.contentType = ContentType.json;
        req.write(jsonEncode(payload));
        await req.close();
      } catch (_) {}
    }();
  }
  // #endregion

  @override
  Widget build(BuildContext context) {
    // #region agent log
    _debugLog('D', 'window_video:build', 'WindowVideo build called', {
      'has_renderer': renderer != null,
      'has_srcObject': renderer?.srcObject != null,
      'windowTitle': windowTitle,
    });
    // #endregion

    if (renderer == null || renderer!.srcObject == null) {
      if (showPlaceholder) {
        return _buildPlaceholder();
      }
      return const SizedBox.shrink();
    }

    // #region agent log
    _debugLog('D', 'window_video:build', 'Showing RTCVideoView', {
      'renderer_id': renderer.hashCode,
    });
    // #endregion

    return RTCVideoView(
      renderer!,
      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
      filterQuality: FilterQuality.medium,
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: RemoteTheme.surface,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(RemoteTheme.accent),
            ),
            if (windowTitle != null) ...[
              const SizedBox(height: RemoteTheme.spacingMD),
              Text(
                'Loading $windowTitle...',
                style: RemoteTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

