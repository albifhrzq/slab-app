import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/profile.dart';

class ProfileCache {
  // ========== HOURLY SCHEDULE CACHING ==========

  // Save complete 24-hour schedule
  static Future<void> saveHourlySchedule(
    List<Map<String, dynamic>> schedule,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('hourly_schedule', json.encode(schedule));
  }

  // Get complete 24-hour schedule
  static Future<List<Map<String, dynamic>>?> getHourlySchedule() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('hourly_schedule');
    if (data != null) {
      final decoded = json.decode(data) as List;
      return decoded.map((item) => item as Map<String, dynamic>).toList();
    }
    return null;
  }

  // Save profile for a specific hour
  static Future<void> saveHourProfile(
    int hour,
    Map<String, dynamic> profile,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('hour_$hour', json.encode(profile));
  }

  // Get profile for a specific hour
  static Future<Map<String, dynamic>?> getHourProfile(int hour) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('hour_$hour');
    if (data != null) {
      return json.decode(data) as Map<String, dynamic>;
    }
    return null;
  }

  // ========== PERIOD-BASED CACHING (UI Helper) ==========

  // Save representative profile for a period (for quick UI loading)
  static Future<void> savePeriodProfile(String period, Profile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('period_$period', json.encode(profile.toJson()));
  }

  // Get representative profile for a period
  static Future<Profile?> getPeriodProfile(String period) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('period_$period');
    if (data != null) {
      return Profile.fromJson(json.decode(data));
    }
    return null;
  }

  // ========== LEGACY SUPPORT (for backward compatibility) ==========

  // Save profile (legacy method - now saves to period cache)
  static Future<void> saveProfile(String type, Profile profile) async {
    await savePeriodProfile(type, profile);
  }

  // Get profile (legacy method - now reads from period cache)
  static Future<Profile?> getProfile(String type) async {
    return getPeriodProfile(type);
  }

  // ========== DEVICE INFO CACHING ==========

  static Future<void> saveDeviceIp(String ip) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('device_ip', ip);
  }

  static Future<String?> getDeviceIp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('device_ip');
  }

  // Clear all cached data (useful for debugging)
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
