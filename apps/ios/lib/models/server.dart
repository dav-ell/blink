/// Represents a discovered stream server
class StreamServer {
  final String id;
  final String name;
  final String host;
  final int port;
  final String? version;
  final DateTime? lastSeen;
  final bool isManualEntry;

  const StreamServer({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    this.version,
    this.lastSeen,
    this.isManualEntry = false,
  });

  factory StreamServer.fromMdns({
    required String name,
    required String host,
    required int port,
    Map<String, String>? txtRecords,
  }) {
    return StreamServer(
      id: '$host:$port',
      name: txtRecords?['name'] ?? name,
      host: host,
      port: port,
      version: txtRecords?['version'],
      lastSeen: DateTime.now(),
      isManualEntry: false,
    );
  }

  factory StreamServer.manual({
    required String host,
    required int port,
    String? name,
  }) {
    return StreamServer(
      id: '$host:$port',
      name: name ?? host,
      host: host,
      port: port,
      lastSeen: DateTime.now(),
      isManualEntry: true,
    );
  }

  factory StreamServer.fromJson(Map<String, dynamic> json) {
    return StreamServer(
      id: json['id'] as String,
      name: json['name'] as String,
      host: json['host'] as String,
      port: json['port'] as int,
      version: json['version'] as String?,
      lastSeen: json['last_seen'] != null
          ? DateTime.parse(json['last_seen'] as String)
          : null,
      isManualEntry: json['is_manual_entry'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'host': host,
      'port': port,
      'version': version,
      'last_seen': lastSeen?.toIso8601String(),
      'is_manual_entry': isManualEntry,
    };
  }

  /// WebSocket URL for signaling
  String get signalingUrl => 'ws://$host:$port/signaling';

  /// WebSocket URL for window management
  String get windowsUrl => 'ws://$host:$port/windows';

  /// WebSocket URL for input
  String get inputUrl => 'ws://$host:$port/input';

  /// HTTP URL for health check
  String get healthUrl => 'http://$host:$port/health';

  /// Display string for UI
  String get displayAddress => '$host:$port';

  /// Copy with updated lastSeen
  StreamServer copyWith({
    String? id,
    String? name,
    String? host,
    int? port,
    String? version,
    DateTime? lastSeen,
    bool? isManualEntry,
  }) {
    return StreamServer(
      id: id ?? this.id,
      name: name ?? this.name,
      host: host ?? this.host,
      port: port ?? this.port,
      version: version ?? this.version,
      lastSeen: lastSeen ?? this.lastSeen,
      isManualEntry: isManualEntry ?? this.isManualEntry,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StreamServer &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'StreamServer($name at $host:$port)';
}

