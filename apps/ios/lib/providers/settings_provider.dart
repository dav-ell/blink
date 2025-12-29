import 'package:flutter/foundation.dart';
import '../services/settings_service.dart';

class SettingsProvider with ChangeNotifier {
  final SettingsService _settingsService = SettingsService();
  String _apiEndpoint = 'http://localhost:8067';
  bool _isLoading = true;

  String get apiEndpoint => _apiEndpoint;
  bool get isLoading => _isLoading;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _isLoading = true;
    notifyListeners();

    _apiEndpoint = await _settingsService.getApiEndpoint();
    
    _isLoading = false;
    notifyListeners();
  }

  Future<void> setApiEndpoint(String endpoint) async {
    await _settingsService.setApiEndpoint(endpoint);
    _apiEndpoint = endpoint;
    notifyListeners();
  }

  Future<void> resetToDefault() async {
    await _settingsService.resetApiEndpoint();
    _apiEndpoint = _settingsService.getDefaultEndpoint();
    notifyListeners();
  }
}

