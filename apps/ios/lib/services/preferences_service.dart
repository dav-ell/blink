import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/server.dart';

/// Service for persisting user preferences
class PreferencesService extends ChangeNotifier {
  static const String _recentServersKey = 'recent_servers';
  static const String _preferredServerKey = 'preferred_server';
  static const String _autoConnectKey = 'auto_connect';
  static const int _maxRecentServers = 10;

  SharedPreferences? _prefs;
  List<StreamServer> _recentServers = [];
  StreamServer? _preferredServer;
  bool _autoConnect = false;

  List<StreamServer> get recentServers => List.unmodifiable(_recentServers);
  StreamServer? get preferredServer => _preferredServer;
  bool get autoConnect => _autoConnect;

  /// Initialize the preferences service
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    // Load recent servers
    final serversJson = _prefs?.getString(_recentServersKey);
    if (serversJson != null) {
      try {
        final serversList = jsonDecode(serversJson) as List;
        _recentServers = serversList
            .map((s) => StreamServer.fromJson(s as Map<String, dynamic>))
            .toList();
      } catch (e) {
        debugPrint('Error loading recent servers: $e');
        _recentServers = [];
      }
    }

    // Load preferred server
    final preferredJson = _prefs?.getString(_preferredServerKey);
    if (preferredJson != null) {
      try {
        _preferredServer = StreamServer.fromJson(
          jsonDecode(preferredJson) as Map<String, dynamic>,
        );
      } catch (e) {
        debugPrint('Error loading preferred server: $e');
      }
    }

    // Load auto-connect setting
    _autoConnect = _prefs?.getBool(_autoConnectKey) ?? false;

    notifyListeners();
  }

  /// Add a server to recent servers list
  Future<void> addRecentServer(StreamServer server) async {
    // Remove if already exists
    _recentServers.removeWhere((s) => s.id == server.id);
    
    // Add to front
    _recentServers.insert(0, server.copyWith(lastSeen: DateTime.now()));
    
    // Trim to max size
    if (_recentServers.length > _maxRecentServers) {
      _recentServers = _recentServers.take(_maxRecentServers).toList();
    }

    await _saveRecentServers();
    notifyListeners();
  }

  /// Remove a server from recent servers
  Future<void> removeRecentServer(String serverId) async {
    _recentServers.removeWhere((s) => s.id == serverId);
    await _saveRecentServers();
    notifyListeners();
  }

  /// Clear all recent servers
  Future<void> clearRecentServers() async {
    _recentServers.clear();
    await _prefs?.remove(_recentServersKey);
    notifyListeners();
  }

  /// Set the preferred server
  Future<void> setPreferredServer(StreamServer? server) async {
    _preferredServer = server;
    
    if (server != null) {
      await _prefs?.setString(_preferredServerKey, jsonEncode(server.toJson()));
    } else {
      await _prefs?.remove(_preferredServerKey);
    }
    
    notifyListeners();
  }

  /// Set auto-connect preference
  Future<void> setAutoConnect(bool value) async {
    _autoConnect = value;
    await _prefs?.setBool(_autoConnectKey, value);
    notifyListeners();
  }

  Future<void> _saveRecentServers() async {
    final json = jsonEncode(_recentServers.map((s) => s.toJson()).toList());
    await _prefs?.setString(_recentServersKey, json);
  }
}

