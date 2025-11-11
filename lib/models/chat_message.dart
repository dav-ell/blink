/// Represents a message in a chat session
class ChatMessage {
  final String id;
  final String sessionId;
  final String content;
  final DateTime timestamp;
  final MessageSender sender;
  final MessageType type;

  ChatMessage({
    required this.id,
    required this.sessionId,
    required this.content,
    required this.timestamp,
    required this.sender,
    required this.type,
  });

  /// Create a copy of this message with updated fields
  ChatMessage copyWith({
    String? id,
    String? sessionId,
    String? content,
    DateTime? timestamp,
    MessageSender? sender,
    MessageType? type,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      sender: sender ?? this.sender,
      type: type ?? this.type,
    );
  }
}

/// Who sent the message
enum MessageSender {
  user,   // Message from the phone user
  cursor, // Response from Cursor IDE
  system  // System message
}

/// Type of message
enum MessageType {
  text,    // Regular text message
  command, // Command to Cursor
  code,    // Code snippet
  error    // Error message
}
