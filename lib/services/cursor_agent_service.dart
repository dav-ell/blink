import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/chat.dart';
import '../models/job.dart';
import '../models/device.dart';

/// Service for interacting with cursor-agent via REST API
/// 
/// Enables iOS app to:
/// - List existing Cursor chats
/// - View chat history
/// - Continue conversations with full context
/// - Create new chats
class CursorAgentService {
  final String baseUrl;
  final http.Client _client;
  
  CursorAgentService({
    this.baseUrl = 'http://localhost:8000',
    http.Client? client,
  }) : _client = client ?? http.Client();

  // =========================================================================
  // Chat Discovery
  // =========================================================================

  /// List existing Cursor chats
  Future<List<Chat>> listExistingChats({
    bool includeArchived = false,
    String sortBy = 'last_updated',
    int? limit,
  }) async {
    final queryParams = {
      'include_archived': includeArchived.toString(),
      'sort_by': sortBy,
      if (limit != null) 'limit': limit.toString(),
    };
    
    final uri = Uri.parse('$baseUrl/chats').replace(
      queryParameters: queryParams,
    );
    
    final response = await _client.get(
      uri,
      headers: {'Content-Type': 'application/json'},
    ).timeout(const Duration(seconds: 10));
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return (data['chats'] as List)
          .map((chatJson) => Chat.fromJson(chatJson))
          .toList();
    } else {
      throw CursorAgentException('Failed to list chats: ${response.statusCode}');
    }
  }

  /// Get chat summary optimized for UI display
  Future<ChatSummary> getChatSummary(String chatId, {int recentCount = 5}) async {
    final uri = Uri.parse('$baseUrl/chats/$chatId/summary').replace(
      queryParameters: {'recent_count': recentCount.toString()},
    );
    
    final response = await _client.get(
      uri,
      headers: {'Content-Type': 'application/json'},
    ).timeout(const Duration(seconds: 10));
    
    if (response.statusCode == 200) {
      return ChatSummary.fromJson(json.decode(response.body));
    } else if (response.statusCode == 404) {
      throw ChatNotFoundException(chatId);
    } else {
      throw CursorAgentException('Failed to get summary: ${response.statusCode}');
    }
  }

  /// Get full chat details with all messages
  Future<Chat> getChatDetails(String chatId) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/chats/$chatId'),
      headers: {'Content-Type': 'application/json'},
    ).timeout(const Duration(seconds: 15));
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return Chat.fromJson({
        ...data['metadata'] ?? {},
        'chat_id': chatId,
        'messages': data['messages'] ?? [],
      });
    } else if (response.statusCode == 404) {
      throw ChatNotFoundException(chatId);
    } else {
      throw CursorAgentException('Failed to get chat: ${response.statusCode}');
    }
  }

  /// Get info for multiple chats at once (optimized for list views)
  Future<BatchChatInfo> getBatchChatInfo(List<String> chatIds) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/chats/batch-info'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(chatIds),
    ).timeout(const Duration(seconds: 15));
    
    if (response.statusCode == 200) {
      return BatchChatInfo.fromJson(json.decode(response.body));
    } else {
      throw CursorAgentException('Failed to get batch info: ${response.statusCode}');
    }
  }

  // =========================================================================
  // Chat Continuation
  // =========================================================================

  /// Continue an existing conversation with full context
  /// 
  /// The REST API uses cursor-agent's --resume flag to automatically
  /// include all previous messages as context.
  Future<AgentResponse> continueConversation(
    String chatId,
    String prompt, {
    bool showContext = false,
    int? maxHistoryMessages,
    String? model,
    String outputFormat = 'text',
  }) async {
    final uri = Uri.parse('$baseUrl/chats/$chatId/agent-prompt').replace(
      queryParameters: showContext ? {'show_context': 'true'} : null,
    );
    
    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'prompt': prompt,
        'include_history': true,
        if (maxHistoryMessages != null) 'max_history_messages': maxHistoryMessages,
        if (model != null) 'model': model,
        'output_format': outputFormat,
      }),
    ).timeout(const Duration(seconds: 90));
    
    if (response.statusCode == 200) {
      return AgentResponse.fromJson(json.decode(response.body));
    } else if (response.statusCode == 404) {
      throw ChatNotFoundException(chatId);
    } else {
      final error = json.decode(response.body);
      throw CursorAgentException(
        error['detail'] ?? 'Failed to send prompt: ${response.statusCode}'
      );
    }
  }

  // =========================================================================
  // Chat Management
  // =========================================================================

  /// Create a new chat conversation
  Future<String> createNewChat() async {
    final response = await _client.post(
      Uri.parse('$baseUrl/agent/create-chat'),
      headers: {'Content-Type': 'application/json'},
    ).timeout(const Duration(seconds: 10));
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['chat_id'];
    } else {
      throw CursorAgentException('Failed to create chat: ${response.statusCode}');
    }
  }

  /// Get list of available AI models
  Future<ModelsList> getAvailableModels() async {
    final response = await _client.get(
      Uri.parse('$baseUrl/agent/models'),
      headers: {'Content-Type': 'application/json'},
    ).timeout(const Duration(seconds: 5));
    
    if (response.statusCode == 200) {
      return ModelsList.fromJson(json.decode(response.body));
    } else {
      throw CursorAgentException('Failed to get models: ${response.statusCode}');
    }
  }

  // =========================================================================
  // Health & Status
  // =========================================================================

  /// Check if API is available and cursor-agent is installed
  Future<ApiStatus> checkStatus() async {
    final response = await _client.get(
      Uri.parse('$baseUrl/'),
      headers: {'Content-Type': 'application/json'},
    ).timeout(const Duration(seconds: 5));
    
    if (response.statusCode == 200) {
      return ApiStatus.fromJson(json.decode(response.body));
    } else {
      throw CursorAgentException('API not available');
    }
  }

  // =========================================================================
  // Async Job Management (NEW v2.0)
  // =========================================================================

  /// Submit a prompt asynchronously and return immediately with job ID
  Future<Job> submitPromptAsync(
    String chatId,
    String prompt, {
    String? model,
  }) async {
    final uri = Uri.parse('$baseUrl/chats/$chatId/agent-prompt-async');
    
    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'prompt': prompt,
        'include_history': true,
        if (model != null) 'model': model,
        'output_format': 'text',
      }),
    ).timeout(const Duration(seconds: 10));
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      // Convert the initial response to a Job object
      return Job(
        jobId: data['job_id'],
        chatId: data['chat_id'],
        prompt: prompt,
        status: JobStatus.pending,
        createdAt: DateTime.parse(data['created_at']),
        model: model,
      );
    } else if (response.statusCode == 404) {
      throw ChatNotFoundException(chatId);
    } else {
      final error = json.decode(response.body);
      throw CursorAgentException(
        error['detail'] ?? 'Failed to submit prompt: ${response.statusCode}'
      );
    }
  }

  /// Get full job details including status and result
  Future<Job> getJobDetails(String jobId) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/jobs/$jobId'),
      headers: {'Content-Type': 'application/json'},
    ).timeout(const Duration(seconds: 10));
    
    if (response.statusCode == 200) {
      return Job.fromJson(json.decode(response.body));
    } else if (response.statusCode == 404) {
      throw CursorAgentException('Job not found: $jobId');
    } else {
      throw CursorAgentException('Failed to get job: ${response.statusCode}');
    }
  }

  /// Quick status check (lighter response)
  Future<Map<String, dynamic>> getJobStatus(String jobId) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/jobs/$jobId/status'),
      headers: {'Content-Type': 'application/json'},
    ).timeout(const Duration(seconds: 5));
    
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else if (response.statusCode == 404) {
      throw CursorAgentException('Job not found: $jobId');
    } else {
      throw CursorAgentException('Failed to get job status: ${response.statusCode}');
    }
  }

  /// List all jobs for a chat
  Future<List<Job>> listChatJobs(
    String chatId, {
    int limit = 20,
    String? statusFilter,
  }) async {
    final queryParams = {
      'limit': limit.toString(),
      if (statusFilter != null) 'status_filter': statusFilter,
    };
    
    final uri = Uri.parse('$baseUrl/chats/$chatId/jobs').replace(
      queryParameters: queryParams,
    );
    
    final response = await _client.get(
      uri,
      headers: {'Content-Type': 'application/json'},
    ).timeout(const Duration(seconds: 10));
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return (data['jobs'] as List)
          .map((jobJson) => Job.fromJson(jobJson))
          .toList();
    } else {
      throw CursorAgentException('Failed to list jobs: ${response.statusCode}');
    }
  }

  /// Cancel a pending or processing job
  Future<void> cancelJob(String jobId) async {
    final response = await _client.delete(
      Uri.parse('$baseUrl/jobs/$jobId'),
      headers: {'Content-Type': 'application/json'},
    ).timeout(const Duration(seconds: 5));
    
    if (response.statusCode == 200) {
      return;
    } else if (response.statusCode == 404) {
      throw CursorAgentException('Job not found: $jobId');
    } else if (response.statusCode == 400) {
      final error = json.decode(response.body);
      throw CursorAgentException(error['detail'] ?? 'Cannot cancel job');
    } else {
      throw CursorAgentException('Failed to cancel job: ${response.statusCode}');
    }
  }

  // =========================================================================
  // Device Management (NEW - Remote SSH Support)
  // =========================================================================

  /// Create a new device configuration
  Future<Device> createDevice(DeviceCreate deviceCreate) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/devices'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(deviceCreate.toJson()),
    ).timeout(const Duration(seconds: 10));
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return Device.fromJson(data['device']);
    } else {
      throw CursorAgentException('Failed to create device: ${response.statusCode}');
    }
  }

  /// List all configured devices
  Future<List<Device>> listDevices({bool includeInactive = false}) async {
    final uri = Uri.parse('$baseUrl/devices').replace(
      queryParameters: {'include_inactive': includeInactive.toString()},
    );
    
    final response = await _client.get(
      uri,
      headers: {'Content-Type': 'application/json'},
    ).timeout(const Duration(seconds: 10));
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return (data['devices'] as List)
          .map((deviceJson) => Device.fromJson(deviceJson))
          .toList();
    } else {
      throw CursorAgentException('Failed to list devices: ${response.statusCode}');
    }
  }

  /// Get device details by ID
  Future<Device> getDevice(String deviceId) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/devices/$deviceId'),
      headers: {'Content-Type': 'application/json'},
    ).timeout(const Duration(seconds: 10));
    
    if (response.statusCode == 200) {
      return Device.fromJson(json.decode(response.body));
    } else if (response.statusCode == 404) {
      throw CursorAgentException('Device not found: $deviceId');
    } else {
      throw CursorAgentException('Failed to get device: ${response.statusCode}');
    }
  }

  /// Update device configuration
  Future<Device> updateDevice(String deviceId, DeviceUpdate deviceUpdate) async {
    final response = await _client.put(
      Uri.parse('$baseUrl/devices/$deviceId'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(deviceUpdate.toJson()),
    ).timeout(const Duration(seconds: 10));
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return Device.fromJson(data['device']);
    } else if (response.statusCode == 404) {
      throw CursorAgentException('Device not found: $deviceId');
    } else {
      throw CursorAgentException('Failed to update device: ${response.statusCode}');
    }
  }

  /// Delete a device
  Future<void> deleteDevice(String deviceId) async {
    final response = await _client.delete(
      Uri.parse('$baseUrl/devices/$deviceId'),
      headers: {'Content-Type': 'application/json'},
    ).timeout(const Duration(seconds: 10));
    
    if (response.statusCode == 200) {
      return;
    } else if (response.statusCode == 404) {
      throw CursorAgentException('Device not found: $deviceId');
    } else {
      throw CursorAgentException('Failed to delete device: ${response.statusCode}');
    }
  }

  /// Test SSH connection to a device
  Future<DeviceTestResult> testDevice(String deviceId) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/devices/$deviceId/test'),
      headers: {'Content-Type': 'application/json'},
    ).timeout(const Duration(seconds: 15));
    
    if (response.statusCode == 200) {
      return DeviceTestResult.fromJson(json.decode(response.body));
    } else if (response.statusCode == 404) {
      throw CursorAgentException('Device not found: $deviceId');
    } else {
      throw CursorAgentException('Failed to test device: ${response.statusCode}');
    }
  }

  /// Verify cursor-agent is installed on remote device
  Future<Map<String, dynamic>> verifyAgentInstalled(String deviceId) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/devices/$deviceId/verify-agent'),
      headers: {'Content-Type': 'application/json'},
    ).timeout(const Duration(seconds: 15));
    
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else if (response.statusCode == 404) {
      throw CursorAgentException('Device not found: $deviceId');
    } else {
      throw CursorAgentException('Failed to verify agent: ${response.statusCode}');
    }
  }

  /// Verify a directory exists on remote device
  Future<Map<String, dynamic>> verifyDirectory(
    String deviceId,
    String directory,
  ) async {
    final uri = Uri.parse('$baseUrl/devices/$deviceId/verify-directory').replace(
      queryParameters: {'directory': directory},
    );
    
    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
    ).timeout(const Duration(seconds: 15));
    
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else if (response.statusCode == 404) {
      throw CursorAgentException('Device not found: $deviceId');
    } else {
      throw CursorAgentException('Failed to verify directory: ${response.statusCode}');
    }
  }

  /// Browse remote directory contents
  Future<List<DirectoryEntry>> browseRemoteDirectory(
    String deviceId,
    String directory,
  ) async {
    final uri = Uri.parse('$baseUrl/devices/$deviceId/browse').replace(
      queryParameters: {'directory': directory},
    );
    
    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
    ).timeout(const Duration(seconds: 15));
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == true) {
        return (data['entries'] as List)
            .map((e) => DirectoryEntry.fromJson(e))
            .toList();
      } else {
        throw CursorAgentException(data['error'] ?? 'Failed to browse directory');
      }
    } else if (response.statusCode == 404) {
      throw CursorAgentException('Device not found: $deviceId');
    } else {
      throw CursorAgentException('Failed to browse directory: ${response.statusCode}');
    }
  }

  /// Create a new chat on a remote device
  Future<String> createRemoteChat(
    String deviceId,
    String workingDirectory, {
    String? name,
  }) async {
    final remoteChatCreate = RemoteChatCreate(
      deviceId: deviceId,
      workingDirectory: workingDirectory,
      name: name,
    );
    
    final response = await _client.post(
      Uri.parse('$baseUrl/devices/$deviceId/create-chat'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(remoteChatCreate.toJson()),
    ).timeout(const Duration(seconds: 20));
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['chat_id'];
    } else if (response.statusCode == 404) {
      throw CursorAgentException('Device not found: $deviceId');
    } else if (response.statusCode == 400) {
      final error = json.decode(response.body);
      throw CursorAgentException(error['detail'] ?? 'Invalid request');
    } else {
      final error = json.decode(response.body);
      throw CursorAgentException(
        error['detail'] ?? 'Failed to create remote chat: ${response.statusCode}'
      );
    }
  }

  /// Get remote chat information
  Future<RemoteChatInfo?> getRemoteChatInfo(String chatId) async {
    // This would need to be implemented on backend if we want to query individual chats
    // For now, we can get this from the chat list
    return null;
  }

  void dispose() {
    _client.close();
  }
}

// =============================================================================
// Data Models
// =============================================================================

/// Summary of a chat optimized for UI display
class ChatSummary {
  final String chatId;
  final String name;
  final String? createdAt;
  final String? lastUpdated;
  final int messageCount;
  final List<RecentMessage> recentMessages;
  final bool canContinue;
  final bool hasCode;
  final bool hasTodos;
  
  ChatSummary({
    required this.chatId,
    required this.name,
    this.createdAt,
    this.lastUpdated,
    required this.messageCount,
    required this.recentMessages,
    this.canContinue = true,
    this.hasCode = false,
    this.hasTodos = false,
  });
  
  factory ChatSummary.fromJson(Map<String, dynamic> json) {
    return ChatSummary(
      chatId: json['chat_id'],
      name: json['name'] ?? 'Untitled',
      createdAt: json['created_at'],
      lastUpdated: json['last_updated'],
      messageCount: json['message_count'] ?? 0,
      recentMessages: (json['recent_messages'] as List?)
          ?.map((m) => RecentMessage.fromJson(m))
          .toList() ?? [],
      canContinue: json['can_continue'] ?? true,
      hasCode: json['has_code'] ?? false,
      hasTodos: json['has_todos'] ?? false,
    );
  }
}

/// Recent message preview
class RecentMessage {
  final String role;
  final String text;
  final String? createdAt;
  final bool hasCode;
  final bool hasThinking;
  final bool hasToolCall;
  
  RecentMessage({
    required this.role,
    required this.text,
    this.createdAt,
    this.hasCode = false,
    this.hasThinking = false,
    this.hasToolCall = false,
  });
  
  factory RecentMessage.fromJson(Map<String, dynamic> json) {
    return RecentMessage(
      role: json['role'],
      text: json['text'],
      createdAt: json['created_at'],
      hasCode: json['has_code'] ?? false,
      hasThinking: json['has_thinking'] ?? false,
      hasToolCall: json['has_tool_call'] ?? false,
    );
  }
}

/// Response from cursor-agent
class AgentResponse {
  final String status;
  final String chatId;
  final String prompt;
  final String model;
  final String outputFormat;
  final String response;
  final ResponseContext? context;
  final Map<String, dynamic> metadata;
  
  AgentResponse({
    required this.status,
    required this.chatId,
    required this.prompt,
    required this.model,
    required this.outputFormat,
    required this.response,
    this.context,
    required this.metadata,
  });
  
  factory AgentResponse.fromJson(Map<String, dynamic> json) {
    return AgentResponse(
      status: json['status'],
      chatId: json['chat_id'],
      prompt: json['prompt'],
      model: json['model'],
      outputFormat: json['output_format'],
      response: json['response'].toString(),
      context: json['context'] != null 
          ? ResponseContext.fromJson(json['context'])
          : null,
      metadata: json['metadata'] ?? {},
    );
  }
}

/// Context included with response (when show_context=true)
class ResponseContext {
  final int messageCount;
  final List<RecentMessage> recentMessages;
  final String chatName;
  final String? lastUpdated;
  
  ResponseContext({
    required this.messageCount,
    required this.recentMessages,
    required this.chatName,
    this.lastUpdated,
  });
  
  factory ResponseContext.fromJson(Map<String, dynamic> json) {
    return ResponseContext(
      messageCount: json['message_count'] ?? 0,
      recentMessages: (json['recent_messages'] as List?)
          ?.map((m) => RecentMessage.fromJson(m))
          .toList() ?? [],
      chatName: json['chat_name'] ?? 'Untitled',
      lastUpdated: json['last_updated'],
    );
  }
}

/// Batch chat info response
class BatchChatInfo {
  final List<ChatSummary> chats;
  final List<String> notFound;
  final int totalRequested;
  final int totalFound;
  
  BatchChatInfo({
    required this.chats,
    required this.notFound,
    required this.totalRequested,
    required this.totalFound,
  });
  
  factory BatchChatInfo.fromJson(Map<String, dynamic> json) {
    return BatchChatInfo(
      chats: (json['chats'] as List)
          .map((c) => ChatSummary.fromJson(c))
          .toList(),
      notFound: List<String>.from(json['not_found'] ?? []),
      totalRequested: json['total_requested'] ?? 0,
      totalFound: json['total_found'] ?? 0,
    );
  }
}

/// Available models list
class ModelsList {
  final List<String> models;
  final String defaultModel;
  final List<String> recommended;
  
  ModelsList({
    required this.models,
    required this.defaultModel,
    required this.recommended,
  });
  
  factory ModelsList.fromJson(Map<String, dynamic> json) {
    return ModelsList(
      models: List<String>.from(json['models'] ?? []),
      defaultModel: json['default'] ?? 'auto',
      recommended: List<String>.from(json['recommended'] ?? []),
    );
  }
}

/// API status information
class ApiStatus {
  final String name;
  final String version;
  final bool cursorAgentInstalled;
  final String? cursorAgentPath;
  
  ApiStatus({
    required this.name,
    required this.version,
    required this.cursorAgentInstalled,
    this.cursorAgentPath,
  });
  
  factory ApiStatus.fromJson(Map<String, dynamic> json) {
    final cursorAgent = json['cursor_agent'] as Map<String, dynamic>?;
    return ApiStatus(
      name: json['name'],
      version: json['version'],
      cursorAgentInstalled: cursorAgent?['installed'] ?? false,
      cursorAgentPath: cursorAgent?['path'],
    );
  }
}

// =============================================================================
// Exceptions
// =============================================================================

class CursorAgentException implements Exception {
  final String message;
  
  CursorAgentException(this.message);
  
  @override
  String toString() => 'CursorAgentException: $message';
}

class ChatNotFoundException extends CursorAgentException {
  final String chatId;
  
  ChatNotFoundException(this.chatId) : super('Chat not found: $chatId');
}

