import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/message.dart';

/// Cursor API Service - Direct API integration with Cursor's backend
/// 
/// This service makes authenticated API calls to Cursor's backend (api2.cursor.sh)
/// using your captured authentication token.
/// 
/// Usage:
/// ```dart
/// final service = CursorAPIService(
///   authToken: 'your_captured_token',
///   userId: 'auth0|user_...',
/// );
/// 
/// final response = await service.sendMessage('Explain async/await in Dart');
/// print(response);
/// ```
class CursorAPIService {
  final String authToken;
  final String userId;
  final String baseUrl;
  final http.Client _client;
  
  CursorAPIService({
    required this.authToken,
    required this.userId,
    this.baseUrl = 'https://api2.cursor.sh',
    http.Client? client,
  }) : _client = client ?? http.Client();

  /// Get default headers for API requests
  Map<String, String> _getHeaders() {
    return {
      'Authorization': 'Bearer $authToken',
      'Content-Type': 'application/json',
      'X-Cursor-User-Id': userId,
      'X-Cursor-Client-Version': '2.0.69',
      'User-Agent': 'Cursor/2.0.69',
    };
  }

  /// Send a chat message to Cursor's backend
  /// 
  /// [message] - User's message
  /// [model] - Model to use (default: claude-sonnet-4)
  /// [maxTokens] - Maximum tokens in response
  /// [temperature] - Sampling temperature
  /// [systemPrompt] - Optional system prompt
  /// 
  /// Returns the assistant's response as a Message object
  Future<Message> sendMessage({
    required String message,
    String model = 'claude-sonnet-4',
    int maxTokens = 2000,
    double temperature = 0.7,
    String? systemPrompt,
  }) async {
    final messages = <Map<String, String>>[];
    
    if (systemPrompt != null) {
      messages.add({'role': 'system', 'content': systemPrompt});
    }
    
    messages.add({'role': 'user', 'content': message});
    
    final payload = {
      'model': model,
      'messages': messages,
      'max_tokens': maxTokens,
      'temperature': temperature,
      'stream': false,
    };
    
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/v1/chat/completions'),
        headers: _getHeaders(),
        body: json.encode(payload),
      ).timeout(const Duration(seconds: 60));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final content = data['choices'][0]['message']['content'] as String;
        
        return Message(
          bubbleId: DateTime.now().millisecondsSinceEpoch.toString(),
          type: 2, // assistant
          typeLabel: 'assistant',
          text: content,
          createdAt: DateTime.now().toIso8601String(),
          hasToolCall: false,
          hasThinking: false,
          hasCode: content.contains('```'),
          hasTodos: false,
        );
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        throw CursorAPIException(
          'Authentication failed. Token may have expired.',
          statusCode: response.statusCode,
        );
      } else {
        throw CursorAPIException(
          'API request failed: ${response.statusCode}\n${response.body}',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is CursorAPIException) rethrow;
      throw CursorAPIException('Failed to send message: $e');
    }
  }

  /// Send a message with code context (like Cursor IDE does)
  /// 
  /// [message] - User's question
  /// [codeContext] - Code to provide as context
  /// [filePath] - Optional file path for context
  /// [model] - Model to use
  /// 
  /// Returns the assistant's response
  Future<Message> sendMessageWithContext({
    required String message,
    required String codeContext,
    String? filePath,
    String model = 'claude-sonnet-4',
  }) async {
    final contextParts = <String>[];
    
    if (filePath != null) {
      contextParts.add('# File: $filePath');
    }
    
    contextParts.addAll([
      '```',
      codeContext,
      '```',
      '',
      'Question: $message',
    ]);
    
    final fullMessage = contextParts.join('\n');
    
    return sendMessage(
      message: fullMessage,
      model: model,
    );
  }

  /// List available models
  /// 
  /// Returns a list of available model IDs
  Future<List<String>> listModels() async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/v1/models'),
        headers: _getHeaders(),
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final models = data['data'] as List;
        return models
            .map((m) => m['id'] as String)
            .toList();
      } else {
        throw CursorAPIException(
          'Failed to list models: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is CursorAPIException) rethrow;
      throw CursorAPIException('Failed to list models: $e');
    }
  }

  /// Validate authentication token
  /// 
  /// Returns true if token is valid, false otherwise
  Future<bool> validateToken() async {
    try {
      await listModels();
      return true;
    } on CursorAPIException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 403) {
        return false;
      }
      rethrow;
    }
  }

  /// Send a streaming message (for real-time responses)
  /// 
  /// [message] - User's message
  /// [onChunk] - Callback for each chunk of the response
  /// [model] - Model to use
  /// 
  /// Note: Requires SSE (Server-Sent Events) support
  Stream<String> sendMessageStreaming({
    required String message,
    String model = 'claude-sonnet-4',
  }) async* {
    final messages = [
      {'role': 'user', 'content': message}
    ];
    
    final payload = {
      'model': model,
      'messages': messages,
      'max_tokens': 2000,
      'stream': true,
    };
    
    final request = http.Request(
      'POST',
      Uri.parse('$baseUrl/v1/chat/completions'),
    );
    
    request.headers.addAll(_getHeaders());
    request.body = json.encode(payload);
    
    final streamedResponse = await _client.send(request);
    
    if (streamedResponse.statusCode != 200) {
      throw CursorAPIException(
        'Streaming request failed: ${streamedResponse.statusCode}',
        statusCode: streamedResponse.statusCode,
      );
    }
    
    await for (var chunk in streamedResponse.stream.transform(utf8.decoder)) {
      // Parse SSE format
      if (chunk.startsWith('data: ')) {
        final data = chunk.substring(6).trim();
        if (data == '[DONE]') break;
        
        try {
          final parsed = json.decode(data);
          final content = parsed['choices'][0]['delta']['content'];
          if (content != null) {
            yield content as String;
          }
        } catch (_) {
          // Skip malformed chunks
        }
      }
    }
  }

  void dispose() {
    _client.close();
  }
}

/// Exception thrown by Cursor API operations
class CursorAPIException implements Exception {
  final String message;
  final int? statusCode;
  
  CursorAPIException(this.message, {this.statusCode});
  
  @override
  String toString() {
    if (statusCode != null) {
      return 'CursorAPIException [$statusCode]: $message';
    }
    return 'CursorAPIException: $message';
  }
  
  bool get isAuthError => statusCode == 401 || statusCode == 403;
  bool get isRateLimited => statusCode == 429;
  bool get isServerError => statusCode != null && statusCode! >= 500;
}

/// Example usage:
/// 
/// ```dart
/// // Initialize service with captured credentials
/// final service = CursorAPIService(
///   authToken: await secureStorage.read(key: 'cursor_auth_token') ?? '',
///   userId: 'auth0|user_01JYHJFKXK3H3N8Y7CTR10WVB2',
/// );
/// 
/// // Simple message
/// try {
///   final response = await service.sendMessage(
///     message: 'Explain Dart futures',
///   );
///   print(response.text);
/// } catch (e) {
///   if (e is CursorAPIException && e.isAuthError) {
///     print('Token expired - need to re-authenticate');
///   }
/// }
/// 
/// // Message with code context
/// final response = await service.sendMessageWithContext(
///   message: 'How can I improve this?',
///   codeContext: '''
///   Future<void> loadData() async {
///     final data = await fetchFromAPI();
///     setState(() => this.data = data);
///   }
///   ''',
///   filePath: 'lib/screens/home_screen.dart',
/// );
/// 
/// // Streaming response
/// await for (var chunk in service.sendMessageStreaming(
///   message: 'Write a function to calculate fibonacci',
/// )) {
///   print(chunk); // Print each chunk as it arrives
/// }
/// ```

