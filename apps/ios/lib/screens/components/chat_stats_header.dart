import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../models/chat.dart';
import '../../utils/theme.dart';

/// Statistics header for ChatDetailScreen
class ChatStatsHeader extends StatelessWidget {
  final Chat chat;
  
  const ChatStatsHeader({
    super.key,
    required this.chat,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMedium),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : AppTheme.surface,
        border: Border(
          bottom: BorderSide(
            color: (isDark ? Colors.white : Colors.black).withOpacity(0.1),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          _buildStatItem(
            CupertinoIcons.chat_bubble,
            '${chat.messageCount}',
            'Messages',
            AppTheme.primary,
          ),
          if (chat.totalLinesAdded > 0 || chat.totalLinesRemoved > 0) ...[
            const SizedBox(width: AppTheme.spacingMedium),
            _buildStatItem(
              CupertinoIcons.plus,
              '+${chat.totalLinesAdded}',
              'Added',
              AppTheme.activeStatus,
            ),
            const SizedBox(width: AppTheme.spacingMedium),
            _buildStatItem(
              CupertinoIcons.minus,
              '-${chat.totalLinesRemoved}',
              'Removed',
              AppTheme.todoColor,
            ),
          ],
          if (chat.contextUsagePercent != null) ...[
            const Spacer(),
            _buildContextUsage(chat.contextUsagePercent!),
          ],
        ],
      ),
    );
  }
  
  Widget _buildStatItem(
    IconData icon,
    String value,
    String label,
    Color color,
  ) {
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
          Icon(icon, size: 16, color: color),
          const SizedBox(width: AppTheme.spacingXSmall),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: color.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildContextUsage(double percentage) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingSmall,
        vertical: AppTheme.spacingXSmall,
      ),
      decoration: BoxDecoration(
        color: AppTheme.thinkingColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            CupertinoIcons.gauge,
            size: 16,
            color: AppTheme.thinkingColor,
          ),
          const SizedBox(width: AppTheme.spacingXSmall),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${percentage.toStringAsFixed(1)}%',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.thinkingColor,
                ),
              ),
              Text(
                'Context',
                style: TextStyle(
                  fontSize: 10,
                  color: AppTheme.thinkingColor.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

