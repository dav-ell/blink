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
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    final typeLabel = json['type_label'] ?? 'user';
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
