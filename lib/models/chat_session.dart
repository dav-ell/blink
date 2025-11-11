/// Represents a chat session with the Cursor IDE
class ChatSession {
  final String id;
  final String title;
  final DateTime startTime;
  final DateTime lastActivityTime;
  final ChatStatus status;
  final int messageCount;

  ChatSession({
    required this.id,
    required this.title,
    required this.startTime,
    required this.lastActivityTime,
    required this.status,
    required this.messageCount,
  });

  /// Create a copy of this session with updated fields
  ChatSession copyWith({
    String? id,
    String? title,
    DateTime? startTime,
    DateTime? lastActivityTime,
    ChatStatus? status,
    int? messageCount,
  }) {
    return ChatSession(
      id: id ?? this.id,
      title: title ?? this.title,
      startTime: startTime ?? this.startTime,
      lastActivityTime: lastActivityTime ?? this.lastActivityTime,
      status: status ?? this.status,
      messageCount: messageCount ?? this.messageCount,
    );
  }
}

/// Status of a chat session
enum ChatStatus {
  active,   // Currently running
  idle,     // Not running but available
  completed // Session has ended
}
