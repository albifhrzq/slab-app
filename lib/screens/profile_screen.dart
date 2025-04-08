import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/aquarium_api_service.dart';
import '../services/connection_manager.dart';
import '../services/profile_cache.dart';
import '../models/profile.dart';
import '../widgets/app_logo.dart';
import 'dart:async';
import 'dart:convert';

class LightSchedulePoint {
  final int hour;
  final Profile profile;

  LightSchedulePoint(this.hour, this.profile);
}

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
  final Map<String, Profile> _profiles = {};
  final Map<String, List<LightSchedulePoint>> _hourlySchedules = {};
  bool _isPreviewing = false;
  Timer? _previewTimer;
  int _previewStep = 0;
  final int _previewSteps = 30; // 30 detik untuk preview
  bool _isPaused = false;
  String _selectedColor = 'royalBlue'; // Warna yang dipilih untuk diedit
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
  bool _isDebugging = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    setState(() => _isLoading = true);

    try {
      final apiService = Provider.of<AquariumApiService>(
        context,
        listen: false,
      );

      // Load profiles
      for (final type in _profileTypes) {
        try {
          final profileData = await apiService.getProfile(type);
          final profile = Profile.fromJson(profileData);

          setState(() {
            _profiles[type] = profile;
            _initHourlySchedule(type, profile);
          });

          // Cache locally
          await ProfileCache.saveProfile(type, profile);
        } catch (e) {
          // Try to use cached profile if available
          final cachedProfile = await ProfileCache.getProfile(type);
          if (cachedProfile != null) {
            setState(() {
              _profiles[type] = cachedProfile;
              _initHourlySchedule(type, cachedProfile);
            });
          } else {
            // Create default profile
            final defaultProfile = Profile(
              royalBlue: type == 'night' ? 30 : 100,
              blue: type == 'night' ? 20 : 150,
              uv: type == 'night' ? 0 : 50,
              violet: type == 'night' ? 0 : 50,
              red: type == 'night' ? 5 : (type == 'evening' ? 200 : 150),
              green: type == 'night' ? 5 : 100,
              white: type == 'night' ? 0 : (type == 'midday' ? 255 : 200),
            );
            setState(() {
              _profiles[type] = defaultProfile;
              _initHourlySchedule(type, defaultProfile);
            });
          }
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading profiles: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Initialize hourly schedule for a profile type
  void _initHourlySchedule(String type, Profile profile) {
    // Define start and end hours for each profile type
    final Map<String, List<int>> typeHours = {
      'morning': [6, 7, 8, 9, 10, 11, 12],
      'midday': [12, 13, 14, 15, 16, 17, 18],
      'evening': [18, 19, 20, 21, 22, 23, 0],
      'night': [0, 1, 2, 3, 4, 5, 6],
    };

    final hours = typeHours[type] ?? [0, 1, 2, 3, 4, 5];
    final schedule = <LightSchedulePoint>[];

    // Create a basic schedule with smooth transitions
    for (int i = 0; i < hours.length; i++) {
      // Adjust intensity based on position in sequence
      double factor = 1.0;
      if (type == 'morning') {
        factor = i / (hours.length - 1); // Increasing from 0 to 1
      } else if (type == 'evening') {
        factor = 1.0 - (i / (hours.length - 1)); // Decreasing from 1 to 0
      } else if (type == 'night') {
        factor = 0.3; // Constant low
      } else if (type == 'midday') {
        factor = 1.0; // Constant high
      }

      // Create a profile with adjusted intensity
      final hourProfile = Profile(
        royalBlue: (profile.royalBlue * factor).round(),
        blue: (profile.blue * factor).round(),
        uv: (profile.uv * factor).round(),
        violet: (profile.violet * factor).round(),
        red: (profile.red * factor).round(),
        green: (profile.green * factor).round(),
        white: (profile.white * factor).round(),
      );

      schedule.add(LightSchedulePoint(hours[i], hourProfile));
    }

    _hourlySchedules[type] = schedule;
  }

  Future<void> _saveProfile(String type, Profile profile) async {
    try {
      setState(() => _isLoading = true);

      final connectionManager = Provider.of<ConnectionManager>(
        context,
        listen: false,
      );
      final apiService = Provider.of<AquariumApiService>(
        context,
        listen: false,
      );

      // Selalu simpan ke cache lokal
      await ProfileCache.saveProfile(type, profile);

      // Jika terhubung, kirim ke perangkat
      if (connectionManager.isConnected) {
        final success = await apiService.setProfile(type, profile.toJson());

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile saved successfully to device'),
            ),
          );
        } else {
          throw Exception('Failed to save profile to device');
        }
      } else {
        // Hanya tersimpan secara lokal
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile saved locally only (device not connected)'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving profile: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _startPreview() {
    // Reset state
    setState(() {
      _isPreviewing = true;
      _previewStep = 0;
      _isPaused = false;
    });

    // Dapatkan akses ke apiService
    final apiService = Provider.of<AquariumApiService>(context, listen: false);

    // Notifikasi ke pengguna
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Preview started - LED intensity will change directly on hardware',
        ),
        duration: Duration(seconds: 2),
      ),
    );

    _previewTimer?.cancel();
    _previewTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_previewStep >= _previewSteps) {
        _stopPreview();
        return;
      }

      // Dapatkan profil untuk tahap preview ini
      final previewProfile = _getPreviewProfile();

      // Format data dengan format yang konsisten
      final Map<String, dynamic> ledValues = {
        "royalBlue": previewProfile.royalBlue,
        "blue": previewProfile.blue,
        "uv": previewProfile.uv,
        "violet": previewProfile.violet,
        "red": previewProfile.red,
        "green": previewProfile.green,
        "white": previewProfile.white,
      };

      try {
        // Kirim profil ke hardware dengan mode manual
        await apiService.setManualMode(true);
        await apiService.setManualLedValues(ledValues);

        if (mounted) {
          setState(() {
            _previewStep++;
          });
        }
      } catch (e) {
        // Tampilkan error jika terjadi masalah komunikasi
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Preview error: ${e.toString()}')),
        );
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
      // Kembalikan ke mode otomatis saat preview selesai
      final apiService = Provider.of<AquariumApiService>(
        context,
        listen: false,
      );

      await apiService.setManualMode(false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preview finished, back to automatic mode'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    }
  }

  Profile _getPreviewProfile() {
    final currentType = _profileTypes[_tabController.index];

    // Jika dalam mode preview per jam (default)
    if (!_isPaused) {
      final schedulePoints = _hourlySchedules[currentType] ?? [];

      if (schedulePoints.isEmpty) {
        return _profiles[currentType] ??
            Profile(
              royalBlue: 0,
              blue: 0,
              uv: 0,
              violet: 0,
              red: 0,
              green: 0,
              white: 0,
            );
      }

      // For preview, we'll simulate transitioning through all hours in the schedule
      final totalPoints = schedulePoints.length;
      final progress = _previewStep / _previewSteps;
      final pointIndex = (progress * totalPoints).floor();
      final nextPointIndex = (pointIndex + 1) % totalPoints;

      // Calculate progress within the current segment
      final segmentProgress = (progress * totalPoints) - pointIndex;

      final currentPoint = schedulePoints[pointIndex].profile;
      final nextPoint = schedulePoints[nextPointIndex].profile;

      return Profile(
        royalBlue: _interpolate(
          currentPoint.royalBlue,
          nextPoint.royalBlue,
          segmentProgress,
        ),
        blue: _interpolate(currentPoint.blue, nextPoint.blue, segmentProgress),
        uv: _interpolate(currentPoint.uv, nextPoint.uv, segmentProgress),
        violet: _interpolate(
          currentPoint.violet,
          nextPoint.violet,
          segmentProgress,
        ),
        red: _interpolate(currentPoint.red, nextPoint.red, segmentProgress),
        green: _interpolate(
          currentPoint.green,
          nextPoint.green,
          segmentProgress,
        ),
        white: _interpolate(
          currentPoint.white,
          nextPoint.white,
          segmentProgress,
        ),
      );
    }
    // Untuk preview yang dipause, gunakan nilai profil yang ada
    else {
      return _profiles[currentType] ??
          Profile(
            royalBlue: 0,
            blue: 0,
            uv: 0,
            violet: 0,
            red: 0,
            green: 0,
            white: 0,
          );
    }
  }

  int _interpolate(int start, int end, double progress) {
    // Memastikan nilai yang dihasilkan adalah integer, tidak ada decimals
    return (start + (end - start) * progress).round();
  }

  // Update profile value at a specific hour
  void _updateProfileAtHour(String type, int hour, String colorKey, int value) {
    final schedulePoints = _hourlySchedules[type] ?? [];
    final pointIndex = schedulePoints.indexWhere((point) => point.hour == hour);

    if (pointIndex >= 0) {
      final oldPoint = schedulePoints[pointIndex];
      Profile updatedProfile;

      switch (colorKey) {
        case 'royalBlue':
          updatedProfile = oldPoint.profile.copyWith(royalBlue: value);
          break;
        case 'blue':
          updatedProfile = oldPoint.profile.copyWith(blue: value);
          break;
        case 'uv':
          updatedProfile = oldPoint.profile.copyWith(uv: value);
          break;
        case 'violet':
          updatedProfile = oldPoint.profile.copyWith(violet: value);
          break;
        case 'red':
          updatedProfile = oldPoint.profile.copyWith(red: value);
          break;
        case 'green':
          updatedProfile = oldPoint.profile.copyWith(green: value);
          break;
        case 'white':
          updatedProfile = oldPoint.profile.copyWith(white: value);
          break;
        default:
          updatedProfile = oldPoint.profile;
      }

      setState(() {
        schedulePoints[pointIndex] = LightSchedulePoint(hour, updatedProfile);
        // Also update the main profile by averaging all hourly profiles
        _updateAverageProfile(type);
      });
    }
  }

  // Update the main profile based on hourly values
  void _updateAverageProfile(String type) {
    final schedulePoints = _hourlySchedules[type] ?? [];
    if (schedulePoints.isEmpty) return;

    int totalRoyalBlue = 0;
    int totalBlue = 0;
    int totalUv = 0;
    int totalViolet = 0;
    int totalRed = 0;
    int totalGreen = 0;
    int totalWhite = 0;

    for (final point in schedulePoints) {
      totalRoyalBlue += point.profile.royalBlue;
      totalBlue += point.profile.blue;
      totalUv += point.profile.uv;
      totalViolet += point.profile.violet;
      totalRed += point.profile.red;
      totalGreen += point.profile.green;
      totalWhite += point.profile.white;
    }

    final count = schedulePoints.length;
    setState(() {
      _profiles[type] = Profile(
        royalBlue: (totalRoyalBlue / count).round(),
        blue: (totalBlue / count).round(),
        uv: (totalUv / count).round(),
        violet: (totalViolet / count).round(),
        red: (totalRed / count).round(),
        green: (totalGreen / count).round(),
        white: (totalWhite / count).round(),
      );
    });
  }

  Widget _buildHourlyIntensityChart(String type) {
    final schedulePoints = _hourlySchedules[type] ?? [];
    if (schedulePoints.isEmpty) return Container();

    // Sort schedule points by hour
    schedulePoints.sort((a, b) => a.hour.compareTo(b.hour));

    return Container(
      height: 280,
      padding: const EdgeInsets.only(top: 20, right: 20, left: 8, bottom: 12),
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: true),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  // Konversi nilai 0-255 menjadi persentase 0-100%
                  final percentValue = _intensityToPercent(value.toInt());
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Text(
                      '$percentValue%',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  );
                },
              ),
              axisNameWidget: const Text(
                'Intensity (%)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= schedulePoints.length) {
                    return const Text('');
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      '${schedulePoints[index].hour}:00',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  );
                },
              ),
              axisNameWidget: const Text(
                'Hour',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() == schedulePoints.length ~/ 2) {
                    return const Text(
                      'Intensity All Colors',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: true),
          lineTouchData: LineTouchData(
            enabled: true,
            touchTooltipData: LineTouchTooltipData(
              tooltipBgColor: Colors.blueGrey.withOpacity(0.8),
              tooltipMargin: 8,
              getTooltipItems: (List<LineBarSpot> touchedSpots) {
                // Tampilkan tooltip untuk semua warna
                return touchedSpots.map((spot) {
                  final colorKey = _colorOptions[spot.barIndex];
                  final percentValue = _intensityToPercent(spot.y.toInt());
                  final isSelected = colorKey == _selectedColor;

                  return LineTooltipItem(
                    '${_getColorName(colorKey)}: $percentValue%',
                    TextStyle(
                      color: Colors.white,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  );
                }).toList();
              },
            ),
            touchCallback: (
              FlTouchEvent event,
              LineTouchResponse? touchResponse,
            ) {
              // Hanya proses event jika ada response valid
              if (touchResponse == null ||
                  touchResponse.lineBarSpots == null ||
                  touchResponse.lineBarSpots!.isEmpty) {
                return;
              }

              // Tangani semua jenis event input
              if (event is FlTapDownEvent ||
                  event is FlTapUpEvent ||
                  event is FlLongPressStart ||
                  event is FlLongPressMoveUpdate ||
                  event is FlPanDownEvent ||
                  event is FlPanUpdateEvent) {
                // Ambil lokasi x (jam) yang sedang ditekan/digeser
                final touchedX = touchResponse.lineBarSpots!.first.x.toInt();
                if (touchedX < 0 || touchedX >= schedulePoints.length) return;

                final hour = schedulePoints[touchedX].hour;

                // Temukan indeks warna yang dipilih dalam array _colorOptions
                final selectedColorIndex = _colorOptions.indexOf(
                  _selectedColor,
                );

                // Untuk event geser, gunakan posisi y dari event
                if ((event is FlPanUpdateEvent ||
                        event is FlLongPressMoveUpdate) &&
                    event.localPosition != null) {
                  // Untuk gestur geser dan tekan lama, ambil posisi y dari event
                  final RenderBox renderBox =
                      context.findRenderObject() as RenderBox;
                  final chartPosition = renderBox.globalToLocal(
                    event.localPosition!,
                  );

                  // Area grafik sekitar 280 pixel
                  double chartHeight = 280;
                  double topPadding = 20;
                  // Hitung nilai relatif dengan memperhatikan bahwa 0 di bawah dan 255 di atas
                  double relativeY =
                      chartHeight - (chartPosition.dy - topPadding);
                  // Pastikan nilai dalam batas yang benar
                  relativeY = relativeY.clamp(0.0, chartHeight);

                  // Konversi ke nilai intensitas (0-255)
                  int newValue = ((relativeY / chartHeight) * 255)
                      .round()
                      .clamp(0, 255);

                  // Update profil dengan nilai baru untuk warna yang dipilih
                  _updateProfileAtHour(type, hour, _selectedColor, newValue);
                  setState(() {});
                }
                // Untuk event tap, cari data point terdekat
                else {
                  // Coba cari spot yang sesuai dengan warna yang dipilih
                  final selectedBarSpots =
                      touchResponse.lineBarSpots!
                          .where((spot) => spot.barIndex == selectedColorIndex)
                          .toList();

                  if (selectedBarSpots.isNotEmpty) {
                    // Jika ada titik untuk warna yang dipilih, gunakan nilainya
                    int newValue = selectedBarSpots.first.y.toInt().clamp(
                      0,
                      255,
                    );
                    _updateProfileAtHour(type, hour, _selectedColor, newValue);
                    setState(() {});
                  }
                }
              }
            },
          ),
          lineBarsData:
              _colorOptions.map((color) {
                bool isSelected = color == _selectedColor;
                return LineChartBarData(
                  spots: List.generate(schedulePoints.length, (index) {
                    final point = schedulePoints[index];
                    final value = _getProfileValue(point.profile, color);
                    return FlSpot(index.toDouble(), value.toDouble());
                  }),
                  isCurved: true,
                  color: _colorMap[color] ?? Colors.blue,
                  barWidth: isSelected ? 4.0 : 1.5,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: isSelected,
                    getDotPainter: (spot, percent, barData, index) {
                      return FlDotCirclePainter(
                        radius: isSelected ? 6 : 4,
                        color: _colorMap[color] ?? Colors.blue,
                        strokeColor:
                            isSelected ? Colors.white : Colors.transparent,
                        strokeWidth: isSelected ? 2 : 0,
                      );
                    },
                  ),
                  belowBarData: BarAreaData(
                    show: isSelected,
                    color: (_colorMap[color] ?? Colors.blue).withOpacity(0.1),
                    applyCutOffY: true,
                    cutOffY: 0,
                    gradient: LinearGradient(
                      colors: [
                        (_colorMap[color] ?? Colors.blue).withOpacity(0.4),
                        (_colorMap[color] ?? Colors.blue).withOpacity(0.0),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  dashArray: isSelected ? null : [4, 2],
                );
              }).toList(),
          minX: 0,
          maxX: schedulePoints.length - 1.0,
          minY: 0,
          maxY: 255,
        ),
      ),
    );
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

  Widget _buildColorSelector() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select color to edit:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children:
                _colorOptions.map((color) {
                  final isSelected = color == _selectedColor;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedColor = color;
                      });
                    },
                    child: Column(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _colorMap[color],
                            shape: BoxShape.circle,
                            border: Border.all(
                              color:
                                  isSelected
                                      ? Colors.white
                                      : Colors.transparent,
                              width: 3,
                            ),
                            boxShadow:
                                isSelected
                                    ? [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.3),
                                        blurRadius: 5,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                    : null,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getColorName(color),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight:
                                isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
          ),
        ],
      ),
    );
  }

  String _getColorName(String colorKey) {
    switch (colorKey) {
      case 'royalBlue':
        return 'R. Blue';
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

  Widget _buildPreviewOverlay() {
    if (!_isPreviewing) return const SizedBox.shrink();

    final previewProfile = _getPreviewProfile();
    final currentType = _profileTypes[_tabController.index];
    final nextType = _profileTypes[(_tabController.index + 1) % 4];

    return Container(
      color: Colors.black.withOpacity(0.7),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 16.0),
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
              const SizedBox(height: 8),
              Text(
                'Transition from $currentType to $nextType',
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),
              // LED indicator display
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Active LEDs:',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children:
                            _colorOptions.map((color) {
                              final intensity = _getProfileValue(
                                previewProfile,
                                color,
                              );
                              final percent = intensity / 255.0;
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8.0,
                                ),
                                child: Column(
                                  children: [
                                    Container(
                                      width: 30,
                                      height: 30,
                                      decoration: BoxDecoration(
                                        color: _colorMap[color]!.withOpacity(
                                          percent,
                                        ),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 1,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${(percent * 100).toInt()}%',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                    // Quick action buttons
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _buildQuickActionButton(color, 0, '0%'),
                                        const SizedBox(width: 4),
                                        _buildQuickActionButton(
                                          color,
                                          128,
                                          '50%',
                                        ),
                                        const SizedBox(width: 4),
                                        _buildQuickActionButton(
                                          color,
                                          255,
                                          '100%',
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Debug info
              if (_isDebugging) _buildDebugInfo(previewProfile),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: _pausePreview,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                    ),
                    child: const Text('Pause'),
                  ),
                  ElevatedButton(
                    onPressed: _stopPreview,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    child: const Text('Stop Preview'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _isDebugging = !_isDebugging;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                    ),
                    child: Text(_isDebugging ? 'Hide Debug' : 'Debug Data'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Tombol aksi cepat untuk mengatur intensitas LED secara langsung
  Widget _buildQuickActionButton(String color, int value, String label) {
    return GestureDetector(
      onTap: () => _setQuickIntensity(color, value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: _colorMap[color] ?? Colors.white, width: 1),
        ),
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 10),
        ),
      ),
    );
  }

  // Metode untuk mengatur intensitas LED secara cepat
  void _setQuickIntensity(String color, int value) async {
    try {
      final apiService = Provider.of<AquariumApiService>(
        context,
        listen: false,
      );

      // Ambil nilai saat ini dari preview profile
      final profile = _getPreviewProfile();

      // Update nilai untuk warna yang dipilih
      Map<String, dynamic> ledValues = {
        "royalBlue": profile.royalBlue,
        "blue": profile.blue,
        "uv": profile.uv,
        "violet": profile.violet,
        "red": profile.red,
        "green": profile.green,
        "white": profile.white,
      };

      // Set nilai baru untuk warna yang dipilih
      ledValues[color] = value;

      // Kirim ke perangkat
      await apiService.setManualLedValues(ledValues);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$color set to $value'),
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    }
  }

  void _pausePreview() {
    if (_isPaused) {
      // Resume preview
      _previewTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
        if (_previewStep >= _previewSteps) {
          _stopPreview();
          return;
        }

        final previewProfile = _getPreviewProfile();

        // Format data dengan format yang konsisten
        final Map<String, dynamic> ledValues = {
          "royalBlue": previewProfile.royalBlue,
          "blue": previewProfile.blue,
          "uv": previewProfile.uv,
          "violet": previewProfile.violet,
          "red": previewProfile.red,
          "green": previewProfile.green,
          "white": previewProfile.white,
        };

        try {
          final apiService = Provider.of<AquariumApiService>(
            context,
            listen: false,
          );

          await apiService.setManualLedValues(ledValues);

          if (mounted) {
            setState(() {
              _previewStep++;
              _isPaused = false;
            });
          }
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Preview error: ${e.toString()}')),
          );
          _stopPreview();
        }
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Preview continued')));
    } else {
      // Pause preview
      _previewTimer?.cancel();
      setState(() {
        _isPaused = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preview paused - You can manually change intensity'),
        ),
      );
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _previewTimer?.cancel();
    super.dispose();
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
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
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
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : !connectionManager.isConnected
              ? _buildNoConnectionBanner()
              : TabBarView(
                controller: _tabController,
                children:
                    _profileTypes.map((type) {
                      final profile = _profiles[type];
                      if (profile == null) {
                        return const Center(
                          child: Text('No profile data available'),
                        );
                      }

                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              '${type.substring(0, 1).toUpperCase()}${type.substring(1)} Profile',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Color selector
                            _buildColorSelector(),
                            const SizedBox(height: 16),

                            // Hourly intensity chart
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  children: [
                                    const Text(
                                      'Hourly Intensity Settings',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      'Tap or drag on chart to change intensity values',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.info_outline,
                                          size: 14,
                                          color: Colors.blue,
                                        ),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            'Make sure to select the color you want to edit first',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.blue[700],
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Only the selected color will be highlighted and editable',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[700],
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    // Tambahkan Container dengan tinggi tetap untuk mencegah layout shift
                                    SizedBox(
                                      height:
                                          320, // Tinggi tetap untuk grafik dan legenda
                                      child: Column(
                                        children: [
                                          Expanded(
                                            child: _buildHourlyIntensityChart(
                                              type,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          _buildChartLegend(),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Preview Button
                            ElevatedButton.icon(
                              icon: const Icon(Icons.play_arrow),
                              label: const Text('Preview Transition'),
                              onPressed: _startPreview,
                            ),
                            const SizedBox(height: 16),

                            // Current profile info
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Average Intensity Values',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Royal Blue: ${_formatToPercent(profile.royalBlue)}',
                                    ),
                                    Text(
                                      'Blue: ${_formatToPercent(profile.blue)}',
                                    ),
                                    Text('UV: ${_formatToPercent(profile.uv)}'),
                                    Text(
                                      'Violet: ${_formatToPercent(profile.violet)}',
                                    ),
                                    Text(
                                      'Red: ${_formatToPercent(profile.red)}',
                                    ),
                                    Text(
                                      'Green: ${_formatToPercent(profile.green)}',
                                    ),
                                    Text(
                                      'White: ${_formatToPercent(profile.white)}',
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            ElevatedButton.icon(
                              icon: const Icon(Icons.save),
                              label: const Text('Save Profile'),
                              onPressed: () => _saveProfile(type, profile),
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

  // Versi sederhana untuk no connection panel
  Widget _buildNoConnectionBanner() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          color: Colors.red.withOpacity(0.1),
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              const Icon(Icons.wifi_off, color: Colors.red),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Not connected to LED controller. Changes will be saved locally but not sent to device.',
                  style: TextStyle(color: Colors.red[700]),
                ),
              ),
            ],
          ),
        ),
        const Expanded(
          child: Center(child: Text('Connect to controller to edit profiles')),
        ),
      ],
    );
  }

  Widget _buildChartLegend() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        children:
            _colorOptions.map((color) {
              return SizedBox(
                width: 120,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _colorMap[color],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _getColorName(color),
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '(${color == _selectedColor ? 'active' : ''})',
                      style: TextStyle(
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                        color:
                            color == _selectedColor
                                ? Colors.blue
                                : Colors.transparent,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
      ),
    );
  }

  Widget _buildDebugInfo(Profile profile) {
    // Format data untuk nilai LED
    final Map<String, dynamic> ledValues = {
      "royalBlue": profile.royalBlue,
      "blue": profile.blue,
      "uv": profile.uv,
      "violet": profile.violet,
      "red": profile.red,
      "green": profile.green,
      "white": profile.white,
    };

    // Memastikan semua nilai adalah integer
    ledValues.forEach((key, value) {
      if (value is double) {
        ledValues[key] = value.round();
      }
    });

    // Membuat wrapper dengan format yang diminta
    final Map<String, dynamic> formattedValues = {"leds": ledValues};
    final jsonStr1 = json.encode(formattedValues);

    // Format alternatif tanpa wrapper
    final jsonStr2 = json.encode(ledValues);

    // Format LED individual
    const exampleLed = "royalBlue";
    final exampleValue = ledValues[exampleLed];
    final jsonStr3 = json.encode({"led": exampleLed, "value": exampleValue});

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.yellow, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Debug Data (Format yang Dicoba):',
            style: TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            '1. Format dengan wrapper:',
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          ),
          Text(
            jsonStr1,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'monospace',
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '2. Format tanpa wrapper:',
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          ),
          Text(
            jsonStr2,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'monospace',
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '3. Format LED individual (per metode controlLed):',
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          ),
          Text(
            jsonStr3,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'monospace',
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Endpoint: /api/manual/all (POST) dan /api/manual (POST)',
            style: TextStyle(color: Colors.grey, fontSize: 10),
          ),
        ],
      ),
    );
  }

  // Konversi nilai persentase (0-100) ke nilai intensitas (0-255)
  int _percentToIntensity(int percentValue) {
    return (percentValue * 2.55).round().clamp(0, 255);
  }

  // Konversi nilai intensitas (0-255) ke nilai persentase (0-100)
  int _intensityToPercent(int intensityValue) {
    return (intensityValue / 255 * 100).round().clamp(0, 100);
  }

  // Format nilai intensitas ke string persentase
  String _formatToPercent(int value) {
    return '${_intensityToPercent(value)}%';
  }
}
