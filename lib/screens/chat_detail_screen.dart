import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../models/chat.dart';
import '../services/chat_service.dart';
import '../services/cursor_agent_service.dart';
import '../widgets/message_bubble.dart';
import '../utils/theme.dart';

class ChatDetailScreen extends StatefulWidget {
  final Chat chat;
  final ChatService chatService;

  const ChatDetailScreen({
    super.key,
    required this.chat,
    required this.chatService,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late Chat _chat;
  late CursorAgentService _agentService;
  bool _isLoading = false;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _chat = widget.chat;
    _agentService = CursorAgentService();
    _loadFullChat();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _messageController.dispose();
    _focusNode.dispose();
    _agentService.dispose();
    super.dispose();
  }

  Future<void> _loadFullChat({bool animateScroll = false}) async {
    setState(() => _isLoading = true);
    try {
      final fullChat = await widget.chatService.fetchChat(
        _chat.id,
        forceRefresh: true,
      );
      setState(() {
        _chat = fullChat;
        _isLoading = false;
      });
      // Scroll to bottom after UI is built
      // Use instant jump for initial load, animation for updates
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _scrollToBottom(animate: animateScroll),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Error'),
            content: Text('Error loading messages: $e'),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      }
    }
  }

  void _scrollToBottom({bool animate = true}) {
    if (_scrollController.hasClients) {
      // Use a slight delay to ensure content is fully laid out
      Future.delayed(const Duration(milliseconds: 50), () {
        if (_scrollController.hasClients) {
          if (animate) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          } else {
            // Jump instantly for initial load (like iMessage)
            _scrollController.jumpTo(
              _scrollController.position.maxScrollExtent,
            );
          }
        }
      });
    }
  }

  Future<void> _sendMessage() async {
    // Validate input
    final message = _messageController.text.trim();
    if (message.isEmpty || _isSending) {
      return;
    }

    // Dismiss keyboard
    _focusNode.unfocus();

    setState(() => _isSending = true);

    try {
      // Send message via cursor-agent
      await _agentService.continueConversation(
        _chat.id,
        message,
        showContext: false,
      );

      // Clear input on success
      _messageController.clear();

      // Reload chat to show new messages with animated scroll
      await _loadFullChat(animateScroll: true);
    } catch (e) {
      // Show error dialog
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Error'),
            content: Text('Failed to send message: $e'),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Color _getStatusColor(ChatStatus status) {
    return AppTheme.getStatusColor(status.name);
  }

  void _showActionSheet(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              showCupertinoDialog(
                context: context,
                builder: (context) => CupertinoAlertDialog(
                  title: const Text('Coming Soon'),
                  content: const Text('Export chat feature is coming soon!'),
                  actions: [
                    CupertinoDialogAction(
                      child: const Text('OK'),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              );
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(CupertinoIcons.arrow_down_doc),
                SizedBox(width: 8),
                Text('Export chat'),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              showCupertinoDialog(
                context: context,
                builder: (context) => CupertinoAlertDialog(
                  title: const Text('Coming Soon'),
                  content: const Text('Share feature is coming soon!'),
                  actions: [
                    CupertinoDialogAction(
                      child: const Text('OK'),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              );
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(CupertinoIcons.share),
                SizedBox(width: 8),
                Text('Share'),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              showCupertinoDialog(
                context: context,
                builder: (context) => CupertinoAlertDialog(
                  title: const Text('Coming Soon'),
                  content: const Text('Archive feature is coming soon!'),
                  actions: [
                    CupertinoDialogAction(
                      child: const Text('OK'),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              );
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(CupertinoIcons.archivebox),
                SizedBox(width: 8),
                Text('Archive'),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;

    return CupertinoPageScaffold(
      backgroundColor: isDark ? AppTheme.backgroundDark : AppTheme.background,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: (isDark ? AppTheme.surfaceDark : AppTheme.surface).withOpacity(0.95),
        border: null,
        middle: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _chat.title,
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
                    color: _getStatusColor(_chat.status),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _chat.status.name,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.normal,
                    color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondary,
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
              onPressed: _loadFullChat,
              child: Icon(
                CupertinoIcons.refresh,
                color: isDark ? AppTheme.primaryLight : AppTheme.primary,
              ),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => _showActionSheet(context),
              child: Icon(
                CupertinoIcons.ellipsis_circle,
                color: isDark ? AppTheme.primaryLight : AppTheme.primary,
              ),
            ),
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Chat statistics header
            _buildStatsHeader(),

            // Messages list
            Expanded(
              child: _chat.messages.isEmpty
                  ? _buildEmptyState()
                  : CustomScrollView(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        CupertinoSliverRefreshControl(
                          onRefresh: _loadFullChat,
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppTheme.spacingMedium,
                          ),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                return MessageBubble(message: _chat.messages[index]);
                              },
                              childCount: _chat.messages.length,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),

            // Message input
            SafeArea(
              top: false,
              child: _buildMessageInput(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsHeader() {
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
            '${_chat.messageCount}',
            'Messages',
            AppTheme.primary,
          ),
          if (_chat.totalLinesAdded > 0 || _chat.totalLinesRemoved > 0) ...[
            const SizedBox(width: AppTheme.spacingMedium),
            _buildStatItem(
              CupertinoIcons.plus,
              '+${_chat.totalLinesAdded}',
              'Added',
              AppTheme.activeStatus,
            ),
            const SizedBox(width: AppTheme.spacingMedium),
            _buildStatItem(
              CupertinoIcons.minus,
              '-${_chat.totalLinesRemoved}',
              'Removed',
              AppTheme.todoColor,
            ),
          ],
          if (_chat.contextUsagePercent != null) ...[
            const Spacer(),
            _buildContextUsage(_chat.contextUsagePercent!),
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

  Widget _buildEmptyState() {
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
            'No messages yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(height: AppTheme.spacingSmall),
          Text(
            _isLoading ? 'Loading...' : 'Start a conversation in Cursor IDE',
            style: TextStyle(
              fontSize: 14,
              color: textColor.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? AppTheme.surfaceDark : AppTheme.surface;
    final borderColor = (isDark ? Colors.white : Colors.black).withOpacity(0.1);
    final canSend = _messageController.text.trim().isNotEmpty && !_isSending;

    return Container(
      padding: const EdgeInsets.only(
        left: AppTheme.spacingMedium,
        right: AppTheme.spacingMedium,
        top: AppTheme.spacingSmall,
        bottom: AppTheme.spacingSmall,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(
          top: BorderSide(
            color: borderColor,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(
                maxHeight: 120,
              ),
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.surfaceLightDark
                    : AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              ),
              child: CupertinoTextField(
                controller: _messageController,
                focusNode: _focusNode,
                placeholder: 'Type a message...',
                placeholderStyle: TextStyle(
                  color: isDark
                      ? AppTheme.textTertiaryDark
                      : AppTheme.textTertiary,
                ),
                style: TextStyle(
                  color: isDark
                      ? AppTheme.textPrimaryDark
                      : AppTheme.textPrimary,
                  fontSize: 16,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingMedium,
                  vertical: AppTheme.spacingSmall,
                ),
                decoration: const BoxDecoration(),
                maxLines: null,
                textInputAction: TextInputAction.newline,
                enabled: !_isSending,
                onChanged: (_) => setState(() {}), // Rebuild to update send button
              ),
            ),
          ),
          const SizedBox(width: AppTheme.spacingSmall),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: canSend ? _sendMessage : null,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: canSend
                    ? (isDark ? AppTheme.primaryLight : AppTheme.primary)
                    : (isDark
                        ? AppTheme.textTertiaryDark
                        : AppTheme.textTertiary),
                shape: BoxShape.circle,
              ),
              child: _isSending
                  ? const CupertinoActivityIndicator(
                      color: Colors.white,
                    )
                  : const Icon(
                      CupertinoIcons.arrow_up,
                      color: Colors.white,
                      size: 20,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
