import 'package:shared_preferences/shared_preferences.dart';

/// App preferences manager for persistent user settings.
/// (Dark mode and theme switching have been completely removed per requirements).
class AppPreferences {
  AppPreferences._();

  static const _customApiBaseUrlKey = 'custom_api_base_url';

  static Future<void> load() async {
    // Preferences initialized during app start
  }

  static Future<String?> getCustomApiBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_customApiBaseUrlKey);
  }

  static Future<void> setCustomApiBaseUrl(String? url) async {
    final prefs = await SharedPreferences.getInstance();
    if (url == null || url.trim().isEmpty) {
      await prefs.remove(_customApiBaseUrlKey);
    } else {
      await prefs.setString(_customApiBaseUrlKey, url.trim());
    }
  }
}

