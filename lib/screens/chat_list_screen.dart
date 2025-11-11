import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../models/chat.dart';
import '../services/chat_service.dart';
import '../widgets/chat_list_item.dart';
import '../widgets/search_bar.dart' as custom;
import '../widgets/filter_sheet.dart';
import '../utils/theme.dart';
import '../providers/theme_provider.dart';
import 'chat_detail_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final ChatService _chatService = ChatService();
  List<Chat> _chats = [];
  List<Chat> _filteredChats = [];
  bool _isLoading = true;
  bool _isConnected = true;
  String _searchQuery = '';
  final ChatFilters _filters = ChatFilters();

  @override
  void initState() {
    super.initState();
    _checkConnection();
    _loadChats();
  }

  @override
  void dispose() {
    _chatService.dispose();
    super.dispose();
  }

  Future<void> _checkConnection() async {
    final isConnected = await _chatService.checkConnection();
    setState(() {
      _isConnected = isConnected;
    });
  }

  Future<void> _loadChats() async {
    setState(() => _isLoading = true);
    try {
      final chats = await _chatService.fetchChats(
        includeArchived: _filters.includeArchived,
        sortBy: _filters.sortBy,
      );
      setState(() {
        _chats = chats;
        _applyFilters();
        _isLoading = false;
        _isConnected = true;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isConnected = false;
      });
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Error'),
            content: Text('Error loading chats: $e'),
            actions: [
              CupertinoDialogAction(
                child: const Text('Cancel'),
                onPressed: () => Navigator.pop(context),
              ),
              CupertinoDialogAction(
                isDefaultAction: true,
                child: const Text('Retry'),
                onPressed: () {
                  Navigator.pop(context);
                  _loadChats();
                },
              ),
            ],
          ),
        );
      }
    }
  }

  void _applyFilters() {
    var filtered = List<Chat>.from(_chats);

    // Apply text search
    if (_searchQuery.isNotEmpty) {
      final lowerQuery = _searchQuery.toLowerCase();
      filtered = filtered.where((chat) {
        return chat.title.toLowerCase().contains(lowerQuery) ||
            chat.messages.any((msg) => 
              msg.content.toLowerCase().contains(lowerQuery));
      }).toList();
    }

    // Apply content filters
    filtered = _chatService.filterChats(
      filtered,
      hasCode: _filters.hasCode ? true : null,
      hasTodos: _filters.hasTodos ? true : null,
      hasToolCalls: _filters.hasToolCalls ? true : null,
      startDate: _filters.startDate,
      endDate: _filters.endDate,
    );

    setState(() {
      _filteredChats = filtered;
    });
  }

  void _onSearch(String query) {
    setState(() {
      _searchQuery = query;
      _applyFilters();
    });
  }

  void _showFilterSheet() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => FilterSheet(
        filters: _filters,
        onApply: (filters) {
          setState(() {
            _loadChats();
          });
        },
      ),
    );
  }

  void _navigateToChatDetail(Chat chat) async {
    await Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => ChatDetailScreen(
          chat: chat,
          chatService: _chatService,
        ),
      ),
    );
    _loadChats(); // Reload after returning
  }

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;

    return CupertinoPageScaffold(
      backgroundColor: isDark ? AppTheme.backgroundDark : AppTheme.background,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: (isDark ? AppTheme.surfaceDark : AppTheme.surface).withOpacity(0.95),
        border: null,
        middle: const Text('Cursor Chats'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!_isConnected)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.todoColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      CupertinoIcons.cloud,
                      size: 14,
                      color: AppTheme.todoColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Offline',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.todoColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            if (!_isConnected)
              const SizedBox(width: 8),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _loadChats,
              child: Icon(
                CupertinoIcons.refresh,
                color: isDark ? AppTheme.primaryLight : AppTheme.primary,
              ),
            ),
            Consumer<ThemeProvider>(
              builder: (context, themeProvider, child) {
                return CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    themeProvider.toggleTheme();
                  },
                  child: Icon(
                    themeProvider.isDarkMode
                        ? CupertinoIcons.sun_max
                        : CupertinoIcons.moon,
                    color: isDark ? AppTheme.primaryLight : AppTheme.primary,
                  ),
                );
              },
            ),
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Search bar
            custom.ChatSearchBar(
              onSearch: _onSearch,
              onFilterTap: _showFilterSheet,
              hasActiveFilters: _filters.hasActiveFilters,
            ),

            // Chat list
            Expanded(
              child: _isLoading
                  ? _buildLoadingState()
                  : _filteredChats.isEmpty
                      ? _buildEmptyState()
                      : CustomScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          slivers: [
                            CupertinoSliverRefreshControl(
                              onRefresh: _loadChats,
                            ),
                            SliverPadding(
                              padding: const EdgeInsets.only(
                                top: AppTheme.spacingSmall,
                                bottom: AppTheme.spacingXLarge,
                              ),
                              sliver: SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    final chat = _filteredChats[index];
                                    return ChatListItem(
                                      chat: chat,
                                      onTap: () => _navigateToChatDetail(chat),
                                    );
                                  },
                                  childCount: _filteredChats.length,
                                ),
                              ),
                            ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
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

  Widget _buildEmptyState() {
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondary;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _searchQuery.isNotEmpty || _filters.hasActiveFilters
                ? CupertinoIcons.search
                : CupertinoIcons.chat_bubble,
            size: 64,
            color: textColor.withOpacity(0.5),
          ),
          const SizedBox(height: AppTheme.spacingMedium),
          Text(
            _searchQuery.isNotEmpty || _filters.hasActiveFilters
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
            _searchQuery.isNotEmpty || _filters.hasActiveFilters
                ? 'Try adjusting your search or filters'
                : _isConnected
                    ? 'Start a conversation in Cursor IDE'
                    : 'Unable to connect to API',
            style: TextStyle(
              fontSize: 14,
              color: textColor.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
          if (!_isConnected) ...[
            const SizedBox(height: AppTheme.spacingLarge),
            CupertinoButton.filled(
              onPressed: _loadChats,
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
}
