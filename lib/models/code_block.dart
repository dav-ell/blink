class CodeBlock {
  final String language;
  final String code;
  final int? startLine;
  final int? endLine;
  final String? filePath;

  CodeBlock({
    required this.language,
    required this.code,
    this.startLine,
    this.endLine,
    this.filePath,
  });

  factory CodeBlock.fromJson(Map<String, dynamic> json) {
    return CodeBlock(
      language: json['language'] ?? 'text',
      code: json['code'] ?? json['content'] ?? '',
      startLine: json['start_line'],
      endLine: json['end_line'],
      filePath: json['file_path'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'language': language,
      'code': code,
      'start_line': startLine,
      'end_line': endLine,
      'file_path': filePath,
    };
  }
}

