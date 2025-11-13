import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../utils/theme.dart';
import '../../providers/theme_provider.dart';
import '../../providers/chat_provider.dart';
import '../settings_screen.dart';

/// Header for ChatListScreen with connection status, refresh, and theme toggle
class ChatListHeader extends StatelessWidget implements ObstructingPreferredSizeWidget {
  const ChatListHeader({super.key});

  void _navigateToSettings(BuildContext context) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => const SettingsScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final chatProvider = context.watch<ChatProvider>();
    final themeProvider = context.watch<ThemeProvider>();

    return CupertinoNavigationBar(
      backgroundColor: (isDark ? AppTheme.surfaceDark : AppTheme.surface).withOpacity(0.95),
      border: null,
      middle: const Text('Cursor Chats'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!chatProvider.isConnected)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.todoColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    CupertinoIcons.wifi_slash,
                    size: 14,
                    color: AppTheme.todoColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Offline',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.todoColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          if (!chatProvider.isConnected)
            const SizedBox(width: 8),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => chatProvider.loadChats(forceRefresh: true),
            child: Icon(
              CupertinoIcons.refresh,
              color: isDark ? AppTheme.primaryLight : AppTheme.primary,
            ),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => themeProvider.toggleTheme(),
            child: Icon(
              themeProvider.isDarkMode
                  ? CupertinoIcons.sun_max
                  : CupertinoIcons.moon,
              color: isDark ? AppTheme.primaryLight : AppTheme.primary,
            ),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => _navigateToSettings(context),
            child: Icon(
              CupertinoIcons.settings,
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

