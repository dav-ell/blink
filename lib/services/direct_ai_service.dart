import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../models/message.dart';

/// Direct AI Service - Bypasses Cursor entirely
/// 
/// This service makes direct API calls to AI providers (Anthropic, OpenAI, etc.)
/// without depending on Cursor. Use this to avoid Cursor bugs.
class DirectAIService {
  final String? anthropicApiKey;
  final String? openaiApiKey;
  final http.Client _client;
  
  DirectAIService({
    this.anthropicApiKey,
    this.openaiApiKey,
    http.Client? client,
  }) : _client = client ?? http.Client();

  /// Send a message to Claude (Anthropic)
  Future<Message> sendToAnthropic({
    required String prompt,
    String model = 'claude-sonnet-4-20250514',
    int maxTokens = 4096,
  }) async {
    if (anthropicApiKey == null) {
      throw Exception('Anthropic API key not configured');
    }

    try {
      final response = await _client.post(
        Uri.parse('https://api.anthropic.com/v1/messages'),
        headers: {
          'x-api-key': anthropicApiKey!,
          'anthropic-version': '2023-06-01',
          'content-type': 'application/json',
        },
        body: json.encode({
          'model': model,
          'max_tokens': maxTokens,
          'messages': [
            {
              'role': 'user',
              'content': prompt,
            }
          ],
        }),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final content = data['content'][0]['text'] as String;
        
        return Message(
          bubbleId: const Uuid().v4(),
          type: 2, // assistant
          typeLabel: 'assistant',
          text: content,
          createdAt: DateTime.now().toIso8601String(),
          hasToolCall: false,
          hasThinking: false,
          hasCode: _hasCodeBlock(content),
          hasTodos: false,
        );
      } else {
        throw DirectAIException(
          'Anthropic API error: ${response.statusCode}\n${response.body}',
        );
      }
    } catch (e) {
      throw DirectAIException('Failed to call Anthropic API: $e');
    }
  }

  /// Send a message to GPT (OpenAI)
  Future<Message> sendToOpenAI({
    required String prompt,
    String model = 'gpt-4o',
    int maxTokens = 4096,
  }) async {
    if (openaiApiKey == null) {
      throw Exception('OpenAI API key not configured');
    }

    try {
      final response = await _client.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $openaiApiKey',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'model': model,
          'max_tokens': maxTokens,
          'messages': [
            {
              'role': 'user',
              'content': prompt,
            }
          ],
        }),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final content = data['choices'][0]['message']['content'] as String;
        
        return Message(
          bubbleId: const Uuid().v4(),
          type: 2, // assistant
          typeLabel: 'assistant',
          text: content,
          createdAt: DateTime.now().toIso8601String(),
          hasToolCall: false,
          hasThinking: false,
          hasCode: _hasCodeBlock(content),
          hasTodos: false,
        );
      } else {
        throw DirectAIException(
          'OpenAI API error: ${response.statusCode}\n${response.body}',
        );
      }
    } catch (e) {
      throw DirectAIException('Failed to call OpenAI API: $e');
    }
  }

  /// Send message to the specified provider
  Future<Message> sendMessage({
    required String prompt,
    required String provider, // 'anthropic' or 'openai'
    String? model,
    int maxTokens = 4096,
  }) async {
    switch (provider.toLowerCase()) {
      case 'anthropic':
      case 'claude':
        return await sendToAnthropic(
          prompt: prompt,
          model: model ?? 'claude-sonnet-4-20250514',
          maxTokens: maxTokens,
        );
      
      case 'openai':
      case 'gpt':
        return await sendToOpenAI(
          prompt: prompt,
          model: model ?? 'gpt-4o',
          maxTokens: maxTokens,
        );
      
      default:
        throw DirectAIException('Unknown provider: $provider');
    }
  }

  /// Build a prompt with code context (like Cursor does)
  String buildPromptWithContext({
    required String userMessage,
    String? codeContext,
    String? filePath,
  }) {
    final parts = <String>[];
    
    if (codeContext != null && codeContext.isNotEmpty) {
      parts.add('# Code Context');
      if (filePath != null) {
        parts.add('File: $filePath');
      }
      parts.add('```');
      parts.add(codeContext);
      parts.add('```');
      parts.add('');
    }
    
    parts.add('# User Message');
    parts.add(userMessage);
    
    return parts.join('\n');
  }

  /// Check if content has code blocks
  bool _hasCodeBlock(String content) {
    return content.contains('```');
  }

  void dispose() {
    _client.close();
  }
}

/// Custom exception for direct AI service errors
class DirectAIException implements Exception {
  final String message;
  
  DirectAIException(this.message);
  
  @override
  String toString() => message;
}

/// Example usage:
/// 
/// ```dart
/// // Initialize service
/// final aiService = DirectAIService(
///   anthropicApiKey: 'your_anthropic_key',
///   openaiApiKey: 'your_openai_key',
/// );
/// 
/// // Send to Claude
/// final response = await aiService.sendMessage(
///   prompt: 'Explain this code to me',
///   provider: 'anthropic',
/// );
/// 
/// // Send with context (like Cursor does)
/// final contextualPrompt = aiService.buildPromptWithContext(
///   userMessage: 'How can I improve this function?',
///   codeContext: '''
///   void myFunction() {
///     // your code here
///   }
///   ''',
///   filePath: 'lib/main.dart',
/// );
/// 
/// final response = await aiService.sendMessage(
///   prompt: contextualPrompt,
///   provider: 'anthropic',
/// );
/// ```

