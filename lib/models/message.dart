enum MessageRole {
  user,
  assistant,
}

class Message {
  final String id;
  final String content;
  final MessageRole role;
  final DateTime timestamp;

  Message({
    required this.id,
    required this.content,
    required this.role,
    required this.timestamp,
  });

  // TODO: Add fromJson factory for backend integration
  // factory Message.fromJson(Map<String, dynamic> json) {
  //   return Message(
  //     id: json['id'],
  //     content: json['content'],
  //     role: MessageRole.values.firstWhere((e) => e.name == json['role']),
  //     timestamp: DateTime.parse(json['timestamp']),
  //   );
  // }

  // TODO: Add toJson method for backend integration
  // Map<String, dynamic> toJson() {
  //   return {
  //     'id': id,
  //     'content': content,
  //     'role': role.name,
  //     'timestamp': timestamp.toIso8601String(),
  //   };
  // }
}
