import 'dart:async';

/// Generic cache service with TTL (Time To Live) support
/// 
/// Example:
/// ```dart
/// final cache = CacheService<String, Chat>(
///   expiry: Duration(minutes: 5),
/// );
/// 
/// // Store value
/// cache.set('chat-123', myChat);
/// 
/// // Retrieve value
/// final chat = cache.get('chat-123');
/// 
/// // Check if valid
/// if (cache.isValid('chat-123')) {
///   // Use cached value
/// }
/// ```
class CacheService<K, V> {
  final Duration expiry;
  final Map<K, _CacheEntry<V>> _cache = {};
  Timer? _cleanupTimer;
  
  CacheService({
    required this.expiry,
    bool enableAutoCleanup = true,
  }) {
    if (enableAutoCleanup) {
      _startCleanupTimer();
    }
  }
  
  /// Store a value in the cache
  void set(K key, V value) {
    _cache[key] = _CacheEntry(
      value: value,
      timestamp: DateTime.now(),
    );
  }
  
  /// Get a value from the cache
  /// Returns null if not found or expired
  V? get(K key) {
    final entry = _cache[key];
    if (entry == null) return null;
    
    if (_isExpired(entry.timestamp)) {
      _cache.remove(key);
      return null;
    }
    
    return entry.value;
  }
  
  /// Check if a cached value exists and is valid
  bool isValid(K key) {
    final entry = _cache[key];
    if (entry == null) return false;
    
    return !_isExpired(entry.timestamp);
  }
  
  /// Remove a specific key from the cache
  void remove(K key) {
    _cache.remove(key);
  }
  
  /// Clear all cached values
  void clear() {
    _cache.clear();
  }
  
  /// Get all keys in the cache
  Iterable<K> get keys => _cache.keys;
  
  /// Get the number of cached items
  int get length => _cache.length;
  
  /// Check if cache is empty
  bool get isEmpty => _cache.isEmpty;
  
  /// Check if cache is not empty
  bool get isNotEmpty => _cache.isNotEmpty;
  
  /// Get or compute a value
  /// If key exists and is valid, returns cached value
  /// Otherwise computes and caches the value
  Future<V> getOrCompute(
    K key,
    Future<V> Function() compute,
  ) async {
    final cached = get(key);
    if (cached != null) return cached;
    
    final value = await compute();
    set(key, value);
    return value;
  }
  
  /// Clean up expired entries
  void cleanup() {
    final now = DateTime.now();
    _cache.removeWhere((key, entry) => _isExpired(entry.timestamp, now: now));
  }
  
  /// Start automatic cleanup timer
  void _startCleanupTimer() {
    // Run cleanup periodically (every minute or every expiry duration, whichever is longer)
    final interval = expiry > const Duration(minutes: 1)
        ? expiry
        : const Duration(minutes: 1);
    
    _cleanupTimer = Timer.periodic(interval, (_) => cleanup());
  }
  
  /// Check if a timestamp is expired
  bool _isExpired(DateTime timestamp, {DateTime? now}) {
    now ??= DateTime.now();
    return now.difference(timestamp) > expiry;
  }
  
  /// Dispose the cache and stop cleanup timer
  void dispose() {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    _cache.clear();
  }
}

/// Internal cache entry with timestamp
class _CacheEntry<V> {
  final V value;
  final DateTime timestamp;
  
  _CacheEntry({
    required this.value,
    required this.timestamp,
  });
}

