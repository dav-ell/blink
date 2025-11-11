import '../models/chat.dart';
import 'api_service.dart';

class ChatService {
  final ApiService _apiService;
  
  // Cache for performance
  final Map<String, Chat> _chatCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheExpiry = Duration(minutes: 5);

  ChatService({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  // Check if API is available
  Future<bool> checkConnection() async {
    try {
      await _apiService.healthCheck();
      return true;
    } catch (e) {
      return false;
    }
  }

  // Fetch all chats with caching
  Future<List<Chat>> fetchChats({
    bool includeArchived = false,
    String sortBy = 'last_updated',
    bool forceRefresh = false,
  }) async {
    try {
      final response = await _apiService.fetchChats(
        includeArchived: includeArchived,
        sortBy: sortBy,
      );

      final chats = (response['chats'] as List)
          .map((chatJson) => Chat.fromJson(chatJson))
          .toList();

      // Update cache
      for (final chat in chats) {
        _chatCache[chat.id] = chat;
        _cacheTimestamps[chat.id] = DateTime.now();
      }

      return chats;
    } catch (e) {
      throw Exception('Failed to fetch chats: $e');
    }
  }

  // Fetch a specific chat with messages
  Future<Chat> fetchChat(String chatId, {bool forceRefresh = false}) async {
    // Check cache first
    if (!forceRefresh && _isCacheValid(chatId)) {
      return _chatCache[chatId]!;
    }

    try {
      final response = await _apiService.fetchChatMessages(
        chatId,
        includeMetadata: true,
      );

      final chat = Chat.fromJson({
        ...response['metadata'] ?? {},
        'chat_id': chatId,
        'messages': response['messages'] ?? [],
      });

      // Update cache
      _chatCache[chatId] = chat;
      _cacheTimestamps[chatId] = DateTime.now();

      return chat;
    } catch (e) {
      throw Exception('Failed to fetch chat: $e');
    }
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
    _cacheTimestamps.clear();
  }

  // Check if cache is valid
  bool _isCacheValid(String chatId) {
    if (!_chatCache.containsKey(chatId)) return false;
    
    final timestamp = _cacheTimestamps[chatId];
    if (timestamp == null) return false;
    
    return DateTime.now().difference(timestamp) < _cacheExpiry;
  }

  void dispose() {
    _apiService.dispose();
  }
}
