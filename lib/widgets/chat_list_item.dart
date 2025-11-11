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
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMedium,
        vertical: AppTheme.spacingSmall,
      ),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(
          color: Colors.black.withOpacity(0.05),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingMedium),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        chat.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 17,
                          color: AppTheme.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _buildStatusBadge(),
                  ],
                ),

                const SizedBox(height: AppTheme.spacingSmall),

                // Preview text
                if (chat.preview.isNotEmpty)
                  Text(
                    chat.preview,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
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
                      Icons.message_outlined,
                      '${chat.messageCount}',
                      AppTheme.primary,
                    ),
                    if (chat.totalLinesAdded > 0)
                      _buildStatChip(
                        Icons.add,
                        '+${chat.totalLinesAdded}',
                        AppTheme.activeStatus,
                      ),
                    if (chat.totalLinesRemoved > 0)
                      _buildStatChip(
                        Icons.remove,
                        '-${chat.totalLinesRemoved}',
                        AppTheme.todoColor,
                      ),
                    _buildStatChip(
                      Icons.access_time,
                      _formatTime(chat.lastMessageAt),
                      AppTheme.textTertiary,
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
                          _buildBadge('Archived', Icons.archive),
                        if (chat.isDraft)
                          _buildBadge('Draft', Icons.edit),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
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
        horizontal: AppTheme.spacingSmall,
        vertical: AppTheme.spacingXSmall,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
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
          const SizedBox(width: AppTheme.spacingXSmall),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
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
        horizontal: AppTheme.spacingSmall,
        vertical: AppTheme.spacingXSmall,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: color,
          ),
          const SizedBox(width: AppTheme.spacingXSmall),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
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
