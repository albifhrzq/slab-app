import 'dart:convert';
import 'dart:async';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class AquariumApiService {
  String baseUrl;
  final http.Client client = http.Client();

  // Gunakan AppConfig untuk konfigurasi
  static int get defaultTimeoutSeconds => AppConfig.defaultTimeoutSeconds;
  static bool get _mockMode => AppConfig.enableMockMode;

  // Mock mode untuk testing tanpa hardware
  static Map<String, dynamic> _mockCurrentProfile = {
    'royalBlue': 128,
    'blue': 100,
    'uv': 50,
    'violet': 75,
    'red': 25,
    'green': 40,
    'white': 200,
  };

  // Mock hourly schedule (24 hours, 0-23)
  static List<Map<String, dynamic>> _mockHourlySchedule = List.generate(24, (
    hour,
  ) {
    // Create different intensities based on time of day
    if (hour >= 0 && hour < 6) {
      // Night (00:00-05:59) - dim blue
      return {
        'hour': hour,
        'royalBlue': 20,
        'blue': 30,
        'uv': 0,
        'violet': 10,
        'red': 0,
        'green': 0,
        'white': 20,
      };
    } else if (hour >= 6 && hour < 12) {
      // Morning (06:00-11:59) - gradually increasing
      final factor = (hour - 6) / 6.0;
      return {
        'hour': hour,
        'royalBlue': (50 + 150 * factor).round(),
        'blue': (80 + 120 * factor).round(),
        'uv': (20 + 80 * factor).round(),
        'violet': (30 + 70 * factor).round(),
        'red': (10 + 90 * factor).round(),
        'green': (15 + 85 * factor).round(),
        'white': (100 + 155 * factor).round(),
      };
    } else if (hour >= 12 && hour < 18) {
      // Midday (12:00-17:59) - full intensity
      return {
        'hour': hour,
        'royalBlue': 200,
        'blue': 180,
        'uv': 100,
        'violet': 120,
        'red': 80,
        'green': 100,
        'white': 255,
      };
    } else {
      // Evening (18:00-23:59) - gradually decreasing
      final factor = 1.0 - ((hour - 18) / 6.0);
      return {
        'hour': hour,
        'royalBlue': (20 + 130 * factor).round(),
        'blue': (30 + 90 * factor).round(),
        'uv': (0 + 60 * factor).round(),
        'violet': (10 + 70 * factor).round(),
        'red': (0 + 40 * factor).round(),
        'green': (0 + 50 * factor).round(),
        'white': (20 + 160 * factor).round(),
      };
    }
  });

  AquariumApiService({required this.baseUrl});

  // Get current profile
  Future<Map<String, dynamic>> getCurrentProfile() async {
    if (_mockMode) {
      developer.log('Mock: Getting current profile', name: 'mock');
      await Future.delayed(
        const Duration(milliseconds: AppConfig.mockDelayMs),
      ); // Simulate network delay
      return _mockCurrentProfile;
    }

    final response = await client.get(Uri.parse('$baseUrl/api/profile'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load current profile');
    }
  }

  // ========== HOURLY SCHEDULE API METHODS ==========

  // Helper: Get hour ranges for each time period
  static List<int> getHoursForPeriod(String period) {
    switch (period) {
      case 'morning':
        return [6, 7, 8, 9, 10, 11];
      case 'midday':
        return [12, 13, 14, 15, 16, 17];
      case 'evening':
        return [18, 19, 20, 21, 22, 23];
      case 'night':
        return [0, 1, 2, 3, 4, 5];
      default:
        return [];
    }
  }

  // Helper: Get hours for all periods
  static Map<String, List<int>> getAllPeriodHours() {
    return {
      'morning': getHoursForPeriod('morning'),
      'midday': getHoursForPeriod('midday'),
      'evening': getHoursForPeriod('evening'),
      'night': getHoursForPeriod('night'),
    };
  }

  // Get complete 24-hour schedule
  Future<List<Map<String, dynamic>>> getHourlySchedule() async {
    if (_mockMode) {
      developer.log('Mock: Getting hourly schedule (24 hours)', name: 'mock');
      await Future.delayed(const Duration(milliseconds: AppConfig.mockDelayMs));
      return List<Map<String, dynamic>>.from(_mockHourlySchedule);
    }

    try {
      developer.log(
        'Getting hourly schedule: $baseUrl/api/schedule/hourly',
        name: 'network',
      );

      const timeoutDuration = Duration(
        seconds: AppConfig.profileTimeoutSeconds,
      );

      final response = await client
          .get(Uri.parse('$baseUrl/api/schedule/hourly'))
          .timeout(timeoutDuration);

      developer.log(
        'Hourly schedule response: ${response.statusCode}',
        name: 'network',
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['schedule'] != null) {
          return List<Map<String, dynamic>>.from(
            data['schedule'].map((item) => Map<String, dynamic>.from(item)),
          );
        }
        throw Exception('Invalid response format: missing schedule array');
      } else {
        developer.log('HTTP Error: ${response.statusCode}', name: 'network');
        throw Exception(
          'Failed to load hourly schedule (${response.statusCode})',
        );
      }
    } catch (e) {
      developer.log(
        'Get hourly schedule error: ${e.toString()}',
        name: 'network',
      );
      if (e is TimeoutException) {
        throw TimeoutException('Hourly schedule request timed out');
      }
      throw Exception('Failed to load hourly schedule: ${e.toString()}');
    }
  }

  // Set complete 24-hour schedule
  Future<bool> setHourlySchedule(List<Map<String, dynamic>> schedule) async {
    if (_mockMode) {
      developer.log('Mock: Setting hourly schedule (24 hours)', name: 'mock');
      await Future.delayed(
        const Duration(milliseconds: AppConfig.mockDelayMs ~/ 2),
      );
      _mockHourlySchedule = List<Map<String, dynamic>>.from(schedule);
      return true;
    }

    try {
      // Ensure all hour entries are properly formatted
      final formattedSchedule =
          schedule.map((hour) {
            return {
              'hour': hour['hour'] ?? 0,
              'royalBlue': hour['royalBlue'] ?? 0,
              'blue': hour['blue'] ?? 0,
              'uv': hour['uv'] ?? 0,
              'violet': hour['violet'] ?? 0,
              'red': hour['red'] ?? 0,
              'green': hour['green'] ?? 0,
              'white': hour['white'] ?? 0,
            };
          }).toList();

      final data = {'schedule': formattedSchedule};
      final jsonBody = json.encode(data);

      developer.log(
        'Setting hourly schedule: $baseUrl/api/schedule/hourly',
        name: 'network',
      );

      developer.log(
        'Schedule size: ${schedule.length} hours, payload: ${jsonBody.length} bytes',
        name: 'network',
      );

      final response = await client
          .post(
            Uri.parse('$baseUrl/api/schedule/hourly'),
            headers: {'Content-Type': 'application/json'},
            body: jsonBody,
          )
          .timeout(
            const Duration(seconds: AppConfig.saveScheduleTimeoutSeconds),
            onTimeout: () {
              developer.log(
                'Set hourly schedule request timed out after ${AppConfig.saveScheduleTimeoutSeconds}s',
                name: 'network',
              );
              throw TimeoutException(
                'Device tidak merespons dalam ${AppConfig.saveScheduleTimeoutSeconds} detik',
              );
            },
          );

      developer.log(
        'Set hourly schedule response: ${response.statusCode}',
        name: 'network',
      );

      if (response.statusCode != 200) {
        developer.log(
          'Set hourly schedule failed with status ${response.statusCode}: ${response.body}',
          name: 'network',
        );
        throw Exception('Device menolak data (HTTP ${response.statusCode})');
      }

      return true;
    } on TimeoutException catch (e) {
      developer.log(
        'Set hourly schedule timeout: ${e.message}',
        name: 'network',
      );
      rethrow;
    } catch (e) {
      developer.log(
        'Set hourly schedule error: ${e.toString()}',
        name: 'network',
      );
      rethrow;
    }
  }

  // Get profile for a specific hour (0-23)
  Future<Map<String, dynamic>> getHourProfile(int hour) async {
    if (hour < 0 || hour > 23) {
      throw ArgumentError('Hour must be between 0 and 23');
    }

    if (_mockMode) {
      developer.log('Mock: Getting profile for hour $hour', name: 'mock');
      await Future.delayed(
        const Duration(milliseconds: AppConfig.mockDelayMs ~/ 2),
      );
      return _mockHourlySchedule[hour];
    }

    try {
      developer.log(
        'Getting hour profile: $baseUrl/api/schedule/hourly/$hour',
        name: 'network',
      );

      const timeoutDuration = Duration(
        seconds: AppConfig.profileTimeoutSeconds,
      );

      final response = await client
          .get(Uri.parse('$baseUrl/api/schedule/hourly/$hour'))
          .timeout(timeoutDuration);

      developer.log(
        'Hour profile response: ${response.statusCode}',
        name: 'network',
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        developer.log('HTTP Error: ${response.statusCode}', name: 'network');
        throw Exception('Failed to load hour profile (${response.statusCode})');
      }
    } catch (e) {
      developer.log('Get hour profile error: ${e.toString()}', name: 'network');
      if (e is TimeoutException) {
        throw TimeoutException('Hour profile request timed out');
      }
      throw Exception('Failed to load hour profile: ${e.toString()}');
    }
  }

  // Update profile for a specific hour
  Future<bool> setHourProfile(int hour, Map<String, dynamic> profile) async {
    if (hour < 0 || hour > 23) {
      throw ArgumentError('Hour must be between 0 and 23');
    }

    if (_mockMode) {
      developer.log(
        'Mock: Setting profile for hour $hour: $profile',
        name: 'mock',
      );
      await Future.delayed(
        const Duration(milliseconds: AppConfig.mockDelayMs ~/ 2),
      );
      _mockHourlySchedule[hour] = Map<String, dynamic>.from(profile)
        ..['hour'] = hour;
      return true;
    }

    try {
      // Format the profile data (remove 'hour' key if present, backend adds it)
      final profileData = {
        'royalBlue': profile['royalBlue'] ?? 0,
        'blue': profile['blue'] ?? 0,
        'uv': profile['uv'] ?? 0,
        'violet': profile['violet'] ?? 0,
        'red': profile['red'] ?? 0,
        'green': profile['green'] ?? 0,
        'white': profile['white'] ?? 0,
      };

      developer.log(
        'Setting hour $hour profile: $baseUrl/api/schedule/hourly/$hour',
        name: 'network',
      );

      final response = await client
          .post(
            Uri.parse('$baseUrl/api/schedule/hourly/$hour'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(profileData),
          )
          .timeout(
            const Duration(seconds: AppConfig.profileTimeoutSeconds),
            onTimeout: () {
              developer.log(
                'Set hour profile request timed out',
                name: 'network',
              );
              throw TimeoutException('Request timed out');
            },
          );

      developer.log(
        'Set hour profile response: ${response.statusCode}',
        name: 'network',
      );

      if (response.statusCode != 200) {
        developer.log(
          'Set hour profile failed: ${response.body}',
          name: 'network',
        );
      }

      return response.statusCode == 200;
    } on TimeoutException {
      developer.log('Set hour profile timeout', name: 'network');
      rethrow;
    } catch (e) {
      developer.log('Set hour profile error: ${e.toString()}', name: 'network');
      rethrow;
    }
  }

  // ========== PERIOD-BASED METHODS (UI Helper - Uses Hourly API) ==========

  // Get all profiles for a specific period (e.g., 'morning', 'midday', etc.)
  // Returns a list of hourly profiles within that period
  Future<List<Map<String, dynamic>>> getPeriodProfiles(String period) async {
    final hours = getHoursForPeriod(period);
    if (hours.isEmpty) {
      throw ArgumentError('Invalid period: $period');
    }

    final schedule = await getHourlySchedule();
    return hours.map((hour) => schedule[hour]).toList();
  }

  // Get representative profile for a period (average or middle hour)
  Future<Map<String, dynamic>> getPeriodRepresentative(String period) async {
    final profiles = await getPeriodProfiles(period);
    if (profiles.isEmpty) {
      throw Exception('No profiles found for period: $period');
    }

    // Return the middle profile as representative
    final middleIndex = profiles.length ~/ 2;
    return profiles[middleIndex];
  }

  // Set all hours in a period to the same profile
  Future<bool> setPeriodProfile(
    String period,
    Map<String, dynamic> profile,
  ) async {
    final hours = getHoursForPeriod(period);
    if (hours.isEmpty) {
      throw ArgumentError('Invalid period: $period');
    }

    developer.log(
      'Setting profile for period $period (${hours.length} hours)',
      name: 'network',
    );

    try {
      final currentSchedule = await getHourlySchedule();

      // Update all hours in this period
      for (final hour in hours) {
        currentSchedule[hour] = Map<String, dynamic>.from(profile)
          ..['hour'] = hour;
      }

      return await setHourlySchedule(currentSchedule);
    } catch (e) {
      developer.log(
        'Set period profile error: ${e.toString()}',
        name: 'network',
      );
      return false;
    }
  }

  // Get all periods with their profiles (for batch loading)
  Future<Map<String, List<Map<String, dynamic>>>> getAllPeriodProfiles() async {
    final schedule = await getHourlySchedule();
    final periods = getAllPeriodHours();

    final result = <String, List<Map<String, dynamic>>>{};
    for (final entry in periods.entries) {
      final periodName = entry.key;
      final hours = entry.value;
      result[periodName] = hours.map((hour) => schedule[hour]).toList();
    }

    return result;
  }

  // Manual LED control
  Future<bool> controlLed(String led, int value) async {
    if (_mockMode) {
      developer.log('Mock: Controlling LED $led to value $value', name: 'mock');
      await Future.delayed(const Duration(milliseconds: 50));
      // Update mock current profile
      _mockCurrentProfile[led] = value;
      return true;
    }

    final data = {'led': led, 'value': value};

    final response = await client.post(
      Uri.parse('$baseUrl/api/manual'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(data),
    );

    return response.statusCode == 200;
  }

  // Get current time
  Future<Map<String, dynamic>> getCurrentTime() async {
    if (_mockMode) {
      developer.log('Mock: Getting current time', name: 'mock');
      await Future.delayed(const Duration(milliseconds: 100));
      final now = DateTime.now();
      return {
        'hour': now.hour,
        'minute': now.minute,
        'second': now.second,
        'day': now.day,
        'month': now.month,
        'year': now.year,
      };
    }

    try {
      developer.log('Getting time: $baseUrl/api/time', name: 'network');
      final response = await client
          .get(Uri.parse('$baseUrl/api/time'))
          .timeout(Duration(seconds: defaultTimeoutSeconds));

      developer.log(
        'Time response: ${response.statusCode} - ${response.body}',
        name: 'network',
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        developer.log('HTTP Error: ${response.statusCode}', name: 'network');
        throw Exception('Failed to load current time: ${response.statusCode}');
      }
    } catch (e) {
      developer.log('Get time error: ${e.toString()}', name: 'network');
      if (e is TimeoutException) {
        throw TimeoutException('Time request timed out');
      }
      throw Exception('Failed to load current time: ${e.toString()}');
    }
  }

  // Get operation mode
  Future<String> getMode() async {
    if (_mockMode) {
      developer.log('Mock: Getting operation mode', name: 'mock');
      await Future.delayed(const Duration(milliseconds: 100));
      return 'automatic'; // Default to automatic mode
    }

    final response = await client.get(Uri.parse('$baseUrl/api/mode'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['mode'];
    } else {
      throw Exception('Failed to load mode');
    }
  }

  // Set operation mode
  Future<bool> setMode(String mode) async {
    if (_mockMode) {
      developer.log('Mock: Setting operation mode to $mode', name: 'mock');
      await Future.delayed(const Duration(milliseconds: 100));
      return true;
    }

    final data = {'mode': mode};

    final response = await client.post(
      Uri.parse('$baseUrl/api/mode'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(data),
    );

    return response.statusCode == 200;
  }

  // Ping endpoint to keep connection alive
  Future<Map<String, dynamic>> ping() async {
    if (_mockMode) {
      developer.log('Mock: Pinging controller', name: 'mock');
      await Future.delayed(const Duration(milliseconds: 50));
      return {
        'status': 'ok',
        'latency': '2ms',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
    }

    try {
      developer.log('Pinging: $baseUrl/api/ping', name: 'network');
      final response = await client
          .get(Uri.parse('$baseUrl/api/ping'))
          .timeout(Duration(seconds: defaultTimeoutSeconds));

      developer.log(
        'Ping response: ${response.statusCode} - ${response.body}',
        name: 'network',
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        developer.log('HTTP Error: ${response.statusCode}', name: 'network');
        throw Exception('Failed to ping controller: ${response.statusCode}');
      }
    } catch (e) {
      developer.log('Ping error: ${e.toString()}', name: 'network');
      if (e is TimeoutException) {
        throw TimeoutException('Ping request timed out');
      }
      throw Exception('Failed to ping controller: ${e.toString()}');
    }
  }

  // Set time on the RTC controller
  Future<bool> setTime(DateTime time) async {
    if (_mockMode) {
      developer.log('Mock: Setting time to $time', name: 'mock');
      await Future.delayed(const Duration(milliseconds: 100));
      return true;
    }

    try {
      // Format data waktu sesuai dengan format yang diharapkan oleh controller
      final data = {
        'year': time.year,
        'month': time.month,
        'day': time.day,
        'hour': time.hour,
        'minute': time.minute,
        'second': time.second,
      };

      final response = await client
          .post(
            Uri.parse('$baseUrl/api/time'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(data),
          )
          .timeout(Duration(seconds: defaultTimeoutSeconds));

      return response.statusCode == 200;
    } catch (e) {
      if (e is TimeoutException) {
        throw TimeoutException('Set time request timed out');
      }
      throw Exception('Failed to set time: ${e.toString()}');
    }
  }

  // Set manual mode on/off
  Future<bool> setManualMode(bool enabled) async {
    try {
      developer.log('Setting manual mode: $enabled', name: 'network');

      // Menggunakan endpoint mode yang sudah ada
      final mode = enabled ? 'manual' : 'auto';
      return await setMode(mode);
    } catch (e) {
      developer.log('Set manual mode error: ${e.toString()}', name: 'network');
      throw Exception('Failed to set manual mode: ${e.toString()}');
    }
  }

  // Set LED values langsung dalam mode manual
  Future<bool> setManualLedValues(Map<String, dynamic> values) async {
    try {
      // Memastikan format data yang dikirim persis sama dengan yang diharapkan hardware
      Map<String, dynamic> ledValues = {
        "royalBlue": values["royalBlue"] ?? 0,
        "blue": values["blue"] ?? 0,
        "uv": values["uv"] ?? 0,
        "violet": values["violet"] ?? 0,
        "red": values["red"] ?? 0,
        "green": values["green"] ?? 0,
        "white": values["white"] ?? 0,
      };

      // Memastikan semua nilai adalah integer
      ledValues.forEach((key, value) {
        if (value is double) {
          ledValues[key] = value.round();
        }
      });

      // Coba dengan format wrapper terlebih dahulu
      bool success = await _trySetManualLedValues({"leds": ledValues});

      // Jika gagal dengan format wrapper, coba tanpa wrapper
      if (!success) {
        developer.log('Trying without wrapper', name: 'network');
        success = await _trySetManualLedValues(ledValues);

        // Jika masih gagal, coba format setiap LED individual
        if (!success) {
          developer.log('Trying individual LED calls', name: 'network');
          success = true;
          for (var entry in ledValues.entries) {
            final singleLedSuccess = await controlLed(entry.key, entry.value);
            if (!singleLedSuccess) {
              success = false;
            }
          }
        }
      }

      return success;
    } catch (e) {
      developer.log(
        'Set manual LED values error: ${e.toString()}',
        name: 'network',
      );
      throw Exception('Failed to set manual LED values: ${e.toString()}');
    }
  }

  // Helper method untuk mencoba format data tertentu
  Future<bool> _trySetManualLedValues(
    Map<String, dynamic> formattedValues,
  ) async {
    try {
      // Log data request dengan format yang lebih detail
      final jsonBody = json.encode(formattedValues);
      developer.log('Trying JSON body: $jsonBody', name: 'network');
      developer.log(
        'URL: ${Uri.parse('$baseUrl/api/manual/all')}',
        name: 'network',
      );

      final response = await client
          .post(
            Uri.parse('$baseUrl/api/manual/all'),
            headers: {'Content-Type': 'application/json'},
            body: jsonBody,
          )
          .timeout(Duration(seconds: defaultTimeoutSeconds));

      developer.log(
        'Manual LED response: ${response.statusCode}',
        name: 'network',
      );
      developer.log('Response body: ${response.body}', name: 'network');

      return response.statusCode == 200;
    } catch (e) {
      developer.log('Try format error: ${e.toString()}', name: 'network');
      return false;
    }
  }

  // Mock mode utilities
  static bool get isMockMode => _mockMode;

  static void toggleMockMode() {
    // Note: Karena _mockMode adalah const, implementasi ini akan memerlukan
    // perubahan dari const bool ke static bool untuk bisa diubah
    developer.log('Mock mode is currently: $_mockMode', name: 'mock');
    developer.log(
      'To change mock mode, edit _mockMode value in source code',
      name: 'mock',
    );
  }

  // Method untuk reset mock data ke default
  static void resetMockData() {
    _mockCurrentProfile = {
      'royalBlue': 128,
      'blue': 100,
      'uv': 50,
      'violet': 75,
      'red': 25,
      'green': 40,
      'white': 200,
    };

    // Reset hourly schedule to defaults
    _mockHourlySchedule = List.generate(24, (hour) {
      if (hour >= 0 && hour < 6) {
        return {
          'hour': hour,
          'royalBlue': 20,
          'blue': 30,
          'uv': 0,
          'violet': 10,
          'red': 0,
          'green': 0,
          'white': 20,
        };
      } else if (hour >= 6 && hour < 12) {
        final factor = (hour - 6) / 6.0;
        return {
          'hour': hour,
          'royalBlue': (50 + 150 * factor).round(),
          'blue': (80 + 120 * factor).round(),
          'uv': (20 + 80 * factor).round(),
          'violet': (30 + 70 * factor).round(),
          'red': (10 + 90 * factor).round(),
          'green': (15 + 85 * factor).round(),
          'white': (100 + 155 * factor).round(),
        };
      } else if (hour >= 12 && hour < 18) {
        return {
          'hour': hour,
          'royalBlue': 200,
          'blue': 180,
          'uv': 100,
          'violet': 120,
          'red': 80,
          'green': 100,
          'white': 255,
        };
      } else {
        final factor = 1.0 - ((hour - 18) / 6.0);
        return {
          'hour': hour,
          'royalBlue': (20 + 130 * factor).round(),
          'blue': (30 + 90 * factor).round(),
          'uv': (0 + 60 * factor).round(),
          'violet': (10 + 70 * factor).round(),
          'red': (0 + 40 * factor).round(),
          'green': (0 + 50 * factor).round(),
          'white': (20 + 160 * factor).round(),
        };
      }
    });

    developer.log(
      'Mock data reset to defaults (hourly schedule)',
      name: 'mock',
    );
  }
}
