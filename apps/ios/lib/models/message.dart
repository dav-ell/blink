import 'tool_call.dart';
import 'code_block.dart';
import 'todo_item.dart';

enum MessageRole {
  user,
  assistant,
}

enum MessageStatus {
  pending,    // Message created, not yet sent
  sending,    // Being sent to backend
  processing, // Backend is processing (cursor-agent running)
  completed,  // Successfully completed
  failed,     // Failed to send or process
}

class Message {
  final String id;
  final String bubbleId;
  final String content;
  final MessageRole role;
  final DateTime timestamp;
  final int type;
  final String typeLabel;
  final bool hasToolCall;
  final bool hasThinking;
  final bool hasCode;
  final bool hasTodos;
  // Separated content fields
  final List<ToolCall>? toolCalls;
  final String? thinkingContent;
  final List<CodeBlock>? codeBlocks;
  final List<TodoItem>? todos;
  // Async status fields
  final MessageStatus status;
  final String? jobId;
  final DateTime? sentAt;
  final DateTime? processingStartedAt;
  final DateTime? completedAt;
  final String? errorMessage;

  Message({
    required this.id,
    required this.bubbleId,
    required this.content,
    required this.role,
    required this.timestamp,
    required this.type,
    required this.typeLabel,
    this.hasToolCall = false,
    this.hasThinking = false,
    this.hasCode = false,
    this.hasTodos = false,
    this.toolCalls,
    this.thinkingContent,
    this.codeBlocks,
    this.todos,
    this.status = MessageStatus.completed, // Default for existing messages
    this.jobId,
    this.sentAt,
    this.processingStartedAt,
    this.completedAt,
    this.errorMessage,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    final typeLabel = json['type_label'] ?? 'user';
    
    // Parse tool calls
    List<ToolCall>? toolCalls;
    if (json['tool_calls'] != null && json['tool_calls'] is List) {
      toolCalls = (json['tool_calls'] as List)
          .map((tc) => ToolCall.fromJson(tc as Map<String, dynamic>))
          .toList();
    }
    
    // Parse code blocks
    List<CodeBlock>? codeBlocks;
    if (json['code_blocks'] != null && json['code_blocks'] is List) {
      codeBlocks = (json['code_blocks'] as List)
          .map((cb) => CodeBlock.fromJson(cb as Map<String, dynamic>))
          .toList();
    }
    
    // Parse todos
    List<TodoItem>? todos;
    if (json['todos'] != null && json['todos'] is List) {
      todos = (json['todos'] as List)
          .map((td) => TodoItem.fromJson(td as Map<String, dynamic>))
          .toList();
    }
    
    // Parse status
    MessageStatus status = MessageStatus.completed;
    if (json['status'] != null) {
      status = MessageStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => MessageStatus.completed,
      );
    }
    
    return Message(
      id: json['bubble_id'] ?? json['id'] ?? '',
      bubbleId: json['bubble_id'] ?? '',
      content: json['text'] ?? json['content'] ?? '',
      role: typeLabel == 'assistant' ? MessageRole.assistant : MessageRole.user,
      timestamp: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      type: json['type'] ?? 1,
      typeLabel: typeLabel,
      hasToolCall: json['has_tool_call'] ?? false,
      hasThinking: json['has_thinking'] ?? false,
      hasCode: json['has_code'] ?? false,
      hasTodos: json['has_todos'] ?? false,
      toolCalls: toolCalls,
      thinkingContent: json['thinking_content'],
      codeBlocks: codeBlocks,
      todos: todos,
      status: status,
      jobId: json['job_id'],
      sentAt: json['sent_at'] != null ? DateTime.parse(json['sent_at']) : null,
      processingStartedAt: json['processing_started_at'] != null
          ? DateTime.parse(json['processing_started_at'])
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'])
          : null,
      errorMessage: json['error_message'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bubble_id': bubbleId,
      'text': content,
      'type': type,
      'type_label': typeLabel,
      'created_at': timestamp.toIso8601String(),
      'has_tool_call': hasToolCall,
      'has_thinking': hasThinking,
      'has_code': hasCode,
      'has_todos': hasTodos,
      'status': status.name,
      'job_id': jobId,
      'sent_at': sentAt?.toIso8601String(),
      'processing_started_at': processingStartedAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'error_message': errorMessage,
    };
  }

  /// Get elapsed time in seconds since processing started
  double? getElapsedSeconds() {
    if (processingStartedAt == null) return null;
    final endTime = completedAt ?? DateTime.now();
    return endTime.difference(processingStartedAt!).inMilliseconds / 1000.0;
  }

  /// Check if message is currently being processed
  bool get isProcessing =>
      status == MessageStatus.sending || status == MessageStatus.processing;

  /// Check if message has completed successfully
  bool get isCompleted => status == MessageStatus.completed;

  /// Check if message has failed
  bool get isFailed => status == MessageStatus.failed;

  /// Create a copy of this message with some fields replaced
  Message copyWith({
    String? id,
    String? bubbleId,
    String? content,
    MessageRole? role,
    DateTime? timestamp,
    int? type,
    String? typeLabel,
    bool? hasToolCall,
    bool? hasThinking,
    bool? hasCode,
    bool? hasTodos,
    List<ToolCall>? toolCalls,
    String? thinkingContent,
    List<CodeBlock>? codeBlocks,
    List<TodoItem>? todos,
    MessageStatus? status,
    String? jobId,
    DateTime? sentAt,
    DateTime? processingStartedAt,
    DateTime? completedAt,
    String? errorMessage,
  }) {
    return Message(
      id: id ?? this.id,
      bubbleId: bubbleId ?? this.bubbleId,
      content: content ?? this.content,
      role: role ?? this.role,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      typeLabel: typeLabel ?? this.typeLabel,
      hasToolCall: hasToolCall ?? this.hasToolCall,
      hasThinking: hasThinking ?? this.hasThinking,
      hasCode: hasCode ?? this.hasCode,
      hasTodos: hasTodos ?? this.hasTodos,
      toolCalls: toolCalls ?? this.toolCalls,
      thinkingContent: thinkingContent ?? this.thinkingContent,
      codeBlocks: codeBlocks ?? this.codeBlocks,
      todos: todos ?? this.todos,
      status: status ?? this.status,
      jobId: jobId ?? this.jobId,
      sentAt: sentAt ?? this.sentAt,
      processingStartedAt: processingStartedAt ?? this.processingStartedAt,
      completedAt: completedAt ?? this.completedAt,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
