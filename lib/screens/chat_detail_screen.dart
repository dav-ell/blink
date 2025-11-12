import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../models/chat.dart';
import '../models/message.dart';
import '../models/job.dart';
import '../services/chat_service.dart';
import '../services/cursor_agent_service.dart';
import '../services/job_polling_service.dart';
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

class _ChatDetailScreenState extends State<ChatDetailScreen> with WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late Chat _chat;
  late CursorAgentService _agentService;
  late JobPollingService _pollingService;
  bool _isLoading = false;
  bool _isSending = false;
  
  // Track active jobs and pending messages
  final Map<String, Message> _pendingMessages = {}; // jobId -> Message
  Timer? _uiUpdateTimer;
  int _activeJobCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _chat = widget.chat;
    _agentService = CursorAgentService();
    _pollingService = JobPollingService(agentService: _agentService);
    _loadFullChat();
    _startUiUpdateTimer();
    _resumeActiveJobs();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _uiUpdateTimer?.cancel();
    _pollingService.stopAll();
    _scrollController.dispose();
    _messageController.dispose();
    _focusNode.dispose();
    _agentService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Resume polling and refresh when app comes back to foreground
      _resumeActiveJobs();
      _loadFullChat();
    }
  }

  void _startUiUpdateTimer() {
    // Update UI every second to refresh elapsed time
    _uiUpdateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _activeJobCount > 0) {
        setState(() {});
      }
    });
  }

  Future<void> _resumeActiveJobs() async {
    // Check for any active jobs from the backend and resume polling
    try {
      final jobs = await _agentService.listChatJobs(
        _chat.id,
        limit: 10,
        statusFilter: 'processing',
      );
      
      for (final job in jobs) {
        if (job.isProcessing) {
          _startPollingJob(job.jobId);
        }
      }
      
      _updateActiveJobCount();
    } catch (e) {
      // Silently fail - not critical
    }
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
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty || _isSending) {
      return;
    }

    // Dismiss keyboard
    _focusNode.unfocus();

    // Clear input immediately for better UX
    _messageController.clear();

    setState(() => _isSending = true);

    try {
      // Submit prompt asynchronously
      final job = await _agentService.submitPromptAsync(
        _chat.id,
        messageText,
      );

      // Create a pending message to show in UI
      final pendingMessage = Message(
        id: job.jobId,
        bubbleId: '',
        content: messageText,
        role: MessageRole.user,
        timestamp: DateTime.now(),
        type: 1,
        typeLabel: 'user',
        status: MessageStatus.processing,
        jobId: job.jobId,
        sentAt: DateTime.now(),
        processingStartedAt: DateTime.now(),
      );

      // Add to chat messages and pending messages
      setState(() {
        _chat = Chat(
          id: _chat.id,
          title: _chat.title,
          status: _chat.status,
          createdAt: _chat.createdAt,
          lastMessageAt: DateTime.now(),
          messages: [..._chat.messages, pendingMessage],
          isArchived: _chat.isArchived,
          isDraft: _chat.isDraft,
          totalLinesAdded: _chat.totalLinesAdded,
          totalLinesRemoved: _chat.totalLinesRemoved,
          subtitle: _chat.subtitle,
          unifiedMode: _chat.unifiedMode,
          contextUsagePercent: _chat.contextUsagePercent,
        );
        _pendingMessages[job.jobId] = pendingMessage;
      });

      // Scroll to bottom to show new message
      _scrollToBottom(animate: true);

      // Start polling for job status
      _startPollingJob(job.jobId);
      
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

  void _startPollingJob(String jobId) {
    _pollingService.startPolling(
      jobId,
      onUpdate: (job) {
        _handleJobUpdate(job);
      },
      onComplete: (job) {
        _handleJobComplete(job);
      },
      onFailed: (job, error) {
        _handleJobFailed(job, error);
      },
    );
    _updateActiveJobCount();
  }

  void _handleJobUpdate(Job job) {
    if (!mounted) return;
    
    // Update the pending message with latest job info
    setState(() {
      if (_pendingMessages.containsKey(job.jobId)) {
        final message = _pendingMessages[job.jobId]!;
        final updatedMessage = message.copyWith(
          status: job.status == JobStatus.processing
              ? MessageStatus.processing
              : MessageStatus.pending,
          processingStartedAt: job.startedAt,
        );
        
        // Update in messages list
        final index = _chat.messages.indexWhere((m) => m.jobId == job.jobId);
        if (index >= 0) {
          final updatedMessages = List<Message>.from(_chat.messages);
          updatedMessages[index] = updatedMessage;
          _chat = Chat(
            id: _chat.id,
            title: _chat.title,
            status: _chat.status,
            createdAt: _chat.createdAt,
            lastMessageAt: _chat.lastMessageAt,
            messages: updatedMessages,
            isArchived: _chat.isArchived,
            isDraft: _chat.isDraft,
            totalLinesAdded: _chat.totalLinesAdded,
            totalLinesRemoved: _chat.totalLinesRemoved,
            subtitle: _chat.subtitle,
            unifiedMode: _chat.unifiedMode,
            contextUsagePercent: _chat.contextUsagePercent,
          );
          _pendingMessages[job.jobId] = updatedMessage;
        }
      }
    });
  }

  void _handleJobComplete(Job job) {
    if (!mounted) return;
    
    // Remove from pending and reload chat to get the actual messages
    _pendingMessages.remove(job.jobId);
    _updateActiveJobCount();
    _loadFullChat(animateScroll: true);
  }

  void _handleJobFailed(Job job, String error) {
    if (!mounted) return;
    
    // Update the message to show failed status
    setState(() {
      if (_pendingMessages.containsKey(job.jobId)) {
        final message = _pendingMessages[job.jobId]!;
        final updatedMessage = message.copyWith(
          status: MessageStatus.failed,
          completedAt: DateTime.now(),
          errorMessage: error,
        );
        
        // Update in messages list
        final index = _chat.messages.indexWhere((m) => m.jobId == job.jobId);
        if (index >= 0) {
          final updatedMessages = List<Message>.from(_chat.messages);
          updatedMessages[index] = updatedMessage;
          _chat = Chat(
            id: _chat.id,
            title: _chat.title,
            status: _chat.status,
            createdAt: _chat.createdAt,
            lastMessageAt: _chat.lastMessageAt,
            messages: updatedMessages,
            isArchived: _chat.isArchived,
            isDraft: _chat.isDraft,
            totalLinesAdded: _chat.totalLinesAdded,
            totalLinesRemoved: _chat.totalLinesRemoved,
            subtitle: _chat.subtitle,
            unifiedMode: _chat.unifiedMode,
            contextUsagePercent: _chat.contextUsagePercent,
          );
        }
        
        _pendingMessages.remove(job.jobId);
      }
    });
    
    _updateActiveJobCount();
  }

  void _updateActiveJobCount() {
    setState(() {
      _activeJobCount = _pollingService.activeJobIds.length;
    });
  }

  Future<void> _retryMessage(Message failedMessage) async {
    // Remove the failed message
    setState(() {
      _chat = Chat(
        id: _chat.id,
        title: _chat.title,
        status: _chat.status,
        createdAt: _chat.createdAt,
        lastMessageAt: _chat.lastMessageAt,
        messages: _chat.messages.where((m) => m.id != failedMessage.id).toList(),
        isArchived: _chat.isArchived,
        isDraft: _chat.isDraft,
        totalLinesAdded: _chat.totalLinesAdded,
        totalLinesRemoved: _chat.totalLinesRemoved,
        subtitle: _chat.subtitle,
        unifiedMode: _chat.unifiedMode,
        contextUsagePercent: _chat.contextUsagePercent,
      );
    });

    // Retry by submitting the prompt again
    setState(() => _isSending = true);

    try {
      final job = await _agentService.submitPromptAsync(
        _chat.id,
        failedMessage.content,
      );

      // Create a new pending message
      final pendingMessage = Message(
        id: job.jobId,
        bubbleId: '',
        content: failedMessage.content,
        role: MessageRole.user,
        timestamp: DateTime.now(),
        type: 1,
        typeLabel: 'user',
        status: MessageStatus.processing,
        jobId: job.jobId,
        sentAt: DateTime.now(),
        processingStartedAt: DateTime.now(),
      );

      setState(() {
        _chat = Chat(
          id: _chat.id,
          title: _chat.title,
          status: _chat.status,
          createdAt: _chat.createdAt,
          lastMessageAt: DateTime.now(),
          messages: [..._chat.messages, pendingMessage],
          isArchived: _chat.isArchived,
          isDraft: _chat.isDraft,
          totalLinesAdded: _chat.totalLinesAdded,
          totalLinesRemoved: _chat.totalLinesRemoved,
          subtitle: _chat.subtitle,
          unifiedMode: _chat.unifiedMode,
          contextUsagePercent: _chat.contextUsagePercent,
        );
        _pendingMessages[job.jobId] = pendingMessage;
      });

      _scrollToBottom(animate: true);
      _startPollingJob(job.jobId);
      
    } catch (e) {
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Error'),
            content: Text('Failed to retry message: $e'),
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
                  _activeJobCount > 0
                      ? '$_activeJobCount processing'
                      : _chat.status.name,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.normal,
                    color: _activeJobCount > 0
                        ? AppTheme.thinkingColor
                        : (isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondary),
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
                                final message = _chat.messages[index];
                                return MessageBubble(
                                  message: message,
                                  onRetry: message.isFailed && message.role == MessageRole.user
                                      ? () => _retryMessage(message)
                                      : null,
                                );
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
