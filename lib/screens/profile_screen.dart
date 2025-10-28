import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/aquarium_api_service.dart';
import '../services/connection_manager.dart';
import '../services/profile_cache.dart';
import '../models/profile.dart';
import '../widgets/app_logo.dart';
import 'dart:async';
import 'dart:developer' as developer;

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _profileTypes = ['morning', 'midday', 'evening', 'night'];
  bool _isLoading = true;

  // Store complete hourly schedule (24 hours, 0-23)
  List<Map<String, dynamic>> _hourlySchedule = [];

  // Track selected hour for each period
  final Map<String, int> _selectedHour = {};

  // Auto-save debouncing
  Timer? _autoSaveTimer;
  final Map<int, bool> _pendingSaves = {}; // Track which hours need saving
  bool _isSaving = false;

  bool _isPreviewing = false;
  Timer? _previewTimer;
  int _previewStep = 0;
  final int _previewSteps = 30;

  final List<String> _colorOptions = [
    'royalBlue',
    'blue',
    'uv',
    'violet',
    'red',
    'green',
    'white',
  ];

  final Map<String, Color> _colorMap = {
    'royalBlue': Colors.blue[900]!,
    'blue': Colors.blue,
    'uv': Colors.purple[900]!,
    'violet': Colors.purple,
    'red': Colors.red,
    'green': Colors.green,
    'white': Colors.white,
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    // Initialize selected hour for each period (default to first hour)
    for (final type in _profileTypes) {
      _selectedHour[type] = AquariumApiService.getHoursForPeriod(type).first;
    }

    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    setState(() => _isLoading = true);

    try {
      // Check connection status
      final connectionManager = Provider.of<ConnectionManager>(
        context,
        listen: false,
      );

      if (!connectionManager.isConnected) {
        final connected = await connectionManager.initialConnect();
        if (!connected) {
          setState(() => _isLoading = false);
          // Don't show snackbar, just stop - UI will show connection warning
          return;
        }
      }

      // Load from API if connected
      await _syncWithApi();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profiles: ${e.toString()}')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _syncWithApi() async {
    final apiService = Provider.of<AquariumApiService>(context, listen: false);

    try {
      final schedule = await apiService.getHourlySchedule();

      setState(() {
        _hourlySchedule = schedule;
      });

      // Cache the updated schedule
      await ProfileCache.saveHourlySchedule(schedule);

      developer.log(
        'Successfully synced hourly schedule (24 hours)',
        name: 'profile_screen',
      );
    } catch (e) {
      developer.log(
        'Failed to sync hourly schedule: $e',
        name: 'profile_screen',
      );
    }
  }

  // Get hours for a specific period
  List<int> _getHoursForType(String type) {
    return AquariumApiService.getHoursForPeriod(type);
  }

  // Get profile for a specific hour
  Profile _getProfileForHour(int hour) {
    if (hour < 0 || hour >= _hourlySchedule.length) {
      return Profile(
        royalBlue: 0,
        blue: 0,
        uv: 0,
        violet: 0,
        red: 0,
        green: 0,
        white: 0,
      );
    }

    final data = _hourlySchedule[hour];
    return Profile.fromJson(data);
  }

  // Update profile for a specific hour dengan auto-save
  void _updateProfileForHour(int hour, String colorKey, int newValue) {
    if (hour < 0 || hour >= _hourlySchedule.length) return;

    setState(() {
      _hourlySchedule[hour][colorKey] = newValue;
    });

    // Mark this hour as pending save
    _pendingSaves[hour] = true;

    // Debounce: cancel previous timer and start new one
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(milliseconds: 800), () {
      _autoSaveHour(hour);
    });
  }

  // Auto-save a single hour to device and cache
  Future<void> _autoSaveHour(int hour) async {
    if (_isSaving || !_pendingSaves.containsKey(hour)) return;

    setState(() => _isSaving = true);

    try {
      final profile = _hourlySchedule[hour];

      // Save to cache immediately for backup
      await ProfileCache.saveHourlySchedule(_hourlySchedule);

      developer.log('Auto-saving hour $hour to device', name: 'profile_screen');

      // Save to device (since we're always connected in this screen)
      final apiService = Provider.of<AquariumApiService>(
        context,
        listen: false,
      );

      await apiService.setHourProfile(hour, profile);

      // Remove from pending
      _pendingSaves.remove(hour);

      developer.log(
        'Hour $hour auto-saved successfully',
        name: 'profile_screen',
      );

      // Show subtle success indicator
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text('${hour.toString().padLeft(2, '0')}:00 saved'),
              ],
            ),
            duration: const Duration(seconds: 1),
            backgroundColor: Colors.green[700],
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        );
      }
    } on TimeoutException {
      developer.log('Timeout saving hour $hour', name: 'profile_screen');

      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.timer_off, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Save timeout, please try again'),
              ],
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.deepOrange[700],
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        );
      }
    } catch (e) {
      developer.log(
        'Error auto-saving hour $hour: ${e.toString()}',
        name: 'profile_screen',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Save failed: ${e.toString().replaceAll('Exception: ', '')}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _startPreview() {
    setState(() {
      _isPreviewing = true;
      _previewStep = 0;
    });

    final apiService = Provider.of<AquariumApiService>(context, listen: false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preview started - LED will transition through period'),
          duration: Duration(seconds: 2),
        ),
      );
    }

    _previewTimer?.cancel();
    _previewTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_previewStep >= _previewSteps) {
        _stopPreview();
        return;
      }

      final previewProfile = _getPreviewProfile();

      try {
        await apiService.setManualMode(true);
        await apiService.setManualLedValues(previewProfile.toJson());

        if (mounted) {
          setState(() {
            _previewStep++;
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Preview error: ${e.toString()}')),
          );
        }
        _stopPreview();
      }
    });
  }

  void _stopPreview() async {
    _previewTimer?.cancel();
    setState(() {
      _isPreviewing = false;
      _previewStep = 0;
    });

    try {
      final apiService = Provider.of<AquariumApiService>(
        context,
        listen: false,
      );

      await apiService.setManualMode(false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Preview finished, back to automatic mode'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    }
  }

  Profile _getPreviewProfile() {
    final currentType = _profileTypes[_tabController.index];
    final hours = _getHoursForType(currentType);

    if (hours.isEmpty || _hourlySchedule.isEmpty) {
      return Profile(
        royalBlue: 0,
        blue: 0,
        uv: 0,
        violet: 0,
        red: 0,
        green: 0,
        white: 0,
      );
    }

    // Calculate which hours to transition between
    final progress = _previewStep / _previewSteps;
    final totalHours = hours.length;
    final currentHourIndex = (progress * totalHours).floor().clamp(
      0,
      totalHours - 1,
    );
    final nextHourIndex = ((currentHourIndex + 1) % totalHours);

    final currentHour = hours[currentHourIndex];
    final nextHour = hours[nextHourIndex];

    final currentProfile = _getProfileForHour(currentHour);
    final nextProfile = _getProfileForHour(nextHour);

    // Interpolate between current and next
    final segmentProgress = (progress * totalHours) - currentHourIndex;

    return Profile(
      royalBlue: _interpolate(
        currentProfile.royalBlue,
        nextProfile.royalBlue,
        segmentProgress,
      ),
      blue: _interpolate(
        currentProfile.blue,
        nextProfile.blue,
        segmentProgress,
      ),
      uv: _interpolate(currentProfile.uv, nextProfile.uv, segmentProgress),
      violet: _interpolate(
        currentProfile.violet,
        nextProfile.violet,
        segmentProgress,
      ),
      red: _interpolate(currentProfile.red, nextProfile.red, segmentProgress),
      green: _interpolate(
        currentProfile.green,
        nextProfile.green,
        segmentProgress,
      ),
      white: _interpolate(
        currentProfile.white,
        nextProfile.white,
        segmentProgress,
      ),
    );
  }

  int _interpolate(int start, int end, double progress) {
    return (start + (end - start) * progress).round();
  }

  String _getColorName(String colorKey) {
    switch (colorKey) {
      case 'royalBlue':
        return 'Royal Blue';
      case 'blue':
        return 'Blue';
      case 'uv':
        return 'UV';
      case 'violet':
        return 'Violet';
      case 'red':
        return 'Red';
      case 'green':
        return 'Green';
      case 'white':
        return 'White';
      default:
        return colorKey;
    }
  }

  int _getProfileValue(Profile profile, String colorKey) {
    switch (colorKey) {
      case 'royalBlue':
        return profile.royalBlue;
      case 'blue':
        return profile.blue;
      case 'uv':
        return profile.uv;
      case 'violet':
        return profile.violet;
      case 'red':
        return profile.red;
      case 'green':
        return profile.green;
      case 'white':
        return profile.white;
      default:
        return 0;
    }
  }

  Widget _buildHourSelector(String type) {
    final hours = _getHoursForType(type);
    final selectedHour = _selectedHour[type] ?? hours.first;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Hour for ${type.toUpperCase()} (${hours.first}:00 - ${hours.last}:00)',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  hours.map((hour) {
                    final isSelected = hour == selectedHour;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedHour[type] = hour;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color:
                              isSelected
                                  ? Theme.of(context).primaryColor
                                  : Colors.grey.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color:
                                isSelected
                                    ? Theme.of(context).primaryColor
                                    : Colors.grey.withOpacity(0.5),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          '${hour.toString().padLeft(2, '0')}:00',
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight:
                                isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildLedSliders(String type) {
    final selectedHour = _selectedHour[type] ?? _getHoursForType(type).first;
    final profile = _getProfileForHour(selectedHour);

    return _colorOptions.map((color) {
      final value = _getProfileValue(profile, color);
      final percent = (value / 255 * 100).round();

      return Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: _colorMap[color],
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _getColorName(color),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '$percent%',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: _colorMap[color],
                inactiveTrackColor: _colorMap[color]?.withOpacity(0.3),
                thumbColor: _colorMap[color],
                overlayColor: _colorMap[color]?.withOpacity(0.3),
                valueIndicatorColor: _colorMap[color],
                trackHeight: 6,
              ),
              child: Slider(
                value: percent.toDouble(),
                min: 0,
                max: 100,
                divisions: 100,
                label: '$percent%',
                onChanged: (newPercent) {
                  final newValue = (newPercent * 255 / 100).round().clamp(
                    0,
                    255,
                  );
                  _updateProfileForHour(selectedHour, color, newValue);
                },
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildPreviewOverlay() {
    if (!_isPreviewing) return const SizedBox.shrink();

    final previewProfile = _getPreviewProfile();

    return Container(
      color: Colors.black.withOpacity(0.7),
      child: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Preview Mode (Live)',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Time: ${_previewStep}s / ${_previewSteps}s',
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 16),
                // LED indicators
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children:
                      _colorOptions.map((color) {
                        final intensity = _getProfileValue(
                          previewProfile,
                          color,
                        );
                        final percent = (intensity / 255.0 * 100).round();
                        return Column(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: _colorMap[color]!.withOpacity(
                                  intensity / 255.0,
                                ),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$percent%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _stopPreview,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Stop Preview'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _previewTimer?.cancel();
    _autoSaveTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connectionManager = Provider.of<ConnectionManager>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [AppLogo(size: 24), SizedBox(width: 8), Text('Profiles')],
        ),
        automaticallyImplyLeading: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child:
                  connectionManager.isConnected
                      ? const Icon(Icons.wifi, color: Colors.green)
                      : const Icon(Icons.wifi_off, color: Colors.red),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Morning'),
            Tab(text: 'Midday'),
            Tab(text: 'Evening'),
            Tab(text: 'Night'),
          ],
        ),
      ),
      body: Stack(
        children: [
          // Check connection first - if not connected, show warning
          !connectionManager.isConnected
              ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.wifi_off,
                        size: 80,
                        color: Colors.orange[300],
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Device Not Connected',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Please connect to the device first to edit profiles.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Connection status
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.info_outline,
                              color: Colors.orange,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                connectionManager.connectionStatus,
                                style: const TextStyle(
                                  color: Colors.orange,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Retry button
                      ElevatedButton.icon(
                        icon: const Icon(Icons.wifi),
                        label: const Text('Retry Connection'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                        ),
                        onPressed:
                            connectionManager.isRetrying
                                ? null
                                : () async {
                          final success =
                              await connectionManager.manualRetry();
                          if (success && mounted) {
                            // Reload profiles after successful connection
                            _loadProfiles();
                          }
                        },
                      ),
                    ],
                  ),
                ),
              )
              : _isLoading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                controller: _tabController,
                children:
                    _profileTypes.map((type) {
                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Hour Selector
                            _buildHourSelector(type),

                            // LED Intensity Sliders
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${type.toUpperCase()} - LED Intensity',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    ..._buildLedSliders(type),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Preview button
                            ElevatedButton.icon(
                              onPressed: _startPreview,
                              icon: const Icon(Icons.play_arrow),
                              label: const Text('Preview Period'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Info message
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.blue.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: Colors.blue[700],
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Settings for ${(_selectedHour[type] ?? _getHoursForType(type).first).toString().padLeft(2, '0')}:00',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.blue[700],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Auto-save indicator
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.green.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _isSaving ? Icons.sync : Icons.cloud_done,
                                    color: Colors.green[700],
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _isSaving
                                          ? 'Menyimpan...'
                                          : 'Perubahan tersimpan otomatis',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.green[700],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
              ),
          _buildPreviewOverlay(),
        ],
      ),
    );
  }
}
