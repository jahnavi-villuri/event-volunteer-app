import 'package:event_volunteer/services/app_preferences.dart';
import 'package:event_volunteer/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AppPreferences & Light-Theme Tests', () {
    test('AppTheme is strictly Light mode only', () {
      final theme = AppTheme.light;
      expect(theme.brightness, Brightness.light);
      expect(theme.scaffoldBackgroundColor, AppColors.background);
      expect(theme.colorScheme.primary, AppColors.primary);
      expect(theme.appBarTheme.backgroundColor, AppColors.background);
      expect(theme.cardTheme.color, AppColors.surface);
    });

    test('custom api base url persists and loads correctly', () async {
      await AppPreferences.setCustomApiBaseUrl('http://192.168.1.50:3000');
      final savedUrl = await AppPreferences.getCustomApiBaseUrl();
      expect(savedUrl, 'http://192.168.1.50:3000');

      // Reset to default
      await AppPreferences.setCustomApiBaseUrl(null);
      final resetUrl = await AppPreferences.getCustomApiBaseUrl();
      expect(resetUrl, isNull);
    });
  });
}
