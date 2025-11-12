import 'package:flutter/cupertino.dart';
import '../../models/chat.dart';
import '../../utils/theme.dart';

/// Navigation bar for ChatDetailScreen
class ChatDetailAppBar extends StatelessWidget implements ObstructingPreferredSizeWidget {
  final Chat chat;
  final int activeJobCount;
  final VoidCallback onRefresh;
  final VoidCallback onShowMenu;
  
  const ChatDetailAppBar({
    super.key,
    required this.chat,
    required this.activeJobCount,
    required this.onRefresh,
    required this.onShowMenu,
  });
  
  Color _getStatusColor(ChatStatus status) {
    return AppTheme.getStatusColor(status.name);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    
    return CupertinoNavigationBar(
      backgroundColor: (isDark ? AppTheme.surfaceDark : AppTheme.surface).withOpacity(0.95),
      border: null,
      middle: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            chat.title,
            style: const TextStyle(fontSize: 17),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: _getStatusColor(chat.status),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                activeJobCount > 0
                    ? '$activeJobCount processing'
                    : chat.status.name,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.normal,
                  color: activeJobCount > 0
                      ? AppTheme.thinkingColor
                      : (isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondary),
                ),
              ),
            ],
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: onRefresh,
            child: Icon(
              CupertinoIcons.refresh,
              color: isDark ? AppTheme.primaryLight : AppTheme.primary,
            ),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: onShowMenu,
            child: Icon(
              CupertinoIcons.ellipsis_circle,
              color: isDark ? AppTheme.primaryLight : AppTheme.primary,
            ),
          ),
        ],
      ),
    );
  }
  
  @override
  Size get preferredSize => const Size.fromHeight(44);
  
  @override
  bool shouldFullyObstruct(BuildContext context) => true;
}

