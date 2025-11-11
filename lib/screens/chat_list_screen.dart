import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../models/chat.dart';
import '../services/chat_service.dart';
import '../widgets/chat_list_item.dart';
import '../widgets/search_bar.dart' as custom;
import '../widgets/filter_sheet.dart';
import '../utils/theme.dart';
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading chats: $e'),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: _loadChats,
            ),
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (_, controller) => FilterSheet(
          filters: _filters,
          onApply: (filters) {
            setState(() {
              _loadChats();
            });
          },
        ),
      ),
    );
  }

  void _navigateToChatDetail(Chat chat) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
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
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Cursor Chats'),
        actions: [
          if (!_isConnected)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                avatar: const Icon(
                  Icons.cloud_off,
                  size: 16,
                  color: AppTheme.todoColor,
                ),
                label: const Text(
                  'Offline',
                  style: TextStyle(fontSize: 12),
                ),
                backgroundColor: AppTheme.todoColor.withOpacity(0.1),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadChats,
          ),
        ],
      ),
      body: Column(
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
                    : RefreshIndicator(
                        onRefresh: _loadChats,
                        child: ListView.builder(
                          padding: const EdgeInsets.only(
                            top: AppTheme.spacingSmall,
                            bottom: AppTheme.spacingXLarge,
                          ),
                          itemCount: _filteredChats.length,
                          itemBuilder: (context, index) {
                            final chat = _filteredChats[index];
                            return ChatListItem(
                              chat: chat,
                              onTap: () => _navigateToChatDetail(chat),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.spacingMedium),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Container(
            margin: const EdgeInsets.only(bottom: AppTheme.spacingMedium),
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _searchQuery.isNotEmpty || _filters.hasActiveFilters
                ? Icons.search_off
                : Icons.chat_bubble_outline,
            size: 64,
            color: AppTheme.textTertiary,
          ),
          const SizedBox(height: AppTheme.spacingMedium),
          Text(
            _searchQuery.isNotEmpty || _filters.hasActiveFilters
                ? 'No chats found'
                : 'No chats yet',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: AppTheme.spacingSmall),
          Text(
            _searchQuery.isNotEmpty || _filters.hasActiveFilters
                ? 'Try adjusting your search or filters'
                : _isConnected
                    ? 'Start a conversation in Cursor IDE'
                    : 'Unable to connect to API',
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textTertiary,
            ),
            textAlign: TextAlign.center,
          ),
          if (!_isConnected) ...[
            const SizedBox(height: AppTheme.spacingLarge),
            ElevatedButton.icon(
              onPressed: _loadChats,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry Connection'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingLarge,
                  vertical: AppTheme.spacingMedium,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
