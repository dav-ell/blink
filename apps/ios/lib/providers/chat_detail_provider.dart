import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/chat.dart';
import '../models/message.dart';
import '../models/job.dart';
import '../services/chat_service.dart';
import '../repositories/chat_repository.dart';
import 'job_polling_provider.dart';

/// Provider for managing chat detail state
/// 
/// Manages:
/// - Single chat with messages
/// - Message sending
/// - Job polling for async operations
/// - Loading/error states
class ChatDetailProvider with ChangeNotifier {
  final ChatService _chatService;
  final ChatRepository _repository;
  final JobPollingProvider _jobPollingProvider;
  
  Chat? _chat;
  bool _isLoading = false;
  bool _isSending = false;
  String _errorMessage = '';
  
  // Track pending messages (being processed)
  final Map<String, Message> _pendingMessages = {};
  
  ChatDetailProvider({
    ChatService? chatService,
    ChatRepository? repository,
    JobPollingProvider? jobPollingProvider,
  })  : _chatService = chatService ?? ChatService(),
        _repository = repository ?? ChatRepository(),
        _jobPollingProvider = jobPollingProvider ?? JobPollingProvider();
  
  // Getters
  Chat? get chat => _chat;
  bool get isLoading => _isLoading;
  bool get isSending => _isSending;
  String get errorMessage => _errorMessage;
  bool get hasError => _errorMessage.isNotEmpty;
  int get activeJobCount => _jobPollingProvider.activeJobCount;
  bool get hasChat => _chat != null;
  
  /// Load chat details
  Future<void> loadChat(String chatId, {bool forceRefresh = false}) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();
    
    try {
      final chat = await _chatService.fetchChat(
        chatId,
        forceRefresh: forceRefresh,
      );
      
      _chat = chat;
      
      // Resume any active jobs
      await _resumeActiveJobs(chatId);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Send a message asynchronously
  Future<void> sendMessage(String messageText) async {
    if (_chat == null || messageText.trim().isEmpty || _isSending) {
      return;
    }
    
    _isSending = true;
    _errorMessage = '';
    notifyListeners();
    
    try {
      // Submit prompt asynchronously
      final result = await _repository.submitPrompt(
        _chat!.id,
        messageText,
      );
      
      await result.when(
        success: (job) async {
          // Create pending message
          final pendingMessage = Message(
            id: job.jobId,
            bubbleId: '',
            content: messageText,
            role: MessageRole.user,
            timestamp: DateTime.now(),
            type: 1,
            typeLabel: 'user',
            status: MessageStatus.processing,
            jobId: job.jobId,
            sentAt: DateTime.now(),
            processingStartedAt: DateTime.now(),
          );
          
          // Add to pending messages
          _pendingMessages[job.jobId] = pendingMessage;
          
          // Add to chat messages
          _chat = Chat(
            id: _chat!.id,
            title: _chat!.title,
            status: _chat!.status,
            createdAt: _chat!.createdAt,
            lastMessageAt: DateTime.now(),
            messages: [..._chat!.messages, pendingMessage],
            isArchived: _chat!.isArchived,
            isDraft: _chat!.isDraft,
            totalLinesAdded: _chat!.totalLinesAdded,
            totalLinesRemoved: _chat!.totalLinesRemoved,
            subtitle: _chat!.subtitle,
            unifiedMode: _chat!.unifiedMode,
            contextUsagePercent: _chat!.contextUsagePercent,
          );
          
          notifyListeners();
          
          // Start polling for job
          await _startPollingJob(job.jobId);
        },
        failure: (error) {
          _errorMessage = error;
          notifyListeners();
        },
      );
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }
  
  /// Retry a failed message
  Future<void> retryMessage(Message failedMessage) async {
    if (_chat == null) return;
    
    // Remove the failed message
    _chat = Chat(
      id: _chat!.id,
      title: _chat!.title,
      status: _chat!.status,
      createdAt: _chat!.createdAt,
      lastMessageAt: _chat!.lastMessageAt,
      messages: _chat!.messages.where((m) => m.id != failedMessage.id).toList(),
      isArchived: _chat!.isArchived,
      isDraft: _chat!.isDraft,
      totalLinesAdded: _chat!.totalLinesAdded,
      totalLinesRemoved: _chat!.totalLinesRemoved,
      subtitle: _chat!.subtitle,
      unifiedMode: _chat!.unifiedMode,
      contextUsagePercent: _chat!.contextUsagePercent,
    );
    notifyListeners();
    
    // Retry by sending again
    await sendMessage(failedMessage.content);
  }
  
  /// Start polling a job
  Future<void> _startPollingJob(String jobId) async {
    await _jobPollingProvider.startPolling(
      jobId,
      onUpdate: (job) => _handleJobUpdate(job),
      onComplete: (job) => _handleJobComplete(job),
      onFailed: (job, error) => _handleJobFailed(job, error),
    );
  }
  
  /// Resume active jobs from backend
  Future<void> _resumeActiveJobs(String chatId) async {
    final result = await _repository.listChatJobs(
      chatId,
      limit: 10,
      statusFilter: 'processing',
    );
    
    await result.when(
      success: (jobs) async {
        for (final job in jobs) {
          if (job.isProcessing) {
            await _startPollingJob(job.jobId);
          }
        }
      },
      failure: (_) {
        // Silently fail - not critical
      },
    );
  }
  
  /// Handle job update
  void _handleJobUpdate(Job job) {
    if (_pendingMessages.containsKey(job.jobId) && _chat != null) {
      final message = _pendingMessages[job.jobId]!;
      final updatedMessage = message.copyWith(
        status: job.status == JobStatus.processing
            ? MessageStatus.processing
            : MessageStatus.pending,
        processingStartedAt: job.startedAt,
      );
      
      _pendingMessages[job.jobId] = updatedMessage;
      _updateMessageInChat(updatedMessage);
    }
  }
  
  /// Handle job completion
  void _handleJobComplete(Job job) {
    _pendingMessages.remove(job.jobId);
    // Reload chat to get actual messages from backend
    if (_chat != null) {
      loadChat(_chat!.id, forceRefresh: true);
    }
  }
  
  /// Handle job failure
  void _handleJobFailed(Job job, String error) {
    if (_pendingMessages.containsKey(job.jobId) && _chat != null) {
      final message = _pendingMessages[job.jobId]!;
      final updatedMessage = message.copyWith(
        status: MessageStatus.failed,
        completedAt: DateTime.now(),
        errorMessage: error,
      );
      
      _updateMessageInChat(updatedMessage);
      _pendingMessages.remove(job.jobId);
    }
  }
  
  /// Update a message in the chat
  void _updateMessageInChat(Message updatedMessage) {
    if (_chat == null) return;
    
    final index = _chat!.messages.indexWhere((m) => m.jobId == updatedMessage.jobId);
    if (index >= 0) {
      final updatedMessages = List<Message>.from(_chat!.messages);
      updatedMessages[index] = updatedMessage;
      
      _chat = Chat(
        id: _chat!.id,
        title: _chat!.title,
        status: _chat!.status,
        createdAt: _chat!.createdAt,
        lastMessageAt: _chat!.lastMessageAt,
        messages: updatedMessages,
        isArchived: _chat!.isArchived,
        isDraft: _chat!.isDraft,
        totalLinesAdded: _chat!.totalLinesAdded,
        totalLinesRemoved: _chat!.totalLinesRemoved,
        subtitle: _chat!.subtitle,
        unifiedMode: _chat!.unifiedMode,
        contextUsagePercent: _chat!.contextUsagePercent,
      );
      
      notifyListeners();
    }
  }
  
  /// Clear error message
  void clearError() {
    _errorMessage = '';
    notifyListeners();
  }
  
  /// Clear current chat
  void clear() {
    _chat = null;
    _pendingMessages.clear();
    _jobPollingProvider.stopAll();
    notifyListeners();
  }
  
  @override
  void dispose() {
    _jobPollingProvider.stopAll();
    // Don't dispose singleton services - they're managed by the service locator
    // _chatService.dispose();
    // _repository.dispose();
    super.dispose();
  }
}

