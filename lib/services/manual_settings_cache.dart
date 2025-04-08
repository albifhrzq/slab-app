import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/profile.dart';

class ManualSettingsCache {
  static const String _manualProfileKey = 'manual_profile';

  // Save manual LED settings to local storage
  static Future<void> saveManualProfile(Profile profile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final profileJson = json.encode(profile.toJson());
      await prefs.setString(_manualProfileKey, profileJson);
    } catch (e) {
      print('Error saving manual profile: $e');
    }
  }

  // Get manual LED settings from local storage
  static Future<Profile?> getManualProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final profileJson = prefs.getString(_manualProfileKey);

      if (profileJson != null) {
        final profileData = json.decode(profileJson);
        return Profile.fromJson(profileData);
      }
      return null;
    } catch (e) {
      print('Error loading manual profile: $e');
      return null;
    }
  }
}
