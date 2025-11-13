import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../models/chat.dart';
import '../providers/chat_provider.dart';
import '../providers/chat_detail_provider.dart';
import '../widgets/search_bar.dart' as custom;
import '../widgets/filter_sheet.dart';
import '../utils/theme.dart';
import '../core/service_locator.dart';
import 'chat_detail_screen.dart';
import 'new_chat_screen.dart';
import 'components/chat_list_header.dart';
import 'components/chat_list_content.dart';
import 'components/chat_list_fab.dart';

/// Main screen displaying list of chats
/// 
/// Refactored to use ChatProvider for state management
/// Components extracted for better organization
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final ChatFilters _filters = ChatFilters();

  @override
  void initState() {
    super.initState();
    // Initialize chat provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().initialize();
    });
  }

  void _onSearch(String query) {
    context.read<ChatProvider>().setSearchQuery(query);
  }

  void _showFilterSheet() {
    final chatProvider = context.read<ChatProvider>();
    
    showCupertinoModalPopup(
      context: context,
      builder: (context) => FilterSheet(
        filters: _filters,
        onApply: (filters) {
          chatProvider.setIncludeArchived(_filters.includeArchived);
          chatProvider.loadChats();
        },
      ),
    );
  }

  Future<void> _navigateToChatDetail(Chat chat) async {
    await Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => ChangeNotifierProvider(
          create: (_) => getIt<ChatDetailProvider>(),
          child: ChatDetailScreen(chat: chat),
        ),
      ),
    );
    
    // Reload after returning
    if (mounted) {
      context.read<ChatProvider>().loadChats();
    }
  }

  Future<void> _createNewChat() async {
    final chatProvider = context.read<ChatProvider>();
    
    // Navigate to new chat screen for location selection
    if (mounted) {
      await Navigator.push(
        context,
        CupertinoPageRoute(
          builder: (context) => const NewChatScreen(),
        ),
      );
      
      // Refresh after returning
      if (mounted) {
        chatProvider.loadChats(forceRefresh: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;

    return CupertinoPageScaffold(
      backgroundColor: isDark ? AppTheme.backgroundDark : AppTheme.background,
      navigationBar: const ChatListHeader(),
      child: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Search bar
                custom.ChatSearchBar(
                  onSearch: _onSearch,
                  onFilterTap: _showFilterSheet,
                  hasActiveFilters: _filters.hasActiveFilters,
                ),

                // Chat list content
                Expanded(
                  child: ChatListContent(
                    onChatTap: _navigateToChatDetail,
                  ),
                ),
              ],
            ),
            
            // Floating Action Button
            ChatListFab(
              onPressed: _createNewChat,
            ),
          ],
        ),
      ),
    );
  }
}
