import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../utils/theme.dart';

/// Floating action button for creating new chats
class ChatListFab extends StatelessWidget {
  final VoidCallback onPressed;
  
  const ChatListFab({
    super.key,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    
    return Positioned(
      right: 16,
      bottom: 16,
      child: CupertinoButton(
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: isDark ? AppTheme.primaryLight : AppTheme.primary,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            CupertinoIcons.add,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
    );
  }
}

