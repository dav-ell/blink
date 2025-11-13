import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _apiEndpointKey = 'api_endpoint';
  static const String _defaultEndpoint = 'http://localhost:8000';

  Future<String> getApiEndpoint() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_apiEndpointKey) ?? _defaultEndpoint;
  }

  Future<void> setApiEndpoint(String endpoint) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiEndpointKey, endpoint);
  }

  Future<void> resetApiEndpoint() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_apiEndpointKey);
  }

  String getDefaultEndpoint() {
    return _defaultEndpoint;
  }
}

