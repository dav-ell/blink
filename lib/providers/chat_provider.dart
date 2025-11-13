import 'package:flutter/foundation.dart';
import '../models/chat.dart';
import '../services/chat_service.dart';

/// Provider for managing chat list state
/// 
/// Manages:
/// - List of chats
/// - Search query
/// - Filters
/// - Loading/error states
class ChatProvider with ChangeNotifier {
  final ChatService _chatService;
  
  List<Chat> _chats = [];
  List<Chat> _filteredChats = [];
  bool _isLoading = false;
  bool _isConnected = true;
  String _searchQuery = '';
  String _errorMessage = '';
  
  // Filter state
  bool _includeArchived = false;
  String _sortBy = 'last_updated';
  
  ChatProvider({ChatService? chatService})
      : _chatService = chatService ?? ChatService();
  
  // Getters
  List<Chat> get chats => _chats;
  List<Chat> get filteredChats => _filteredChats;
  bool get isLoading => _isLoading;
  bool get isConnected => _isConnected;
  String get searchQuery => _searchQuery;
  String get errorMessage => _errorMessage;
  bool get includeArchived => _includeArchived;
  String get sortBy => _sortBy;
  bool get hasError => _errorMessage.isNotEmpty;
  
  /// Initialize - check connection and load chats
  Future<void> initialize() async {
    await checkConnection();
    if (_isConnected) {
      await loadChats();
    }
  }
  
  /// Check API connection
  Future<void> checkConnection() async {
    final connected = await _chatService.checkConnection();
    _isConnected = connected;
    notifyListeners();
  }
  
  /// Load all chats
  Future<void> loadChats({bool forceRefresh = false}) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();
    
    try {
      final chats = await _chatService.fetchChats(
        includeArchived: _includeArchived,
        sortBy: _sortBy,
        forceRefresh: forceRefresh,
      );
      
      _chats = chats;
      _isConnected = true;
      _applyFilters();
    } catch (e) {
      _errorMessage = e.toString();
      _isConnected = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Set search query and filter chats
  void setSearchQuery(String query) {
    _searchQuery = query;
    _applyFilters();
  }
  
  /// Set archived filter
  void setIncludeArchived(bool include) {
    if (_includeArchived != include) {
      _includeArchived = include;
      loadChats();
    }
  }
  
  /// Set sort order
  void setSortBy(String sortBy) {
    if (_sortBy != sortBy) {
      _sortBy = sortBy;
      loadChats();
    }
  }
  
  /// Create a new chat
  Future<String> createNewChat() async {
    try {
      final chatId = await _chatService.createNewChat();
      // Refresh list after creating
      await loadChats(forceRefresh: true);
      return chatId;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }
  
  /// Apply filters to chat list
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
    
    _filteredChats = filtered;
    notifyListeners();
  }
  
  /// Clear error message
  void clearError() {
    _errorMessage = '';
    notifyListeners();
  }
  
  /// Clear cache
  void clearCache() {
    _chatService.clearCache();
  }
  
  @override
  void dispose() {
    // Don't dispose singleton service - it's managed by the service locator
    // _chatService.dispose();
    super.dispose();
  }
}

