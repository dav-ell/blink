enum JobStatus {
  pending,
  processing,
  completed,
  failed,
  cancelled,
}

class Job {
  final String jobId;
  final String chatId;
  final String prompt;
  final JobStatus status;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? result;
  final String? error;
  final String? userBubbleId;
  final String? assistantBubbleId;
  final String? model;

  Job({
    required this.jobId,
    required this.chatId,
    required this.prompt,
    required this.status,
    required this.createdAt,
    this.startedAt,
    this.completedAt,
    this.result,
    this.error,
    this.userBubbleId,
    this.assistantBubbleId,
    this.model,
  });

  factory Job.fromJson(Map<String, dynamic> json) {
    // Parse status
    JobStatus status = JobStatus.pending;
    if (json['status'] != null) {
      status = JobStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => JobStatus.pending,
      );
    }

    return Job(
      jobId: json['job_id'] ?? '',
      chatId: json['chat_id'] ?? '',
      prompt: json['prompt'] ?? '',
      status: status,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      startedAt: json['started_at'] != null
          ? DateTime.parse(json['started_at'])
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'])
          : null,
      result: json['result'],
      error: json['error'],
      userBubbleId: json['user_bubble_id'],
      assistantBubbleId: json['assistant_bubble_id'],
      model: json['model'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'job_id': jobId,
      'chat_id': chatId,
      'prompt': prompt,
      'status': status.name,
      'created_at': createdAt.toIso8601String(),
      'started_at': startedAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'result': result,
      'error': error,
      'user_bubble_id': userBubbleId,
      'assistant_bubble_id': assistantBubbleId,
      'model': model,
    };
  }

  /// Get elapsed time in seconds
  double? getElapsedSeconds() {
    if (startedAt == null) return null;
    final endTime = completedAt ?? DateTime.now();
    return endTime.difference(startedAt!).inMilliseconds / 1000.0;
  }

  /// Check if job is currently processing
  bool get isProcessing =>
      status == JobStatus.pending || status == JobStatus.processing;

  /// Check if job has completed successfully
  bool get isCompleted => status == JobStatus.completed;

  /// Check if job has failed
  bool get isFailed => status == JobStatus.failed;

  /// Check if job was cancelled
  bool get isCancelled => status == JobStatus.cancelled;

  /// Create a copy of this job with some fields replaced
  Job copyWith({
    String? jobId,
    String? chatId,
    String? prompt,
    JobStatus? status,
    DateTime? createdAt,
    DateTime? startedAt,
    DateTime? completedAt,
    String? result,
    String? error,
    String? userBubbleId,
    String? assistantBubbleId,
    String? model,
  }) {
    return Job(
      jobId: jobId ?? this.jobId,
      chatId: chatId ?? this.chatId,
      prompt: prompt ?? this.prompt,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      result: result ?? this.result,
      error: error ?? this.error,
      userBubbleId: userBubbleId ?? this.userBubbleId,
      assistantBubbleId: assistantBubbleId ?? this.assistantBubbleId,
      model: model ?? this.model,
    );
  }
}

