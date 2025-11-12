import 'tool_call.dart';
import 'code_block.dart';
import 'todo_item.dart';

enum MessageRole {
  user,
  assistant,
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
    };
  }
}
