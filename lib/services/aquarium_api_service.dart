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

  static Map<String, Map<String, dynamic>> _mockProfiles = {
    'morning': {
      'royalBlue': 50,
      'blue': 80,
      'uv': 20,
      'violet': 30,
      'red': 10,
      'green': 15,
      'white': 100,
    },
    'midday': {
      'royalBlue': 200,
      'blue': 180,
      'uv': 100,
      'violet': 120,
      'red': 80,
      'green': 100,
      'white': 255,
    },
    'evening': {
      'royalBlue': 150,
      'blue': 120,
      'uv': 60,
      'violet': 80,
      'red': 40,
      'green': 50,
      'white': 180,
    },
    'night': {
      'royalBlue': 20,
      'blue': 30,
      'uv': 0,
      'violet': 10,
      'red': 0,
      'green': 0,
      'white': 20,
    },
  };

  static Map<String, dynamic> _mockTimeRanges = {
    'morning': {'start': '06:00', 'end': '10:00'},
    'midday': {'start': '10:00', 'end': '16:00'},
    'evening': {'start': '16:00', 'end': '22:00'},
    'night': {'start': '22:00', 'end': '06:00'},
  };

  AquariumApiService({required this.baseUrl});

  // Get current profile
  Future<Map<String, dynamic>> getCurrentProfile() async {
    if (_mockMode) {
      developer.log('Mock: Getting current profile', name: 'mock');
      await Future.delayed(
        Duration(milliseconds: AppConfig.mockDelayMs),
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

  // Get profile by type
  Future<Map<String, dynamic>> getProfile(String type) async {
    if (_mockMode) {
      developer.log('Mock: Getting profile type: $type', name: 'mock');
      await Future.delayed(Duration(milliseconds: AppConfig.mockDelayMs ~/ 2));
      return _mockProfiles[type] ?? _mockProfiles['morning']!;
    }

    final response = await client.get(
      Uri.parse('$baseUrl/api/profile?type=$type'),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load profile type: $type');
    }
  }

  // Set profile
  Future<bool> setProfile(String type, Map<String, dynamic> profile) async {
    if (_mockMode) {
      developer.log('Mock: Setting profile $type: $profile', name: 'mock');
      await Future.delayed(Duration(milliseconds: AppConfig.mockDelayMs ~/ 2));
      _mockProfiles[type] = Map<String, dynamic>.from(profile);
      _mockCurrentProfile = Map<String, dynamic>.from(profile);
      return true;
    }

    final data = {'type': type, 'profile': profile};

    final response = await client.post(
      Uri.parse('$baseUrl/api/profile'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(data),
    );

    return response.statusCode == 200;
  }

  // Get time ranges
  Future<Map<String, dynamic>> getTimeRanges() async {
    if (_mockMode) {
      developer.log('Mock: Getting time ranges', name: 'mock');
      await Future.delayed(Duration(milliseconds: AppConfig.mockDelayMs ~/ 2));
      return _mockTimeRanges;
    }

    final response = await client.get(Uri.parse('$baseUrl/api/timeranges'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load time ranges');
    }
  }

  // Set time ranges
  Future<bool> setTimeRanges(Map<String, dynamic> timeRanges) async {
    if (_mockMode) {
      developer.log('Mock: Setting time ranges: $timeRanges', name: 'mock');
      await Future.delayed(const Duration(milliseconds: 100));
      _mockTimeRanges.addAll(timeRanges);
      return true;
    }

    final response = await client.post(
      Uri.parse('$baseUrl/api/timeranges'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(timeRanges),
    );

    return response.statusCode == 200;
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

    _mockProfiles = {
      'morning': {
        'royalBlue': 50,
        'blue': 80,
        'uv': 20,
        'violet': 30,
        'red': 10,
        'green': 15,
        'white': 100,
      },
      'midday': {
        'royalBlue': 200,
        'blue': 180,
        'uv': 100,
        'violet': 120,
        'red': 80,
        'green': 100,
        'white': 255,
      },
      'evening': {
        'royalBlue': 150,
        'blue': 120,
        'uv': 60,
        'violet': 80,
        'red': 40,
        'green': 50,
        'white': 180,
      },
      'night': {
        'royalBlue': 20,
        'blue': 30,
        'uv': 0,
        'violet': 10,
        'red': 0,
        'green': 0,
        'white': 20,
      },
    };

    _mockTimeRanges = {
      'morning': {'start': '06:00', 'end': '10:00'},
      'midday': {'start': '10:00', 'end': '16:00'},
      'evening': {'start': '16:00', 'end': '22:00'},
      'night': {'start': '22:00', 'end': '06:00'},
    };

    developer.log('Mock data reset to defaults', name: 'mock');
  }
}
