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

  @override
  Widget build(BuildContext context) {
    if (renderer == null || renderer!.srcObject == null) {
      if (showPlaceholder) {
        return _buildPlaceholder();
      }
      return const SizedBox.shrink();
    }

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

