import 'package:flutter/foundation.dart';

class AppConfig {
  // Environment variables untuk konfigurasi aplikasi
  static const bool isDevelopment = kDebugMode;

  // Mock mode configuration - bisa diatur via environment variable
  static const bool enableMockMode = bool.fromEnvironment(
    'MOCK_MODE',
    defaultValue:
        isDevelopment, // Default: true di debug mode, false di release
  );

  // Base URL configuration
  static const String defaultBaseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'http://192.168.4.1',
  );

  // Timeout configuration
  static const int defaultTimeoutSeconds = int.fromEnvironment(
    'TIMEOUT_SECONDS',
    defaultValue: 5,
  );

  // Debug logging
  static const bool enableDebugLogs = bool.fromEnvironment(
    'DEBUG_LOGS',
    defaultValue: isDevelopment,
  );

  // Connection retry configuration
  static const int maxRetries = int.fromEnvironment(
    'MAX_RETRIES',
    defaultValue: 5,
  );

  static const int retryIntervalSeconds = int.fromEnvironment(
    'RETRY_INTERVAL',
    defaultValue: 10,
  );

  // Ping interval for connection monitoring
  static const int pingIntervalSeconds = int.fromEnvironment(
    'PING_INTERVAL',
    defaultValue: 15,
  );

  // Mock data delays (untuk simulasi network latency)
  static const int mockDelayMs = int.fromEnvironment(
    'MOCK_DELAY_MS',
    defaultValue: 200,
  );

  // Utility methods
  static void printConfig() {
    if (enableDebugLogs) {
      print('=== App Configuration ===');
      print('Development Mode: $isDevelopment');
      print('Mock Mode: $enableMockMode');
      print('Base URL: $defaultBaseUrl');
      print('Timeout: ${defaultTimeoutSeconds}s');
      print('Max Retries: $maxRetries');
      print('Retry Interval: ${retryIntervalSeconds}s');
      print('Ping Interval: ${pingIntervalSeconds}s');
      print('Mock Delay: ${mockDelayMs}ms');
      print('========================');
    }
  }
}
