import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/message.dart';
import '../utils/theme.dart';
import 'content_type_badge.dart';

class MessageBubble extends StatelessWidget {
  final Message message;

  const MessageBubble({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == MessageRole.user;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingMedium,
          vertical: AppTheme.spacingSmall,
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.80,
        ),
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Content type badges
            if (_hasContentTypes())
              Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.spacingXSmall),
                child: Wrap(
                  spacing: AppTheme.spacingXSmall,
                  runSpacing: AppTheme.spacingXSmall,
                  children: _buildContentBadges(),
                ),
              ),

            // Message bubble
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingMedium),
              decoration: BoxDecoration(
                gradient: isUser
                    ? const LinearGradient(
                        colors: [AppTheme.userMessageBg, AppTheme.primaryLight],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : AppTheme.assistantGradient,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(AppTheme.radiusLarge),
                  topRight: const Radius.circular(AppTheme.radiusLarge),
                  bottomLeft: Radius.circular(
                      isUser ? AppTheme.radiusLarge : AppTheme.radiusSmall),
                  bottomRight: Radius.circular(
                      isUser ? AppTheme.radiusSmall : AppTheme.radiusLarge),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Assistant label
                  if (!isUser)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.smart_toy,
                            size: 14,
                            color: AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Cursor Assistant',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Message text
                  if (message.content.isNotEmpty)
                    SelectableText(
                      message.content,
                      style: TextStyle(
                        color: isUser ? Colors.white : AppTheme.textPrimary,
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),

                  // Timestamp
                  const SizedBox(height: AppTheme.spacingSmall),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 11,
                        color: isUser
                            ? Colors.white.withOpacity(0.7)
                            : AppTheme.textTertiary,
                      ),
                      const SizedBox(width: AppTheme.spacingXSmall),
                      Text(
                        _formatTime(message.timestamp),
                        style: TextStyle(
                          color: isUser
                              ? Colors.white.withOpacity(0.7)
                              : AppTheme.textTertiary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _hasContentTypes() {
    return message.hasCode ||
        message.hasTodos ||
        message.hasToolCall ||
        message.hasThinking;
  }

  List<Widget> _buildContentBadges() {
    final badges = <Widget>[];

    if (message.hasCode) {
      badges.add(const ContentTypeBadge(type: 'code', small: true));
    }
    if (message.hasTodos) {
      badges.add(const ContentTypeBadge(type: 'todo', small: true));
    }
    if (message.hasToolCall) {
      badges.add(const ContentTypeBadge(type: 'tool', small: true));
    }
    if (message.hasThinking) {
      badges.add(const ContentTypeBadge(type: 'thinking', small: true));
    }

    return badges;
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return DateFormat('MMM d, h:mm a').format(timestamp);
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
