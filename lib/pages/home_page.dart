import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wine_launcher/pages/welcome_page.dart';
import 'package:wine_launcher/pages/game_launcher_page.dart';
import 'package:wine_launcher/pages/wine_setup_page.dart';
import 'package:wine_launcher/pages/settings_page.dart';
import 'package:wine_launcher/pages/logs_page.dart';
import 'package:wine_launcher/models/providers.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Load prefixes when app starts
      Provider.of<PrefixProvider>(context, listen: false).loadPrefixes(context);
    });
  }

  final List<Widget> _pages = const [
    WelcomePage(),
    GameLauncherPage(),
    WineSetupPage(),
    SettingsPage(),
    LogsPage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home),
            label: 'Welcome',
          ),
          NavigationDestination(
            icon: Icon(Icons.games),
            label: 'Games',
          ),
          NavigationDestination(
            icon: Icon(Icons.wine_bar),
            label: 'Wine',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
          NavigationDestination(
            icon: Icon(Icons.article),
            label: 'Logs',
          ),
        ],
      ),
    );
  }
} 