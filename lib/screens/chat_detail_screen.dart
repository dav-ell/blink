import 'package:flutter/material.dart';
import '../models/chat.dart';
import '../services/chat_service.dart';
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
  late Chat _chat;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _chat = widget.chat;
    _loadFullChat();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadFullChat() async {
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
      _scrollToBottom();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading messages: $e')),
        );
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Color _getStatusColor(ChatStatus status) {
    return AppTheme.getStatusColor(status.name);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _chat.title,
              style: const TextStyle(fontSize: 18),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Row(
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
                    fontSize: 12,
                    fontWeight: FontWeight.normal,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadFullChat,
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$value coming soon!')),
              );
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'Export',
                child: Row(
                  children: [
                    Icon(Icons.download, size: 20),
                    SizedBox(width: 12),
                    Text('Export chat'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'Share',
                child: Row(
                  children: [
                    Icon(Icons.share, size: 20),
                    SizedBox(width: 12),
                    Text('Share'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'Archive',
                child: Row(
                  children: [
                    Icon(Icons.archive, size: 20),
                    SizedBox(width: 12),
                    Text('Archive'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Chat statistics header
          _buildStatsHeader(),

          // Messages list
          Expanded(
            child: _chat.messages.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: _loadFullChat,
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                        vertical: AppTheme.spacingMedium,
                      ),
                      itemCount: _chat.messages.length,
                      itemBuilder: (context, index) {
                        return MessageBubble(message: _chat.messages[index]);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsHeader() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMedium),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildStatItem(
            Icons.message_outlined,
            '${_chat.messageCount}',
            'Messages',
            AppTheme.primary,
          ),
          if (_chat.totalLinesAdded > 0 || _chat.totalLinesRemoved > 0) ...[
            const SizedBox(width: AppTheme.spacingMedium),
            _buildStatItem(
              Icons.add,
              '+${_chat.totalLinesAdded}',
              'Added',
              AppTheme.activeStatus,
            ),
            const SizedBox(width: AppTheme.spacingMedium),
            _buildStatItem(
              Icons.remove,
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
            Icons.memory,
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_outlined,
            size: 64,
            color: AppTheme.textTertiary,
          ),
          const SizedBox(height: AppTheme.spacingMedium),
          const Text(
            'No messages yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: AppTheme.spacingSmall),
          Text(
            _isLoading ? 'Loading...' : 'Start a conversation in Cursor IDE',
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
