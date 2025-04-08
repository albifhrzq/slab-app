import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/aquarium_api_service.dart';
import '../services/connection_manager.dart';
import '../services/manual_settings_cache.dart';
import '../models/profile.dart';
import '../widgets/app_logo.dart';
import 'dart:async';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isManualMode = false;
  Profile _currentProfile = Profile(
    royalBlue: 0,
    blue: 0,
    uv: 0,
    violet: 0,
    red: 0,
    green: 0,
    white: 0,
  );
  bool _isLoading = true;

  // Variabel untuk menyimpan waktu RTC
  DateTime? _currentTime;
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    _loadCurrentState();

    // Mulai timer untuk memperbarui jam setiap detik
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_currentTime != null) {
        setState(() {
          // Increment waktu lokal setiap detik
          _currentTime = _currentTime!.add(const Duration(seconds: 1));
        });
      }
    });

    // Update dari server setiap 1 menit untuk menyinkronkan waktu
    Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        _updateRtcTime();
      }
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  // Metode untuk mengambil waktu dari RTC controller
  Future<void> _updateRtcTime() async {
    try {
      final apiService = Provider.of<AquariumApiService>(
        context,
        listen: false,
      );

      final timeData = await apiService.getCurrentTime();
      setState(() {
        // Parsing format waktu dari controller
        // Mengasumsikan format: {"hour": 12, "minute": 30, "second": 45, "day": 15, "month": 6, "year": 2023}
        _currentTime = DateTime(
          timeData['year'],
          timeData['month'],
          timeData['day'],
          timeData['hour'],
          timeData['minute'],
          timeData['second'],
        );
      });
    } catch (e) {
      // Jika gagal mendapatkan waktu, jangan ubah waktu yang sudah ada
      print('Error fetching RTC time: $e');
    }
  }

  // Metode untuk sinkronisasi waktu smartphone ke RTC
  Future<void> _syncPhoneTimeToRtc() async {
    try {
      final apiService = Provider.of<AquariumApiService>(
        context,
        listen: false,
      );

      // Ambil waktu smartphone saat ini
      final DateTime now = DateTime.now();

      // Kirim ke controller
      final success = await apiService.setTime(now);

      if (success) {
        // Update tampilan dengan waktu baru
        setState(() {
          _currentTime = now;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Device time synchronized with phone time'),
          ),
        );
      } else {
        throw Exception('Failed to set time on controller');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error syncing time: ${e.toString()}')),
      );
    }
  }

  Future<void> _loadCurrentState() async {
    setState(() => _isLoading = true);

    try {
      final apiService = Provider.of<AquariumApiService>(
        context,
        listen: false,
      );

      // Simpan dulu apakah sedang dalam mode manual
      final wasInManualMode = _isManualMode;
      // Simpan pengaturan manual saat ini
      final previousProfile = _currentProfile;

      try {
        // Muat mode operasi saat ini
        final mode = await apiService.getMode();
        final isNowManualMode = mode == 'manual';

        setState(() => _isManualMode = isNowManualMode);

        // Jika dalam mode manual, prioritaskan pengaturan cache
        if (isNowManualMode) {
          // Coba muat dari cache terlebih dahulu
          final cachedProfile = await ManualSettingsCache.getManualProfile();

          if (cachedProfile != null) {
            setState(() => _currentProfile = cachedProfile);

            // Jika profil di perangkat berbeda dengan cache, terapkan pengaturan cache ke perangkat
            try {
              final deviceProfile = await apiService.getCurrentProfile();
              final deviceProfileObj = Profile.fromJson(deviceProfile);

              if (!_areProfilesEqual(deviceProfileObj, cachedProfile)) {
                await apiService.setManualLedValues(cachedProfile.toJson());
              }
            } catch (e) {
              print('Error syncing cached profile to device: $e');
            }
          } else {
            // Jika tidak ada cache, muat dari perangkat
            final profile = await apiService.getCurrentProfile();
            final deviceProfile = Profile.fromJson(profile);
            setState(() => _currentProfile = deviceProfile);

            // Simpan ke cache untuk selanjutnya
            await ManualSettingsCache.saveManualProfile(deviceProfile);
          }
        } else {
          // Jika dalam mode auto, muat profil dari perangkat
          final profile = await apiService.getCurrentProfile();
          setState(() => _currentProfile = Profile.fromJson(profile));
        }
      } catch (e) {
        print('Error loading from device: $e');

        // Jika terjadi error tapi sebelumnya dalam mode manual, gunakan profil sebelumnya
        if (wasInManualMode) {
          // Gunakan pengaturan sebelumnya
          final cachedProfile = await ManualSettingsCache.getManualProfile();
          if (cachedProfile != null) {
            setState(() => _currentProfile = cachedProfile);
          } else {
            setState(() => _currentProfile = previousProfile);
          }
        }
      }

      // Muat waktu dari RTC
      await _updateRtcTime();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading data: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Helper untuk membandingkan dua profil
  bool _areProfilesEqual(Profile a, Profile b) {
    return a.royalBlue == b.royalBlue &&
        a.blue == b.blue &&
        a.uv == b.uv &&
        a.violet == b.violet &&
        a.red == b.red &&
        a.green == b.green &&
        a.white == b.white;
  }

  Future<void> _toggleMode(bool value) async {
    try {
      final apiService = Provider.of<AquariumApiService>(
        context,
        listen: false,
      );
      final success = await apiService.setMode(value ? 'manual' : 'auto');

      if (success) {
        setState(() => _isManualMode = value);

        // If switching to manual mode, load saved manual settings
        if (value) {
          final cachedProfile = await ManualSettingsCache.getManualProfile();
          if (cachedProfile != null) {
            setState(() => _currentProfile = cachedProfile);

            // Apply the cached settings to the device
            await apiService.setManualLedValues(_currentProfile.toJson());
          }
        }
      } else {
        throw Exception('Failed to set mode');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error setting mode: ${e.toString()}')),
      );
    }
  }

  Future<void> _setLedValue(String led, int value) async {
    try {
      final apiService = Provider.of<AquariumApiService>(
        context,
        listen: false,
      );
      final success = await apiService.controlLed(led, value);

      if (success) {
        final updatedProfile = _updateProfileValue(_currentProfile, led, value);
        setState(() => _currentProfile = updatedProfile);

        // Save updated manual settings to cache
        if (_isManualMode) {
          await ManualSettingsCache.saveManualProfile(_currentProfile);
        }
      } else {
        throw Exception('Failed to set LED value');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error setting LED: ${e.toString()}')),
      );
    }
  }

  Profile _updateProfileValue(Profile profile, String led, int value) {
    switch (led) {
      case 'royalBlue':
        return profile.copyWith(royalBlue: value);
      case 'blue':
        return profile.copyWith(blue: value);
      case 'uv':
        return profile.copyWith(uv: value);
      case 'violet':
        return profile.copyWith(violet: value);
      case 'red':
        return profile.copyWith(red: value);
      case 'green':
        return profile.copyWith(green: value);
      case 'white':
        return profile.copyWith(white: value);
      default:
        return profile;
    }
  }

  @override
  Widget build(BuildContext context) {
    final connectionManager = Provider.of<ConnectionManager>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [AppLogo(size: 24), SizedBox(width: 8), Text('SLAB')],
        ),
        actions: [
          // Menampilkan indikator koneksi
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color:
                    connectionManager.isConnected
                        ? Colors.green.withOpacity(0.2)
                        : Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    connectionManager.isConnected ? Icons.wifi : Icons.wifi_off,
                    size: 18,
                    color:
                        connectionManager.isConnected
                            ? Colors.green
                            : Colors.red,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    connectionManager.connectionStatus,
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          connectionManager.isConnected
                              ? Colors.green
                              : Colors.red,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : !connectionManager.isConnected
              ? _buildNoConnectionMessage(context)
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Tampilan Jam RTC
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Theme.of(context).primaryColor.withOpacity(0.7),
                              Theme.of(context).primaryColor.withOpacity(0.3),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.access_time,
                                    size: 24,
                                    color: Colors.white,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'RTC Clock',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  _currentTime != null
                                      ? _formatTime(_currentTime!)
                                      : '--:--:--',
                                  style: const TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'monospace',
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _currentTime != null
                                    ? _formatDate(_currentTime!)
                                    : '--/--/----',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      icon: const Icon(
                                        Icons.sync,
                                        size: 14,
                                        color: Colors.white,
                                      ),
                                      label: const Text(
                                        'Get RTC',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                        ),
                                      ),
                                      onPressed: () async {
                                        await _updateRtcTime();
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Clock synchronized with RTC',
                                            ),
                                          ),
                                        );
                                      },
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 6,
                                        ),
                                        visualDensity: VisualDensity.compact,
                                        side: const BorderSide(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      icon: const Icon(
                                        Icons.smartphone,
                                        size: 14,
                                        color: Colors.white,
                                      ),
                                      label: const Text(
                                        'Sync Phone',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                        ),
                                      ),
                                      onPressed: _syncPhoneTimeToRtc,
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 6,
                                        ),
                                        visualDensity: VisualDensity.compact,
                                        side: const BorderSide(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Mode toggle
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Mode: ${_isManualMode ? 'Manual' : 'Auto'}',
                              style: const TextStyle(fontSize: 18),
                            ),
                            Switch(
                              value: _isManualMode,
                              onChanged: _toggleMode,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Manual controls
                    if (_isManualMode) ...[
                      const Text(
                        'Manual LED Control',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 8),

                      // LED sliders
                      _buildLedSlider(
                        'Royal Blue',
                        'royalBlue',
                        Colors.blue[900]!,
                        _currentProfile.royalBlue,
                      ),
                      _buildLedSlider(
                        'Blue',
                        'blue',
                        Colors.blue,
                        _currentProfile.blue,
                      ),
                      _buildLedSlider(
                        'UV',
                        'uv',
                        Colors.purple[900]!,
                        _currentProfile.uv,
                      ),
                      _buildLedSlider(
                        'Violet',
                        'violet',
                        Colors.purple,
                        _currentProfile.violet,
                      ),
                      _buildLedSlider(
                        'Red',
                        'red',
                        Colors.red,
                        _currentProfile.red,
                      ),
                      _buildLedSlider(
                        'Green',
                        'green',
                        Colors.green,
                        _currentProfile.green,
                      ),
                      _buildLedSlider(
                        'White',
                        'white',
                        Colors.white,
                        _currentProfile.white,
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Profile management buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.lightbulb_outline),
                          label: const Text('Edit Profiles'),
                          onPressed:
                              () => Navigator.pushNamed(context, '/profiles'),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Refresh button
                    ElevatedButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh'),
                      onPressed: () async {
                        // Simpan pengaturan manual saat ini sebelum refresh
                        if (_isManualMode) {
                          await ManualSettingsCache.saveManualProfile(
                            _currentProfile,
                          );
                        }

                        // Sekarang muat ulang data
                        await _loadCurrentState();

                        // Jika dalam mode manual, pastikan pengaturan yang tersimpan digunakan
                        if (_isManualMode) {
                          final cachedProfile =
                              await ManualSettingsCache.getManualProfile();
                          if (cachedProfile != null) {
                            setState(() {
                              _currentProfile = cachedProfile;
                            });

                            // Jika terhubung, terapkan pengaturan ke perangkat
                            final connectionManager =
                                Provider.of<ConnectionManager>(
                                  context,
                                  listen: false,
                                );
                            if (connectionManager.isConnected) {
                              final apiService =
                                  Provider.of<AquariumApiService>(
                                    context,
                                    listen: false,
                                  );
                              await apiService.setManualLedValues(
                                _currentProfile.toJson(),
                              );
                            }
                          }
                        }

                        // Tampilkan notifikasi refresh berhasil
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Data refreshed successfully'),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
    );
  }

  Widget _buildLedSlider(String label, String key, Color color, int value) {
    // Konversi nilai intensitas (0-255) ke persentase (0-100%)
    final percentValue = _intensityToPercent(value);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: color.withOpacity(value / 255),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Slider(
                    value: value.toDouble(),
                    min: 0,
                    max: 255,
                    divisions: 255,
                    label: '$percentValue%',
                    onChanged: (val) {
                      setState(() {
                        _currentProfile = _updateProfileValue(
                          _currentProfile,
                          key,
                          val.toInt(),
                        );
                      });
                    },
                    onChangeEnd: (val) {
                      _setLedValue(key, val.toInt());
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Text('$percentValue%'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Fungsi untuk mengkonversi nilai intensitas (0-255) ke persentase (0-100%)
  int _intensityToPercent(int intensityValue) {
    return (intensityValue / 255 * 100).round().clamp(0, 100);
  }

  // Fungsi untuk mengkonversi nilai persentase (0-100%) ke intensitas (0-255)
  int _percentToIntensity(int percentValue) {
    return (percentValue * 2.55).round().clamp(0, 255);
  }

  // Widget untuk menampilkan pesan ketika tidak terhubung
  Widget _buildNoConnectionMessage(BuildContext context) {
    final connectionManager = Provider.of<ConnectionManager>(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off, size: 80, color: Colors.red.withOpacity(0.7)),
            const SizedBox(height: 16),
            const Text(
              'Not Connected to LED Controller',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              connectionManager.connectionStatus,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.red[700]),
            ),
            const SizedBox(height: 8),
            Text(
              'Please check the device IP address in settings and make sure the device is powered on and connected to the network.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
            const SizedBox(height: 24),

            // Tampilkan status retry jika sedang melakukan retry
            if (connectionManager.isRetrying) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Retrying connection (${connectionManager.retryCount}/5)...',
                    style: const TextStyle(color: Colors.orange),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            ElevatedButton.icon(
              icon: const Icon(Icons.settings),
              label: const Text('Go to Settings'),
              onPressed: () => Navigator.pushNamed(context, '/settings'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Retry Connection'),
              onPressed: () {
                connectionManager.resetAndRetry();
                _loadCurrentState();
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime time) {
    final List<String> weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final List<String> months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    // Weekday dimulai dari 1 (Monday) hingga 7 (Sunday)
    final String weekday = weekdays[time.weekday - 1];
    final String month = months[time.month - 1];

    return '$weekday, $month ${time.day}, ${time.year}';
  }
}
