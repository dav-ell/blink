import 'dart:convert';
import 'package:http/http.dart' as http;

/// @deprecated Use ChatRepository instead for new code
/// This service is kept for backwards compatibility during migration
@Deprecated('Use ChatRepository instead. Will be removed in a future version.')
class ApiService {
  // Use Mac's local network IP for physical iOS devices, 127.0.0.1 for simulator
  static const String baseUrl = 'http://192.168.1.120:8000';
  
  final http.Client _client;
  
  ApiService({http.Client? client}) : _client = client ?? http.Client();

  // Health check
  Future<Map<String, dynamic>> healthCheck() async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/health'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw ApiException('Health check failed: ${response.statusCode}');
      }
    } catch (e) {
      throw ApiException('Failed to connect to API: $e');
    }
  }

  // Fetch all chats with pagination and filtering
  Future<Map<String, dynamic>> fetchChats({
    bool includeArchived = false,
    String sortBy = 'last_updated',
    int? limit,
    int offset = 0,
  }) async {
    try {
      final queryParams = {
        'include_archived': includeArchived.toString(),
        'sort_by': sortBy,
        'offset': offset.toString(),
      };
      
      if (limit != null) {
        queryParams['limit'] = limit.toString();
      }

      final uri = Uri.parse('$baseUrl/chats').replace(
        queryParameters: queryParams,
      );

      final response = await _client.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw ApiException('Failed to fetch chats: ${response.statusCode}');
      }
    } catch (e) {
      throw ApiException('Error fetching chats: $e');
    }
  }

  // Create a new chat
  Future<Map<String, dynamic>> createChat() async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/agent/create-chat'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw ApiException('Failed to create chat: ${response.statusCode}');
      }
    } catch (e) {
      throw ApiException('Error creating chat: $e');
    }
  }

  // Fetch chat metadata only
  Future<Map<String, dynamic>> fetchChatMetadata(String chatId) async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/chats/$chatId/metadata'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else if (response.statusCode == 404) {
        throw ApiException('Chat not found');
      } else {
        throw ApiException('Failed to fetch chat metadata: ${response.statusCode}');
      }
    } catch (e) {
      throw ApiException('Error fetching chat metadata: $e');
    }
  }

  // Fetch all messages for a specific chat
  Future<Map<String, dynamic>> fetchChatMessages(
    String chatId, {
    bool includeMetadata = true,
    int? limit,
    bool includeContent = true,
  }) async {
    try {
      final queryParams = {
        'include_metadata': includeMetadata.toString(),
        'include_content': includeContent.toString(),
      };
      
      if (limit != null) {
        queryParams['limit'] = limit.toString();
      }

      final uri = Uri.parse('$baseUrl/chats/$chatId').replace(
        queryParameters: queryParams,
      );

      final response = await _client.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else if (response.statusCode == 404) {
        throw ApiException('Chat not found');
      } else {
        throw ApiException('Failed to fetch messages: ${response.statusCode}');
      }
    } catch (e) {
      throw ApiException('Error fetching messages: $e');
    }
  }

  void dispose() {
    _client.close();
  }
}

class ApiException implements Exception {
  final String message;
  
  ApiException(this.message);
  
  @override
  String toString() => message;
}

