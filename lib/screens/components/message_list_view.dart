import 'package:flutter/cupertino.dart';
import '../../models/message.dart';
import '../../utils/theme.dart';
import '../../widgets/message_bubble.dart';

/// Message list view with scroll controller and empty state
class MessageListView extends StatelessWidget {
  final List<Message> messages;
  final ScrollController scrollController;
  final Future<void> Function() onRefresh;
  final void Function(Message)? onRetry;
  final bool isLoading;
  
  const MessageListView({
    super.key,
    required this.messages,
    required this.scrollController,
    required this.onRefresh,
    this.onRetry,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty && !isLoading) {
      return _buildEmptyState(context);
    }
    
    return CustomScrollView(
      controller: scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        CupertinoSliverRefreshControl(
          onRefresh: onRefresh,
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(
            vertical: AppTheme.spacingMedium,
          ),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final message = messages[index];
                return MessageBubble(
                  message: message,
                  onRetry: message.isFailed && message.role == MessageRole.user && onRetry != null
                      ? () => onRetry!(message)
                      : null,
                );
              },
              childCount: messages.length,
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildEmptyState(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondary;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.chat_bubble_2,
            size: 64,
            color: textColor.withOpacity(0.5),
          ),
          const SizedBox(height: AppTheme.spacingMedium),
          Text(
            'This is a new chat',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(height: AppTheme.spacingSmall),
          Text(
            isLoading 
                ? 'Loading...' 
                : 'Send a message to start the conversation!',
            style: TextStyle(
              fontSize: 14,
              color: textColor.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}

