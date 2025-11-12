/// A Result type for clean error handling
/// 
/// Use this instead of throwing exceptions to make error handling explicit
/// and easier to reason about.
/// 
/// Example:
/// ```dart
/// Future<Result<Chat, String>> fetchChat(String id) async {
///   try {
///     final chat = await repository.getChat(id);
///     return Result.success(chat);
///   } catch (e) {
///     return Result.failure('Failed to fetch chat: $e');
///   }
/// }
/// 
/// // Usage
/// final result = await fetchChat('123');
/// result.when(
///   success: (chat) => print('Got chat: ${chat.title}'),
///   failure: (error) => print('Error: $error'),
/// );
/// ```
sealed class Result<T, E> {
  const Result();
  
  /// Create a successful result
  factory Result.success(T value) = Success<T, E>;
  
  /// Create a failed result
  factory Result.failure(E error) = Failure<T, E>;
  
  /// Check if this is a success
  bool get isSuccess => this is Success<T, E>;
  
  /// Check if this is a failure
  bool get isFailure => this is Failure<T, E>;
  
  /// Get the value if success, or null if failure
  T? get valueOrNull => switch (this) {
    Success(value: final v) => v,
    Failure() => null,
  };
  
  /// Get the error if failure, or null if success
  E? get errorOrNull => switch (this) {
    Success() => null,
    Failure(error: final e) => e,
  };
  
  /// Get the value if success, or throw if failure
  T get valueOrThrow => switch (this) {
    Success(value: final v) => v,
    Failure(error: final e) => throw Exception('Called value on Failure: $e'),
  };
  
  /// Get the error if failure, or throw if success
  E get errorOrThrow => switch (this) {
    Success(value: final v) => throw Exception('Called error on Success: $v'),
    Failure(error: final e) => e,
  };
  
  /// Transform the success value
  Result<R, E> map<R>(R Function(T value) transform) {
    return switch (this) {
      Success(value: final v) => Result.success(transform(v)),
      Failure(error: final e) => Result.failure(e),
    };
  }
  
  /// Transform the error value
  Result<T, F> mapError<F>(F Function(E error) transform) {
    return switch (this) {
      Success(value: final v) => Result.success(v),
      Failure(error: final e) => Result.failure(transform(e)),
    };
  }
  
  /// Handle both success and failure cases
  R when<R>({
    required R Function(T value) success,
    required R Function(E error) failure,
  }) {
    return switch (this) {
      Success(value: final v) => success(v),
      Failure(error: final e) => failure(e),
    };
  }
  
  /// Execute side effects without transforming the result
  Result<T, E> tap({
    void Function(T value)? onSuccess,
    void Function(E error)? onFailure,
  }) {
    switch (this) {
      case Success(value: final v):
        onSuccess?.call(v);
      case Failure(error: final e):
        onFailure?.call(e);
    }
    return this;
  }
}

/// A successful result
final class Success<T, E> extends Result<T, E> {
  final T value;
  
  const Success(this.value);
  
  @override
  String toString() => 'Success($value)';
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Success<T, E> && value == other.value;
  
  @override
  int get hashCode => value.hashCode;
}

/// A failed result
final class Failure<T, E> extends Result<T, E> {
  final E error;
  
  const Failure(this.error);
  
  @override
  String toString() => 'Failure($error)';
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Failure<T, E> && error == other.error;
  
  @override
  int get hashCode => error.hashCode;
}

