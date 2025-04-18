# SLAB Aquarium LED Controller

A Flutter application for controlling IoT-based aquarium lighting systems. SLAB (Smart LED Aquarium Ballast) allows users to manage aquarium lighting profiles and schedules from their mobile devices.

## Features

- Detailed LED control for 7 channels (Royal Blue, Blue, UV, Violet, Red, Green, White)
- Time-based profiles (morning, midday, evening, night)
- Automatic scheduling with smooth transitions
- Manual mode for direct control
- Real-time connection monitoring
- Diagnostic tools and status information

## System Requirements

- Flutter 3.0.0 or higher
- Android 5.0+ or iOS 12.0+
- WiFi connectivity
- Compatible with SLAB IoT Controller ([GitHub Repository](https://github.com/albifhrzq/SLABIoTController))

## Getting Started

1. Ensure the SLAB controller is connected to Wi-Fi and powered on
2. Install the app on your Android or iOS device
3. Open the app and enter the controller's IP address in the settings page
4. The app will automatically connect and display current lighting status

## Development

This project is developed using Flutter and follows the Provider architecture for state management.

### Project Structure

```
lib/
├── main.dart                    # Application entry point
├── models/                      # Data models
│   ├── profile.dart             # Lighting profile model
│   └── time_ranges.dart         # Time ranges model
├── screens/                     # UI screens
│   ├── dashboard_screen.dart    # Main view and manual control
│   ├── profile_screen.dart      # Lighting profile editor
│   └── settings_screen.dart     # Settings and diagnostics
├── services/                    # Business logic
│   ├── aquarium_api_service.dart # Controller communication
│   ├── connection_manager.dart   # Connection and retry management
│   ├── profile_cache.dart        # Local storage
│   └── manual_settings_cache.dart # Manual settings cache
└── widgets/                     # Reusable UI components
    └── app_logo.dart            # App logo widget
```

### Building from Source

1. Clone the repository
```bash
git clone https://github.com/albifhrzq/slab-app.git
cd slab-app
```

2. Get dependencies
```bash
flutter pub get
```

3. Run the application
```bash
flutter run
```

## Troubleshooting

- **Cannot connect to controller**: Ensure mobile device and controller are on the same Wi-Fi network, and the IP address is correct
- **Lighting not changing**: Check connection status in the app and ensure manual mode is not active
- **App crashes**: Clear app cache and ensure latest Flutter version is installed

## License

Licensed under MIT License - see LICENSE file for full details.

## Contact

For questions or support, contact us at: support@slab-aquarium.com
