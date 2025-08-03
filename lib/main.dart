import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/aquarium_api_service.dart';
import 'services/connection_manager.dart';
import 'services/profile_cache.dart';
import 'screens/dashboard_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/profile_screen.dart';
import 'config/app_config.dart';

void main() {
  // Print configuration saat aplikasi dimulai
  AppConfig.printConfig();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AquariumApiService>(
          create: (_) => AquariumApiService(baseUrl: AppConfig.defaultBaseUrl),
          dispose: (_, service) => service.client.close(),
        ),
        ChangeNotifierProxyProvider<AquariumApiService, ConnectionManager>(
          create:
              (context) => ConnectionManager(
                Provider.of<AquariumApiService>(context, listen: false),
              ),
          update:
              (context, apiService, previous) =>
                  previous ?? ConnectionManager(apiService),
        ),
      ],
      child: MaterialApp(
        title: 'Aquarium LED Controller',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
          brightness: Brightness.light,
        ),
        darkTheme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
          brightness: Brightness.dark,
        ),
        themeMode: ThemeMode.system,
        initialRoute: '/',
        routes: {
          '/':
              (context) => FutureBuilder<String?>(
                future: ProfileCache.getDeviceIp(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Scaffold(
                      body: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final savedIp = snapshot.data;
                  if (savedIp != null) {
                    // Update the connection manager with the saved IP
                    final connectionManager = Provider.of<ConnectionManager>(
                      context,
                      listen: false,
                    );
                    connectionManager.setIpAddress(savedIp);
                  }

                  return const DashboardScreen();
                },
              ),
          '/settings': (context) => const SettingsScreen(),
          '/profiles': (context) => const ProfileScreen(),
        },
      ),
    );
  }
}
