import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/message.dart';
import '../utils/theme.dart';
import 'content_type_badge.dart';
import 'tool_call_box.dart';
import 'thinking_box.dart';
import 'expandable_content.dart';
import 'processing_indicator.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final VoidCallback? onRetry;

  const MessageBubble({
    super.key,
    required this.message,
    this.onRetry,
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
            // Tool call boxes (shown before message bubble)
            if (message.toolCalls != null && message.toolCalls!.isNotEmpty)
              ...message.toolCalls!.map((toolCall) => ToolCallBox(
                    toolCall: toolCall,
                  )),

            // Thinking/reasoning box (shown before message bubble)
            if (message.thinkingContent != null &&
                message.thinkingContent!.isNotEmpty)
              ThinkingBox(content: message.thinkingContent!),

            // Content type badges (if using old format)
            if (_hasContentTypes())
              Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.spacingXSmall),
                child: Wrap(
                  spacing: AppTheme.spacingXSmall,
                  runSpacing: AppTheme.spacingXSmall,
                  children: _buildContentBadges(),
                ),
              ),

            // Processing indicator (for pending/processing messages)
            if (message.isProcessing)
              Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.spacingXSmall),
                child: ProcessingIndicator(
                  elapsedSeconds: message.getElapsedSeconds(),
                  isPending: message.status == MessageStatus.pending,
                ),
              ),

            // Message bubble (only shown if there's text content)
            if (message.content.isNotEmpty)
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
                              CupertinoIcons.sparkles,
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

                    // Message text with markdown and expandable support
                    ExpandableContent(
                      content: message.content,
                      isUserMessage: isUser,
                      maxLines: 10,
                    ),

                    // Error message for failed messages
                    if (message.isFailed && message.errorMessage != null) ...[
                      const SizedBox(height: AppTheme.spacingSmall),
                      Container(
                        padding: const EdgeInsets.all(AppTheme.spacingSmall),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                          border: Border.all(
                            color: Colors.red.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  CupertinoIcons.exclamationmark_circle,
                                  size: 14,
                                  color: Colors.red,
                                ),
                                const SizedBox(width: AppTheme.spacingXSmall),
                                Expanded(
                                  child: Text(
                                    message.errorMessage!,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.red.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (onRetry != null && isUser) ...[
                              const SizedBox(height: AppTheme.spacingXSmall),
                              GestureDetector(
                                onTap: onRetry,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppTheme.spacingSmall,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(
                                        CupertinoIcons.arrow_clockwise,
                                        size: 12,
                                        color: Colors.white,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'Retry',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],

                    // Timestamp and status
                    const SizedBox(height: AppTheme.spacingSmall),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getStatusIcon(),
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

  IconData _getStatusIcon() {
    switch (message.status) {
      case MessageStatus.pending:
        return CupertinoIcons.clock;
      case MessageStatus.sending:
        return CupertinoIcons.arrow_up_circle;
      case MessageStatus.processing:
        return CupertinoIcons.hourglass;
      case MessageStatus.completed:
        return CupertinoIcons.time;
      case MessageStatus.failed:
        return CupertinoIcons.exclamationmark_circle;
    }
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
