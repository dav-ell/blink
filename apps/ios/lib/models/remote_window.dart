/// Represents a window available for streaming from the server
class RemoteWindow {
  final int id;
  final String title;
  final String appName;
  final WindowBounds bounds;
  final bool isMinimized;
  final bool isOnScreen;

  const RemoteWindow({
    required this.id,
    required this.title,
    required this.appName,
    required this.bounds,
    this.isMinimized = false,
    this.isOnScreen = true,
  });

  factory RemoteWindow.fromJson(Map<String, dynamic> json) {
    return RemoteWindow(
      id: json['id'] as int,
      title: json['title'] as String? ?? 'Untitled',
      appName: json['app'] as String? ?? 'Unknown',
      bounds: WindowBounds.fromJson(json['bounds'] as Map<String, dynamic>? ?? {}),
      isMinimized: json['is_minimized'] as bool? ?? false,
      isOnScreen: json['is_on_screen'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'app': appName,
      'bounds': bounds.toJson(),
      'is_minimized': isMinimized,
      'is_on_screen': isOnScreen,
    };
  }

  /// Display name combining app and window title
  String get displayName {
    if (title.contains(appName)) {
      return title;
    }
    return '$appName - $title';
  }

  /// Short name for tab display
  String get shortName {
    if (title.length > 20) {
      return '${title.substring(0, 17)}...';
    }
    return title;
  }

  /// Aspect ratio of the window
  double get aspectRatio {
    if (bounds.height == 0) return 16 / 9;
    return bounds.width / bounds.height;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RemoteWindow &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'RemoteWindow(id: $id, title: $title, app: $appName)';
}

/// Window position and size
class WindowBounds {
  final double x;
  final double y;
  final double width;
  final double height;

  const WindowBounds({
    this.x = 0,
    this.y = 0,
    this.width = 1920,
    this.height = 1080,
  });

  factory WindowBounds.fromJson(Map<String, dynamic> json) {
    return WindowBounds(
      x: (json['x'] as num?)?.toDouble() ?? 0,
      y: (json['y'] as num?)?.toDouble() ?? 0,
      width: (json['width'] as num?)?.toDouble() ?? 1920,
      height: (json['height'] as num?)?.toDouble() ?? 1080,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'x': x,
      'y': y,
      'width': width,
      'height': height,
    };
  }

  @override
  String toString() => 'WindowBounds($width x $height at $x, $y)';
}

