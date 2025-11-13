/// Device and remote chat models for HTTP-based remote agent orchestration

enum DeviceStatus {
  online,
  offline,
  unknown;

  static DeviceStatus fromString(String status) {
    switch (status.toLowerCase()) {
      case 'online':
        return DeviceStatus.online;
      case 'offline':
        return DeviceStatus.offline;
      default:
        return DeviceStatus.unknown;
    }
  }

  String get displayName {
    switch (this) {
      case DeviceStatus.online:
        return 'Online';
      case DeviceStatus.offline:
        return 'Offline';
      case DeviceStatus.unknown:
        return 'Unknown';
    }
  }
}

enum ChatLocation {
  local,
  remote;

  static ChatLocation fromString(String location) {
    return location.toLowerCase() == 'remote' 
        ? ChatLocation.remote 
        : ChatLocation.local;
  }
}

class Device {
  final String id;
  final String name;
  final String apiEndpoint;
  final String? apiKey;
  final String? cursorAgentPath;
  final DateTime createdAt;
  final DateTime? lastSeen;
  final bool isActive;
  final DeviceStatus status;

  Device({
    required this.id,
    required this.name,
    required this.apiEndpoint,
    this.apiKey,
    this.cursorAgentPath,
    required this.createdAt,
    this.lastSeen,
    this.isActive = true,
    this.status = DeviceStatus.unknown,
  });

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['id'],
      name: json['name'],
      apiEndpoint: json['api_endpoint'],
      apiKey: json['api_key'],
      cursorAgentPath: json['cursor_agent_path'],
      createdAt: DateTime.parse(json['created_at']),
      lastSeen: json['last_seen'] != null 
          ? DateTime.parse(json['last_seen']) 
          : null,
      isActive: json['is_active'] ?? true,
      status: DeviceStatus.fromString(json['status'] ?? 'unknown'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'api_endpoint': apiEndpoint,
      if (apiKey != null) 'api_key': apiKey,
      'cursor_agent_path': cursorAgentPath,
      'created_at': createdAt.toIso8601String(),
      'last_seen': lastSeen?.toIso8601String(),
      'is_active': isActive,
      'status': status.name,
    };
  }

  Device copyWith({
    String? name,
    String? apiEndpoint,
    String? apiKey,
    String? cursorAgentPath,
    DateTime? lastSeen,
    bool? isActive,
    DeviceStatus? status,
  }) {
    return Device(
      id: id,
      name: name ?? this.name,
      apiEndpoint: apiEndpoint ?? this.apiEndpoint,
      apiKey: apiKey ?? this.apiKey,
      cursorAgentPath: cursorAgentPath ?? this.cursorAgentPath,
      createdAt: createdAt,
      lastSeen: lastSeen ?? this.lastSeen,
      isActive: isActive ?? this.isActive,
      status: status ?? this.status,
    );
  }
}

class DeviceCreate {
  final String name;
  final String apiEndpoint;
  final String? apiKey;
  final String? cursorAgentPath;

  DeviceCreate({
    required this.name,
    required this.apiEndpoint,
    this.apiKey,
    this.cursorAgentPath,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'api_endpoint': apiEndpoint,
      if (apiKey != null) 'api_key': apiKey,
      if (cursorAgentPath != null) 'cursor_agent_path': cursorAgentPath,
    };
  }
}

class DeviceUpdate {
  final String? name;
  final String? apiEndpoint;
  final String? apiKey;
  final String? cursorAgentPath;
  final bool? isActive;

  DeviceUpdate({
    this.name,
    this.apiEndpoint,
    this.apiKey,
    this.cursorAgentPath,
    this.isActive,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (name != null) json['name'] = name;
    if (apiEndpoint != null) json['api_endpoint'] = apiEndpoint;
    if (apiKey != null) json['api_key'] = apiKey;
    if (cursorAgentPath != null) json['cursor_agent_path'] = cursorAgentPath;
    if (isActive != null) json['is_active'] = isActive;
    return json;
  }
}

class RemoteChatInfo {
  final String chatId;
  final String deviceId;
  final String deviceName;
  final DeviceStatus deviceStatus;
  final String workingDirectory;
  final String? lastMessagePreview;

  RemoteChatInfo({
    required this.chatId,
    required this.deviceId,
    required this.deviceName,
    required this.deviceStatus,
    required this.workingDirectory,
    this.lastMessagePreview,
  });

  factory RemoteChatInfo.fromJson(Map<String, dynamic> json) {
    return RemoteChatInfo(
      chatId: json['chat_id'],
      deviceId: json['device_id'],
      deviceName: json['device_name'] ?? 'Unknown',
      deviceStatus: DeviceStatus.fromString(json['device_status'] ?? 'unknown'),
      workingDirectory: json['working_directory'],
      lastMessagePreview: json['last_message_preview'],
    );
  }
}

class RemoteChatCreate {
  final String deviceId;
  final String workingDirectory;
  final String? name;

  RemoteChatCreate({
    required this.deviceId,
    required this.workingDirectory,
    this.name,
  });

  Map<String, dynamic> toJson() {
    return {
      'device_id': deviceId,
      'working_directory': workingDirectory,
      if (name != null) 'name': name,
    };
  }
}

class DeviceTestResult {
  final bool success;
  final String message;
  final DeviceStatus? status;
  final DateTime testedAt;

  DeviceTestResult({
    required this.success,
    required this.message,
    this.status,
    required this.testedAt,
  });

  factory DeviceTestResult.fromJson(Map<String, dynamic> json) {
    return DeviceTestResult(
      success: json['success'] ?? false,
      message: json['message'] ?? 'Unknown error',
      status: json['status'] != null 
          ? DeviceStatus.fromString(json['status']) 
          : null,
      testedAt: DateTime.parse(json['tested_at']),
    );
  }
}

class DirectoryEntry {
  final String name;
  final String permissions;
  final bool isDirectory;

  DirectoryEntry({
    required this.name,
    required this.permissions,
    required this.isDirectory,
  });

  factory DirectoryEntry.fromJson(Map<String, dynamic> json) {
    return DirectoryEntry(
      name: json['name'],
      permissions: json['permissions'],
      isDirectory: json['is_directory'] ?? false,
    );
  }
}

