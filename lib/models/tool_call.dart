class ToolCall {
  final String name;
  final String? explanation;
  final String? command;
  final Map<String, dynamic>? arguments;

  ToolCall({
    required this.name,
    this.explanation,
    this.command,
    this.arguments,
  });

  factory ToolCall.fromJson(Map<String, dynamic> json) {
    return ToolCall(
      name: json['name'] ?? 'unknown',
      explanation: json['explanation'],
      command: json['command'],
      arguments: json['arguments'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'explanation': explanation,
      'command': command,
      'arguments': arguments,
    };
  }
}

