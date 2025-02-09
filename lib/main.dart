import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'package:provider/provider.dart';
import 'package:wine_launcher/models/providers.dart';
import 'package:wine_launcher/pages/home_page.dart';
import 'package:wine_launcher/services/logging_service.dart';
import 'package:wine_launcher/pages/settings_page.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Ensure we're running on Linux
  if (!Platform.isLinux) {
    LoggingService().log(
      'This application only runs on Linux',
      level: LogLevel.error,
    );
    return;
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => SettingsProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => GameProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => PrefixProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => LoggingService(),
        ),
      ],
      child: const WineLauncherApp(),
    ),
  );
}

class WineLauncherApp extends StatelessWidget {
  const WineLauncherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          title: 'Wine Launcher',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
            useMaterial3: true,
          ),
          darkTheme: ThemeData.dark(useMaterial3: true),
          themeMode: themeProvider.themeMode,
          home: const HomePage(),
        );
      },
    );
  }
}
