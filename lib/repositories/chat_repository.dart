import 'package:http/http.dart' as http;
import '../core/result.dart';
import '../core/constants.dart';
import '../models/chat.dart';
import '../models/job.dart';
import '../services/cursor_agent_service.dart';

/// Repository for chat data operations
/// 
/// This is the single source of truth for all chat-related data access.
/// It wraps the HTTP service and provides a clean interface for the rest
/// of the app.
class ChatRepository {
  final CursorAgentService _agentService;
  
  ChatRepository({
    CursorAgentService? agentService,
    http.Client? httpClient,
  }) : _agentService = agentService ?? 
          CursorAgentService(
            baseUrl: AppConstants.apiBaseUrl,
            client: httpClient,
          );
  
  // =========================================================================
  // Chat Operations
  // =========================================================================
  
  /// Fetch all chats with optional filters
  Future<Result<List<Chat>, String>> fetchChats({
    bool includeArchived = false,
    String sortBy = 'last_updated',
    int? limit,
  }) async {
    try {
      final chats = await _agentService.listExistingChats(
        includeArchived: includeArchived,
        sortBy: sortBy,
        limit: limit,
      );
      return Result.success(chats);
    } on CursorAgentException catch (e) {
      return Result.failure(e.message);
    } catch (e) {
      return Result.failure('Failed to fetch chats: $e');
    }
  }
  
  /// Fetch a specific chat with all its messages
  Future<Result<Chat, String>> fetchChat(String chatId) async {
    try {
      final chat = await _agentService.getChatDetails(chatId);
      return Result.success(chat);
    } on ChatNotFoundException catch (e) {
      return Result.failure(e.message);
    } on CursorAgentException catch (e) {
      return Result.failure(e.message);
    } catch (e) {
      return Result.failure('Failed to fetch chat: $e');
    }
  }
  
  /// Fetch chat summary (lighter response for list views)
  Future<Result<ChatSummary, String>> fetchChatSummary(
    String chatId, {
    int recentCount = 5,
  }) async {
    try {
      final summary = await _agentService.getChatSummary(
        chatId,
        recentCount: recentCount,
      );
      return Result.success(summary);
    } on ChatNotFoundException catch (e) {
      return Result.failure(e.message);
    } on CursorAgentException catch (e) {
      return Result.failure(e.message);
    } catch (e) {
      return Result.failure('Failed to fetch chat summary: $e');
    }
  }
  
  /// Fetch multiple chat summaries at once
  Future<Result<BatchChatInfo, String>> fetchBatchChatInfo(
    List<String> chatIds,
  ) async {
    try {
      final batch = await _agentService.getBatchChatInfo(chatIds);
      return Result.success(batch);
    } on CursorAgentException catch (e) {
      return Result.failure(e.message);
    } catch (e) {
      return Result.failure('Failed to fetch batch chat info: $e');
    }
  }
  
  /// Create a new chat
  Future<Result<String, String>> createChat() async {
    try {
      final chatId = await _agentService.createNewChat();
      return Result.success(chatId);
    } on CursorAgentException catch (e) {
      return Result.failure(e.message);
    } catch (e) {
      return Result.failure('Failed to create chat: $e');
    }
  }
  
  // =========================================================================
  // Async Job Operations
  // =========================================================================
  
  /// Submit a prompt asynchronously
  Future<Result<Job, String>> submitPrompt(
    String chatId,
    String prompt, {
    String? model,
  }) async {
    try {
      final job = await _agentService.submitPromptAsync(
        chatId,
        prompt,
        model: model,
      );
      return Result.success(job);
    } on ChatNotFoundException catch (e) {
      return Result.failure(e.message);
    } on CursorAgentException catch (e) {
      return Result.failure(e.message);
    } catch (e) {
      return Result.failure('Failed to submit prompt: $e');
    }
  }
  
  /// Get job details
  Future<Result<Job, String>> getJobDetails(String jobId) async {
    try {
      final job = await _agentService.getJobDetails(jobId);
      return Result.success(job);
    } on CursorAgentException catch (e) {
      return Result.failure(e.message);
    } catch (e) {
      return Result.failure('Failed to get job details: $e');
    }
  }
  
  /// Get job status (lighter response)
  Future<Result<Map<String, dynamic>, String>> getJobStatus(
    String jobId,
  ) async {
    try {
      final status = await _agentService.getJobStatus(jobId);
      return Result.success(status);
    } on CursorAgentException catch (e) {
      return Result.failure(e.message);
    } catch (e) {
      return Result.failure('Failed to get job status: $e');
    }
  }
  
  /// List all jobs for a chat
  Future<Result<List<Job>, String>> listChatJobs(
    String chatId, {
    int limit = 20,
    String? statusFilter,
  }) async {
    try {
      final jobs = await _agentService.listChatJobs(
        chatId,
        limit: limit,
        statusFilter: statusFilter,
      );
      return Result.success(jobs);
    } on CursorAgentException catch (e) {
      return Result.failure(e.message);
    } catch (e) {
      return Result.failure('Failed to list chat jobs: $e');
    }
  }
  
  /// Cancel a job
  Future<Result<void, String>> cancelJob(String jobId) async {
    try {
      await _agentService.cancelJob(jobId);
      return Result.success(null);
    } on CursorAgentException catch (e) {
      return Result.failure(e.message);
    } catch (e) {
      return Result.failure('Failed to cancel job: $e');
    }
  }
  
  // =========================================================================
  // Health & Status
  // =========================================================================
  
  /// Check API health
  Future<Result<ApiStatus, String>> checkHealth() async {
    try {
      final status = await _agentService.checkStatus();
      return Result.success(status);
    } on CursorAgentException catch (e) {
      return Result.failure(e.message);
    } catch (e) {
      return Result.failure('Failed to check health: $e');
    }
  }
  
  /// Get available AI models
  Future<Result<ModelsList, String>> getAvailableModels() async {
    try {
      final models = await _agentService.getAvailableModels();
      return Result.success(models);
    } on CursorAgentException catch (e) {
      return Result.failure(e.message);
    } catch (e) {
      return Result.failure('Failed to get models: $e');
    }
  }
  
  /// Dispose resources
  void dispose() {
    _agentService.dispose();
  }
}

