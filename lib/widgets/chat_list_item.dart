import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/chat.dart';
import '../utils/theme.dart';

class ChatListItem extends StatelessWidget {
  final Chat chat;
  final VoidCallback onTap;

  const ChatListItem({
    super.key,
    required this.chat,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingMedium,
          vertical: AppTheme.spacingSmall,
        ),
        padding: const EdgeInsets.all(AppTheme.spacingMedium),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.surfaceDark : AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: (isDark ? Colors.white : Colors.black).withOpacity(0.08),
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                Expanded(
                  child: Text(
                    chat.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 17,
                      color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _buildStatusBadge(isDark),
              ],
            ),

            const SizedBox(height: AppTheme.spacingSmall),

            // Preview text
            if (chat.preview.isNotEmpty)
              Text(
                chat.preview,
                style: TextStyle(
                  fontSize: 15,
                  color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondary,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

            const SizedBox(height: AppTheme.spacingMedium),

            // Stats Row
            Wrap(
              spacing: AppTheme.spacingMedium,
              runSpacing: AppTheme.spacingXSmall,
              children: [
                _buildStatChip(
                  CupertinoIcons.chat_bubble,
                  '${chat.messageCount}',
                  AppTheme.primary,
                ),
                if (chat.totalLinesAdded > 0)
                  _buildStatChip(
                    CupertinoIcons.plus,
                    '+${chat.totalLinesAdded}',
                    AppTheme.activeStatus,
                  ),
                if (chat.totalLinesRemoved > 0)
                  _buildStatChip(
                    CupertinoIcons.minus,
                    '-${chat.totalLinesRemoved}',
                    AppTheme.todoColor,
                  ),
                _buildStatChip(
                  CupertinoIcons.time,
                  _formatTime(chat.lastMessageAt),
                  isDark ? AppTheme.textTertiaryDark : AppTheme.textTertiary,
                ),
              ],
            ),

            // Archive/Draft badges
            if (chat.isArchived || chat.isDraft)
              Padding(
                padding: const EdgeInsets.only(top: AppTheme.spacingSmall),
                child: Row(
                  children: [
                    if (chat.isArchived)
                      _buildBadge('Archived', CupertinoIcons.archivebox),
                    if (chat.isDraft)
                      _buildBadge('Draft', CupertinoIcons.pencil),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(bool isDark) {
    Color color;
    String label;

    switch (chat.status) {
      case ChatStatus.active:
        color = AppTheme.activeStatus;
        label = 'Active';
        break;
      case ChatStatus.inactive:
        color = AppTheme.inactiveStatus;
        label = 'Inactive';
        break;
      case ChatStatus.completed:
        color = AppTheme.completedStatus;
        label = 'Completed';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String label, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(right: AppTheme.spacingSmall),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingSmall,
        vertical: AppTheme.spacingXSmall,
      ),
      decoration: BoxDecoration(
        color: AppTheme.archivedStatus.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: AppTheme.archivedStatus,
          ),
          const SizedBox(width: AppTheme.spacingXSmall),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.archivedStatus,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 7) {
      return DateFormat('MMM d').format(timestamp);
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
