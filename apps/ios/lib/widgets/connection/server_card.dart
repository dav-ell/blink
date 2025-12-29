import 'package:flutter/cupertino.dart';
import '../../theme/remote_theme.dart';
import '../../theme/glassmorphism.dart';
import '../../models/server.dart';

/// Card displaying a discovered or saved server
class ServerCard extends StatelessWidget {
  final StreamServer server;
  final VoidCallback? onTap;
  final bool isConnecting;

  const ServerCard({
    super.key,
    required this.server,
    this.onTap,
    this.isConnecting = false,
  });

  @override
  Widget build(BuildContext context) {
    return GlassButton(
      onPressed: isConnecting ? null : onTap,
      padding: const EdgeInsets.all(RemoteTheme.spacingMD),
      borderRadius: RemoteTheme.radiusLG,
      child: Row(
        children: [
          // Server icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: RemoteTheme.surfaceElevated,
              borderRadius: BorderRadius.circular(RemoteTheme.radiusMD),
            ),
            child: Icon(
              server.isManualEntry
                  ? CupertinoIcons.link
                  : CupertinoIcons.desktopcomputer,
              color: RemoteTheme.accent,
              size: 24,
            ),
          ),
          
          const SizedBox(width: RemoteTheme.spacingMD),
          
          // Server info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  server.name,
                  style: RemoteTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  server.displayAddress,
                  style: RemoteTheme.caption,
                ),
                if (server.version != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'v${server.version}',
                    style: RemoteTheme.caption.copyWith(
                      color: RemoteTheme.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          // Status indicator
          if (isConnecting)
            const CupertinoActivityIndicator()
          else
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: RemoteTheme.connected,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: RemoteTheme.connected.withOpacity(0.5),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

