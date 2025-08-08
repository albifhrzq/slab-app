import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../services/aquarium_api_service.dart';
import '../services/connection_manager.dart';
import '../services/manual_settings_cache.dart';
import '../models/profile.dart';
import '../widgets/app_logo.dart';
import '../config/app_config.dart';
import 'dart:async';

enum ControlMode { manual, auto, off }

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  ControlMode _currentMode = ControlMode.auto;
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

    // Load state dan auto sync waktu
    _loadCurrentState();

    // Mulai timer untuk memperbarui jam setiap detik
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          // Selalu gunakan waktu phone yang real-time
          _currentTime = DateTime.now();
        });
      }
    });

    // Sync waktu ke controller setiap 5 menit untuk backup
    Timer.periodic(const Duration(minutes: 5), (_) {
      if (mounted) {
        _autoSyncTimeFromPhone();
      }
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  // Metode untuk set waktu dari smartphone ke controller
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
            content: Text('Device time updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('Failed to set time on controller');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error setting time: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Auto sync waktu saat load - otomatis ambil dari phone
  Future<void> _autoSyncTimeFromPhone() async {
    try {
      final apiService = Provider.of<AquariumApiService>(
        context,
        listen: false,
      );

      // Selalu gunakan waktu smartphone
      final DateTime now = DateTime.now();

      // Set waktu di controller dengan waktu phone
      await apiService.setTime(now);

      // Update tampilan
      setState(() {
        _currentTime = now;
      });
    } catch (e) {
      // Jika gagal sync ke controller, tetap tampilkan waktu phone
      setState(() {
        _currentTime = DateTime.now();
      });
      print('Auto sync failed, using phone time for display: $e');
    }
  }

  Future<void> _loadCurrentState() async {
    setState(() => _isLoading = true);

    try {
      final apiService = Provider.of<AquariumApiService>(
        context,
        listen: false,
      );

      // Coba koneksi awal dengan retry terbatas
      final connectionManager = Provider.of<ConnectionManager>(
        context,
        listen: false,
      );
      final connected = await connectionManager.initialConnect();

      if (!connected) {
        // Jika gagal connect, gunakan data cache saja
        final cachedProfile = await ManualSettingsCache.getManualProfile();
        if (cachedProfile != null) {
          setState(() {
            _currentProfile = cachedProfile;
            _currentMode = ControlMode.manual; // Default ke manual jika offline
          });
        }

        // Set waktu dari phone
        setState(() {
          _currentTime = DateTime.now();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Device not connected. Using offline mode.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Jika berhasil connect, lanjutkan load data dari device
      // Simpan dulu apakah sedang dalam mode manual
      final wasInManualMode = _currentMode == ControlMode.manual;
      // Simpan pengaturan manual saat ini
      final previousProfile = _currentProfile;

      try {
        // Muat mode operasi saat ini
        final mode = await apiService.getMode();
        final newMode = _getModeFromString(mode);

        setState(() => _currentMode = newMode);

        // Jika dalam mode manual, prioritaskan pengaturan cache
        if (newMode == ControlMode.manual) {
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

      // Auto sync dan set waktu dari phone
      await _autoSyncTimeFromPhone();
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

  Future<void> _setMode(ControlMode newMode) async {
    try {
      final apiService = Provider.of<AquariumApiService>(
        context,
        listen: false,
      );
      final success = await apiService.setMode(_getModeString(newMode));

      if (success) {
        setState(() => _currentMode = newMode);

        // If switching to manual mode, load saved manual settings
        if (newMode == ControlMode.manual) {
          final cachedProfile = await ManualSettingsCache.getManualProfile();
          if (cachedProfile != null) {
            setState(() => _currentProfile = cachedProfile);

            // Apply the cached settings to the device
            await apiService.setManualLedValues(_currentProfile.toJson());
          }
        } else if (newMode == ControlMode.off) {
          // Turn off all LEDs
          final offProfile = Profile(
            royalBlue: 0,
            blue: 0,
            uv: 0,
            violet: 0,
            red: 0,
            green: 0,
            white: 0,
          );
          setState(() => _currentProfile = offProfile);
          await apiService.setManualLedValues(offProfile.toJson());
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
        automaticallyImplyLeading: false,
        actions: [
          // Menampilkan indikator koneksi
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
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
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  OutlinedButton.icon(
                                    icon: const Icon(
                                      Icons.access_time,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                    label: const Text(
                                      'Set Time to Device',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                      ),
                                    ),
                                    onPressed: _syncPhoneTimeToRtc,
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      side: const BorderSide(
                                        color: Colors.white,
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

                    // Mode selection buttons
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Control Mode',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildModeButton(
                                    ControlMode.auto,
                                    'Auto',
                                    Icons.auto_mode,
                                    Colors.green,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildModeButton(
                                    ControlMode.manual,
                                    'Manual',
                                    Icons.tune,
                                    Colors.blue,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildModeButton(
                                    ControlMode.off,
                                    'Off',
                                    Icons.power_settings_new,
                                    Colors.red,
                                  ),
                                ),
                              ],
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
                        const Color(0xFF002FA7), // Royal Blue yang lebih akurat
                        _currentProfile.royalBlue,
                      ),
                      _buildLedSlider(
                        'Blue',
                        'blue',
                        const Color(0xFF0047AB), // True Blue
                        _currentProfile.blue,
                      ),
                      _buildLedSlider(
                        'UV',
                        'uv',
                        const Color(0xFF8A2BE2), // UV purple yang lebih gelap
                        _currentProfile.uv,
                      ),
                      _buildLedSlider(
                        'Violet',
                        'violet',
                        const Color(0xFF9400D3), // Dark violet
                        _currentProfile.violet,
                      ),
                      _buildLedSlider(
                        'Red',
                        'red',
                        const Color(0xFFFF0000), // True red
                        _currentProfile.red,
                      ),
                      _buildLedSlider(
                        'Green',
                        'green',
                        const Color(0xFF00FF00), // True green
                        _currentProfile.green,
                      ),
                      _buildLedSlider(
                        'White',
                        'white',
                        const Color(
                          0xFFE8E8E8,
                        ), // Warm white dengan border yang akan terlihat
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

                    // Connection status dan retry button
                    Consumer<ConnectionManager>(
                      builder: (context, connectionManager, child) {
                        if (connectionManager.isConnected) {
                          // Jika terhubung, tampilkan tombol refresh biasa
                          return ElevatedButton.icon(
                            icon: const Icon(Icons.refresh),
                            label: const Text('Refresh Data'),
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

                                  // Terapkan pengaturan ke perangkat
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

                              // Tampilkan notifikasi refresh berhasil
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Data refreshed successfully'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            },
                          );
                        } else {
                          // Jika tidak terhubung, tampilkan tombol retry connection
                          return Column(
                            children: [
                              // Status koneksi
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.orange),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.wifi_off,
                                      color: Colors.orange,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        connectionManager.connectionStatus,
                                        style: const TextStyle(
                                          color: Colors.orange,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Tombol retry
                              ElevatedButton.icon(
                                icon: const Icon(Icons.wifi),
                                label: const Text('Retry Connection'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed:
                                    connectionManager.isRetrying
                                        ? null
                                        : () async {
                                          final success =
                                              await connectionManager
                                                  .manualRetry();
                                          if (success) {
                                            // Jika berhasil connect, load data
                                            await _loadCurrentState();

                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Connected successfully!',
                                                ),
                                                backgroundColor: Colors.green,
                                              ),
                                            );
                                          }
                                        },
                              ),
                            ],
                          );
                        }
                      },
                    ),

                    // Debug panel (hanya tampil di debug mode)
                    if (kDebugMode) ...[
                      const SizedBox(height: 24),
                      Card(
                        color: Colors.orange.withOpacity(0.1),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.developer_mode,
                                    color: Colors.orange[700],
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Development Mode',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange[700],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Icon(
                                    AppConfig.enableMockMode
                                        ? Icons.cloud_off
                                        : Icons.wifi,
                                    size: 16,
                                    color:
                                        AppConfig.enableMockMode
                                            ? Colors.orange
                                            : Colors.green,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    AppConfig.enableMockMode
                                        ? 'Mock Mode (Offline)'
                                        : 'Hardware Mode (Online)',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color:
                                          AppConfig.enableMockMode
                                              ? Colors.orange[700]
                                              : Colors.green[700],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Base URL: ${AppConfig.defaultBaseUrl}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              Text(
                                'Timeout: ${AppConfig.defaultTimeoutSeconds}s | Mock Delay: ${AppConfig.mockDelayMs}ms',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              if (AppConfig.enableMockMode) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'To disable mock mode, run:\nflutter run --dart-define=MOCK_MODE=false',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontFamily: 'monospace',
                                      color: Colors.orange[800],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
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
                    color: color, // 100% warna tanpa opacity
                    shape: BoxShape.circle,
                    border: Border.all(
                      color:
                          color == const Color(0xFFE8E8E8)
                              ? Colors.grey.withOpacity(
                                0.6,
                              ) // Border lebih gelap untuk white
                              : Colors.grey.withOpacity(0.3),
                      width: color == const Color(0xFFE8E8E8) ? 1.5 : 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      // Track yang aktif mengikuti warna LED
                      activeTrackColor: color,
                      // Track yang tidak aktif dengan opacity rendah
                      inactiveTrackColor: color.withOpacity(0.2),
                      // Thumb (handle) dengan warna LED
                      thumbColor: color,
                      // Overlay saat ditekan
                      overlayColor: color.withOpacity(0.2),
                      // Warna value indicator saat dikontrol
                      valueIndicatorColor: color,
                      valueIndicatorTextStyle: const TextStyle(
                        color: Color.fromARGB(255, 0, 0, 0), // Ubah ke hitam
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 35,
                  child: Text(
                    '$percentValue%',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black, // Ubah ke hitam
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeButton(
    ControlMode mode,
    String label,
    IconData icon,
    Color color,
  ) {
    final isSelected = _currentMode == mode;

    return ElevatedButton.icon(
      onPressed: () => _setMode(mode),
      icon: Icon(icon, size: 20, color: isSelected ? Colors.white : color),
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : color,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? color : Colors.transparent,
        foregroundColor: isSelected ? Colors.white : color,
        side: BorderSide(color: color, width: 2),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: isSelected ? 4 : 0,
      ),
    );
  }

  // Fungsi untuk mengkonversi nilai intensitas (0-255) ke persentase (0-100%)
  int _intensityToPercent(int intensityValue) {
    return (intensityValue / 255 * 100).round().clamp(0, 100);
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

  // Helper methods untuk mode control
  ControlMode _getModeFromString(String mode) {
    switch (mode.toLowerCase()) {
      case 'manual':
        return ControlMode.manual;
      case 'auto':
      case 'automatic':
        return ControlMode.auto;
      case 'off':
        return ControlMode.off;
      default:
        return ControlMode.auto;
    }
  }

  String _getModeString(ControlMode mode) {
    switch (mode) {
      case ControlMode.manual:
        return 'manual';
      case ControlMode.auto:
        return 'auto';
      case ControlMode.off:
        return 'off';
    }
  }

  bool get _isManualMode => _currentMode == ControlMode.manual;
}
