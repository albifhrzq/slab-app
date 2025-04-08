import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/profile.dart';
import '../models/time_ranges.dart';

class ProfileCache {
  static Future<void> saveProfile(String type, Profile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile_$type', json.encode(profile.toJson()));
  }

  static Future<Profile?> getProfile(String type) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('profile_$type');
    if (data != null) {
      return Profile.fromJson(json.decode(data));
    }
    return null;
  }

  static Future<void> saveTimeRanges(TimeRanges timeRanges) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('time_ranges', json.encode(timeRanges.toJson()));
  }

  static Future<TimeRanges?> getTimeRanges() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('time_ranges');
    if (data != null) {
      return TimeRanges.fromJson(json.decode(data));
    }
    return null;
  }

  static Future<void> saveDeviceIp(String ip) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('device_ip', ip);
  }

  static Future<String?> getDeviceIp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('device_ip');
  }
}
