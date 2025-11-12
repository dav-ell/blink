import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../models/chat.dart';
import '../providers/chat_detail_provider.dart';
import '../utils/theme.dart';
import 'components/chat_detail_app_bar.dart';
import 'components/chat_stats_header.dart';
import 'components/message_list_view.dart';
import 'components/message_input_bar.dart';

/// Chat detail screen displaying messages and input
/// 
/// Refactored to use ChatDetailProvider for state management
/// Components extracted for better organization
class ChatDetailScreen extends StatefulWidget {
  final Chat chat;

  const ChatDetailScreen({
    super.key,
    required this.chat,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> with WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _uiUpdateTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Load chat details
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatDetailProvider>().loadChat(widget.chat.id);
    });
    
    // Start UI update timer for elapsed time updates
    _startUiUpdateTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _uiUpdateTimer?.cancel();
    _scrollController.dispose();
    _messageController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Resume when app comes back to foreground
      _loadChat();
    }
  }

  void _startUiUpdateTimer() {
    // Update UI every second for active jobs
    _uiUpdateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final provider = context.read<ChatDetailProvider>();
      if (mounted && provider.activeJobCount > 0) {
        setState(() {}); // Trigger rebuild for elapsed time
      }
    });
  }

  Future<void> _loadChat() async {
    await context.read<ChatDetailProvider>().loadChat(
      widget.chat.id,
      forceRefresh: true,
    );
    _scrollToBottom(animate: true);
  }

  void _scrollToBottom({bool animate = true}) {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 50), () {
        if (_scrollController.hasClients) {
          if (animate) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          } else {
            _scrollController.jumpTo(
              _scrollController.position.maxScrollExtent,
            );
          }
        }
      });
    }
  }

  void _sendMessage() {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty) return;

    // Clear input and dismiss keyboard
    _messageController.clear();
    _focusNode.unfocus();

    // Send message via provider
    context.read<ChatDetailProvider>().sendMessage(messageText);

    // Scroll to bottom
    _scrollToBottom(animate: true);
  }

  void _retryMessage(message) {
    context.read<ChatDetailProvider>().retryMessage(message);
    _scrollToBottom(animate: true);
  }

  void _showActionSheet() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _showComingSoonDialog('Export chat');
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
              _showComingSoonDialog('Share');
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
              _showComingSoonDialog('Archive');
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

  void _showComingSoonDialog(String feature) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Coming Soon'),
        content: Text('$feature feature is coming soon!'),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String error) {
    if (!mounted) return;
    
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Error'),
        content: Text(error),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () {
              Navigator.pop(context);
              context.read<ChatDetailProvider>().clearError();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final provider = context.watch<ChatDetailProvider>();
    
    // Show error dialog if needed
    if (provider.hasError) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showErrorDialog(provider.errorMessage);
      });
    }
    
    // Get the current chat or use the initial one
    final chat = provider.chat ?? widget.chat;

    return CupertinoPageScaffold(
      backgroundColor: isDark ? AppTheme.backgroundDark : AppTheme.background,
      navigationBar: ChatDetailAppBar(
        chat: chat,
        activeJobCount: provider.activeJobCount,
        onRefresh: _loadChat,
        onShowMenu: _showActionSheet,
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Chat statistics header
            ChatStatsHeader(chat: chat),

            // Messages list
            Expanded(
              child: MessageListView(
                messages: chat.messages,
                scrollController: _scrollController,
                onRefresh: _loadChat,
                onRetry: _retryMessage,
                isLoading: provider.isLoading,
              ),
            ),

            // Message input
            SafeArea(
              top: false,
              child: MessageInputBar(
                controller: _messageController,
                focusNode: _focusNode,
                onSend: _sendMessage,
                isSending: provider.isSending,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
