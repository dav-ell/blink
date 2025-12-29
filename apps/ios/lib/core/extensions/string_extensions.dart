/// Extension methods for String manipulation
extension StringExtensions on String {
  /// Truncate string to maxLength with ellipsis
  String truncate(int maxLength, {String ellipsis = '...'}) {
    if (length <= maxLength) return this;
    return '${substring(0, maxLength - ellipsis.length)}$ellipsis';
  }
  
  /// Check if string contains code blocks (markdown code fences)
  bool get hasCodeBlock {
    return contains('```');
  }
  
  /// Check if string is empty or only whitespace
  bool get isBlank {
    return trim().isEmpty;
  }
  
  /// Check if string is not empty and not only whitespace
  bool get isNotBlank {
    return !isBlank;
  }
  
  /// Capitalize first letter
  String get capitalize {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
  
  /// Convert to title case (capitalize each word)
  String get toTitleCase {
    if (isEmpty) return this;
    return split(' ')
        .map((word) => word.capitalize)
        .join(' ');
  }
}

/// Extension methods for nullable strings
extension NullableStringExtensions on String? {
  /// Return this string or empty string if null
  String get orEmpty => this ?? '';
  
  /// Check if string is null or empty
  bool get isNullOrEmpty => this == null || this!.isEmpty;
  
  /// Check if string is null, empty, or only whitespace
  bool get isNullOrBlank => this == null || this!.isBlank;
}

