import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:provider/provider.dart';
import '../../models/chat.dart';
import '../../utils/theme.dart';
import '../../widgets/chat_list_item.dart';
import '../../providers/chat_provider.dart';

/// Content area for ChatListScreen
/// Handles loading, empty, and list states
class ChatListContent extends StatelessWidget {
  final void Function(Chat chat) onChatTap;
  
  const ChatListContent({
    super.key,
    required this.onChatTap,
  });

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    
    if (chatProvider.isLoading) {
      return _buildLoadingState(context);
    }
    
    if (chatProvider.filteredChats.isEmpty) {
      return _buildEmptyState(context, chatProvider);
    }
    
    return _buildChatList(context, chatProvider);
  }
  
  Widget _buildLoadingState(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.spacingMedium),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
          highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
          child: Container(
            margin: const EdgeInsets.only(bottom: AppTheme.spacingMedium),
            height: 120,
            decoration: BoxDecoration(
              color: isDark ? AppTheme.surfaceDark : Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildEmptyState(BuildContext context, ChatProvider chatProvider) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondary;
    
    final hasFilters = chatProvider.searchQuery.isNotEmpty;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasFilters
                ? CupertinoIcons.search
                : CupertinoIcons.chat_bubble,
            size: 64,
            color: textColor.withOpacity(0.5),
          ),
          const SizedBox(height: AppTheme.spacingMedium),
          Text(
            hasFilters
                ? 'No chats found'
                : 'No chats yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(height: AppTheme.spacingSmall),
          Text(
            hasFilters
                ? 'Try adjusting your search'
                : chatProvider.isConnected
                    ? 'Start a conversation in Cursor IDE'
                    : 'Unable to connect to API',
            style: TextStyle(
              fontSize: 14,
              color: textColor.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
          if (!chatProvider.isConnected) ...[
            const SizedBox(height: AppTheme.spacingLarge),
            CupertinoButton.filled(
              onPressed: () => chatProvider.loadChats(forceRefresh: true),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(CupertinoIcons.refresh, size: 20),
                  SizedBox(width: 8),
                  Text('Retry Connection'),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildChatList(BuildContext context, ChatProvider chatProvider) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        CupertinoSliverRefreshControl(
          onRefresh: () => chatProvider.loadChats(forceRefresh: true),
        ),
        SliverPadding(
          padding: const EdgeInsets.only(
            top: AppTheme.spacingSmall,
            bottom: AppTheme.spacingXLarge,
          ),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final chat = chatProvider.filteredChats[index];
                return ChatListItem(
                  chat: chat,
                  onTap: () => onChatTap(chat),
                );
              },
              childCount: chatProvider.filteredChats.length,
            ),
          ),
        ),
      ],
    );
  }
}

