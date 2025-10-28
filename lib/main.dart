import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/aquarium_api_service.dart';
import 'services/connection_manager.dart';
import 'screens/main_navigation_screen.dart';
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
        themeMode: ThemeMode.dark,
        initialRoute: '/',
        routes: {'/': (context) => const MainNavigationScreen()},
      ),
    );
  }
}
