import '../models/chat.dart';
import '../core/constants.dart';
import '../repositories/chat_repository.dart';
import 'cache_service.dart';

/// Service for chat business logic
/// 
/// This service provides high-level chat operations with caching,
/// filtering, and search capabilities. It uses ChatRepository for
/// data access and CacheService for caching.
class ChatService {
  final ChatRepository _repository;
  final CacheService<String, Chat> _chatCache;
  final CacheService<String, List<Chat>> _listCache;

  ChatService({
    ChatRepository? repository,
  })  : _repository = repository ?? ChatRepository(),
        _chatCache = CacheService(expiry: AppConstants.cacheExpiry),
        _listCache = CacheService(expiry: AppConstants.cacheExpiry);

  // Check if API is available
  Future<bool> checkConnection() async {
    final result = await _repository.checkHealth();
    return result.isSuccess;
  }

  // Create a new chat
  Future<String> createNewChat() async {
    final result = await _repository.createChat();
    return result.when(
      success: (chatId) {
        // Clear list cache to force refresh
        _listCache.clear();
        return chatId;
      },
      failure: (error) => throw Exception(error),
    );
  }

  // Fetch all chats with caching
  Future<List<Chat>> fetchChats({
    bool includeArchived = false,
    String sortBy = 'last_updated',
    bool forceRefresh = false,
  }) async {
    final cacheKey = 'chats_${includeArchived}_$sortBy';
    
    // Return cached if valid and not forcing refresh
    if (!forceRefresh) {
      final cached = _listCache.get(cacheKey);
      if (cached != null) return cached;
    }
    
    final result = await _repository.fetchChats(
      includeArchived: includeArchived,
      sortBy: sortBy,
    );

    return result.when(
      success: (chats) {
        // Update caches
        _listCache.set(cacheKey, chats);
        for (final chat in chats) {
          _chatCache.set(chat.id, chat);
        }
        return chats;
      },
      failure: (error) => throw Exception(error),
    );
  }

  // Fetch a specific chat with messages
  Future<Chat> fetchChat(String chatId, {bool forceRefresh = false}) async {
    // Check cache first
    if (!forceRefresh) {
      final cached = _chatCache.get(chatId);
      if (cached != null) return cached;
    }

    final result = await _repository.fetchChat(chatId);

    return result.when(
      success: (chat) {
        // Update cache
        _chatCache.set(chatId, chat);
        return chat;
      },
      failure: (error) => throw Exception(error),
    );
  }

  // Search chats by text
  Future<List<Chat>> searchChats(String query, {bool includeArchived = false}) async {
    final chats = await fetchChats(includeArchived: includeArchived);
    
    if (query.isEmpty) return chats;
    
    final lowerQuery = query.toLowerCase();
    return chats.where((chat) {
      return chat.title.toLowerCase().contains(lowerQuery) ||
             chat.messages.any((msg) => 
               msg.content.toLowerCase().contains(lowerQuery));
    }).toList();
  }

  // Filter chats by various criteria
  List<Chat> filterChats(
    List<Chat> chats, {
    bool? hasCode,
    bool? hasTodos,
    bool? hasToolCalls,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return chats.where((chat) {
      // Date filter
      if (startDate != null && chat.createdAt.isBefore(startDate)) {
        return false;
      }
      if (endDate != null && chat.createdAt.isAfter(endDate)) {
        return false;
      }

      // Content type filters
      if (hasCode == true && !chat.messages.any((m) => m.hasCode)) {
        return false;
      }
      if (hasTodos == true && !chat.messages.any((m) => m.hasTodos)) {
        return false;
      }
      if (hasToolCalls == true && !chat.messages.any((m) => m.hasToolCall)) {
        return false;
      }

      return true;
    }).toList();
  }

  // Clear cache
  void clearCache() {
    _chatCache.clear();
    _listCache.clear();
  }

  void dispose() {
    _chatCache.dispose();
    _listCache.dispose();
    _repository.dispose();
  }
}
