import 'dart:async';
import 'package:flutter/material.dart';
import 'aquarium_api_service.dart';

class ConnectionManager extends ChangeNotifier {
  bool _isConnected = false;
  String _ipAddress = '';
  Timer? _connectionCheckTimer;
  Timer? _retryTimer;
  Timer? _pingTimer;
  final AquariumApiService _apiService;
  int _retryCount = 0;
  static const int maxRetries = 3; // Kurangi dari 5 ke 3
  static const int retryIntervalSeconds = 10;
  static const int pingIntervalSeconds = 30; // Lebih jarang: 30 detik
  static const int gracePeriodSeconds =
      5; // Grace period lebih singkat: 5 detik
  static const int connectionTimeoutSeconds = 3; // Timeout untuk koneksi API
  static const int initialConnectMaxRetries = 3; // Khusus untuk initial connect

  // Status koneksi
  String _connectionStatus = 'Disconnected';
  DateTime? _lastSuccessfulConnection;
  bool _isInitialConnection = true; // Flag untuk initial connection

  // Statistik koneksi
  int _totalPingAttempts = 0;
  int _successfulPings = 0;
  int _connectionDrops = 0;
  int _consecutiveFailures = 0;
  DateTime? _firstPingAttempt;

  ConnectionManager(this._apiService) {
    // Jangan langsung mulai ping timer saat inisialisasi
    // Biarkan user memulai koneksi manual
    _firstPingAttempt = DateTime.now();
  }

  // Method khusus untuk initial connection dengan retry terbatas
  Future<bool> initialConnect() async {
    _isInitialConnection = true;
    _retryCount = 0;
    _connectionStatus = 'Connecting...';
    notifyListeners();

    for (int attempt = 1; attempt <= initialConnectMaxRetries; attempt++) {
      try {
        _connectionStatus =
            'Connecting... (Attempt $attempt/$initialConnectMaxRetries)';
        notifyListeners();

        // Coba ping controller
        await _apiService.ping().timeout(
          const Duration(seconds: connectionTimeoutSeconds),
          onTimeout: () => throw TimeoutException('Connection timed out'),
        );

        // Berhasil connect
        _isConnected = true;
        _lastSuccessfulConnection = DateTime.now();
        _connectionStatus = 'Connected';
        _retryCount = 0;
        _isInitialConnection = false;

        // Mulai ping timer setelah berhasil connect
        _startPingTimer();

        notifyListeners();
        return true;
      } catch (e) {
        String errorMessage = 'Connection failed';
        if (e is TimeoutException) {
          errorMessage = 'Connection timeout';
        }

        _connectionStatus =
            '$errorMessage (Attempt $attempt/$initialConnectMaxRetries)';
        notifyListeners();

        // Tunggu sebentar sebelum retry kecuali ini attempt terakhir
        if (attempt < initialConnectMaxRetries) {
          await Future.delayed(const Duration(seconds: 2));
        }
      }
    }

    // Semua attempt gagal
    _isConnected = false;
    _connectionStatus =
        'Failed to connect after $initialConnectMaxRetries attempts';
    _isInitialConnection = false;
    notifyListeners();
    return false;
  }

  bool get isConnected => _isConnected;
  String get ipAddress => _ipAddress;
  int get retryCount => _retryCount;
  bool get isRetrying => _retryTimer != null;
  String get connectionStatus => _connectionStatus;
  DateTime? get lastSuccessfulConnection => _lastSuccessfulConnection;

  // Getter untuk statistik koneksi
  int get totalPingAttempts => _totalPingAttempts;
  int get successfulPings => _successfulPings;
  int get connectionDrops => _connectionDrops;
  int get pingSuccessRate =>
      _totalPingAttempts > 0
          ? (_successfulPings * 100 ~/ _totalPingAttempts)
          : 0;
  String get connectionUptime => _calculateUptime();

  String _calculateUptime() {
    if (_firstPingAttempt == null) return '0 minutes';

    final now = DateTime.now();
    final difference = now.difference(_firstPingAttempt!);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes';
    } else {
      return '${difference.inHours} hours ${difference.inMinutes % 60} minutes';
    }
  }

  void setIpAddress(String ip) {
    _ipAddress = ip;
    _apiService.baseUrl = 'http://$ip';
    _retryCount = 0; // Reset retry count
    _connectionStatus = 'Connecting...';
    notifyListeners();

    // Restart ping timer saat IP berubah
    _cancelPingTimer();
    _startPingTimer();

    // Lakukan ping langsung
    _pingController();
  }

  void _startPingTimer() {
    _cancelPingTimer(); // Batalkan timer yang ada

    // Buat timer baru untuk ping berkala
    _pingTimer = Timer.periodic(const Duration(seconds: pingIntervalSeconds), (
      _,
    ) {
      _pingController();
    });
  }

  void _cancelPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = null;
  }

  Future<void> _pingController() async {
    _totalPingAttempts++;

    try {
      // Gunakan endpoint ping khusus dengan timeout
      final result = await _apiService.ping().timeout(
        const Duration(seconds: connectionTimeoutSeconds),
        onTimeout: () => throw TimeoutException('Connection timed out'),
      );

      // Jika berhasil, tandai sebagai terhubung
      _successfulPings++;
      _consecutiveFailures = 0;

      final bool wasConnected = _isConnected; // Simpan status sebelumnya
      _isConnected = true;
      _lastSuccessfulConnection = DateTime.now();
      _connectionStatus = 'Connected (Ping: ${result['latency'] ?? 'OK'})';
      _retryCount = 0; // Reset retry count
      _cancelRetryTimer(); // Cancel any retry timer

      // Jika sebelumnya tidak terkoneksi, ini adalah reconnect yang berhasil
      if (!wasConnected) {
        _connectionStatus = 'Reconnected, connection restored';
      }
    } catch (e) {
      // Jika sebelumnya terhubung, ini adalah connection drop
      if (_isConnected) {
        _connectionDrops++;
      }

      _consecutiveFailures++;

      // Jika ping gagal, tandai sebagai terputus
      String errorMessage = 'Ping failed';
      if (e is TimeoutException) {
        errorMessage = 'Connection timeout';
      }
      _handleConnectionFailure(
        '$errorMessage (failures: $_consecutiveFailures)',
      );
    }
    notifyListeners();
  }

  Future<void> checkConnection() async {
    try {
      // Coba dapatkan waktu sebagai tes koneksi sederhana
      await _apiService.getCurrentTime();
      _isConnected = true;
      _lastSuccessfulConnection = DateTime.now();
      _connectionStatus = 'Connected';
      _retryCount = 0; // Reset retry count on successful connection
      _cancelRetryTimer(); // Cancel any retry timer
    } catch (e) {
      _handleConnectionFailure('Connection check failed');
    }
    notifyListeners();
  }

  void _handleConnectionFailure(String reason) {
    _isConnected = false;
    _connectionStatus = 'Disconnected: $reason';

    // Jika sedang dalam initial connection, jangan auto-retry
    if (_isInitialConnection) {
      notifyListeners();
      return;
    }

    // Jika baru saja terkoneksi (dalam 30 detik terakhir) sebelum terputus,
    // langsung coba lagi tanpa menunggu grace period
    final lastConnected = _lastSuccessfulConnection;
    final now = DateTime.now();

    if (lastConnected != null && now.difference(lastConnected).inSeconds < 30) {
      // Koneksi baru saja terputus setelah terhubung
      _connectionStatus = 'Connection lost, immediate retry...';
      notifyListeners();

      // Tunggu 1 detik saja sebelum mencoba lagi
      Timer(const Duration(seconds: 1), () {
        _pingController();
      });
      return;
    }

    // Mulai mekanisme retry jika belum me-retry dan belum mencapai batas retry
    if (!isRetrying && _retryCount < maxRetries) {
      _startRetryWithGracePeriod();
    } else if (_retryCount >= maxRetries) {
      // Setelah mencapai batas retry, atur grace period yang lebih lama
      // untuk mencegah terlalu banyak usaha reconnect
      _connectionStatus = 'Disconnected: Max retries reached';
      _retryCount = 0;

      // Stop ping timer untuk mencegah lebih banyak request
      _cancelPingTimer();

      // Tunggu 60 detik sebelum mencoba lagi untuk mencegah flood requests
      Timer(const Duration(seconds: 60), () {
        _connectionStatus = 'Attempting reconnect after cooldown';
        notifyListeners();
        // Restart ping timer dan coba sekali lagi
        _startPingTimer();
      });
    }
  }

  void _startRetryWithGracePeriod() {
    _cancelRetryTimer(); // Batalkan timer yang ada

    // Tunggu grace period sebelum mencoba reconnect
    _connectionStatus =
        'Waiting for reconnect (${gracePeriodSeconds}s grace period)';
    notifyListeners();

    Timer(const Duration(seconds: gracePeriodSeconds), () {
      // Setelah grace period, mulai mekanisme retry
      _startRetryMechanism();
    });
  }

  void _startRetryMechanism() {
    _cancelRetryTimer(); // Batalkan timer yang ada

    _retryTimer = Timer.periodic(
      const Duration(seconds: retryIntervalSeconds),
      (timer) {
        _retryCount++;
        _connectionStatus = 'Attempting reconnect ($_retryCount/$maxRetries)';
        notifyListeners();

        if (_retryCount <= maxRetries) {
          // Coba konek lagi
          _pingController();
        } else {
          // Batas retry sudah tercapai, batalkan timer
          _cancelRetryTimer();
          _connectionStatus = 'Failed to reconnect after $maxRetries attempts';
          notifyListeners();
        }
      },
    );
  }

  void _cancelRetryTimer() {
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  // Reset mekanisme retry dan coba lagi (untuk tombol manual retry)
  Future<bool> manualRetry() async {
    _retryCount = 0;
    _cancelRetryTimer();
    _cancelPingTimer();

    // Gunakan initial connect strategy untuk manual retry
    return await initialConnect();
  }

  // Method ini hanya untuk maintenance koneksi yang sudah ada
  void resetAndRetry() {
    if (_isInitialConnection) {
      return; // Jangan interfere dengan initial connection
    }

    _retryCount = 0;
    _connectionStatus = 'Reconnecting...';
    _cancelRetryTimer();
    _pingController();
  }

  @override
  void dispose() {
    _connectionCheckTimer?.cancel();
    _retryTimer?.cancel();
    _pingTimer?.cancel();
    super.dispose();
  }
}
