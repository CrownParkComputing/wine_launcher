import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wine_launcher/models/providers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:wine_launcher/version.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Paths'),
            Tab(text: 'Appearance'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _PathsTab(),
          _AppearanceTab(),
        ],
      ),
    );
  }
}

class _PathsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, _) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Games Location',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    title: Text(settings.gamesPath.isEmpty 
                      ? 'Not set' 
                      : settings.gamesPath),
                    trailing: IconButton(
                      icon: const Icon(Icons.folder_open),
                      onPressed: () async {
                        final path = await FilePicker.platform.getDirectoryPath(
                          dialogTitle: 'Select Games Directory',
                        );
                        if (path != null && context.mounted) {
                          settings.gamesPath = path;
                          // Scan for games after path change
                          Provider.of<GameProvider>(context, listen: false)
                            .scanGamesFolder(context);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Wine Prefix Location',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    title: Text(settings.defaultWinePrefixPath.isEmpty 
                      ? 'Not set' 
                      : settings.defaultWinePrefixPath),
                    trailing: IconButton(
                      icon: const Icon(Icons.folder_open),
                      onPressed: () async {
                        final path = await FilePicker.platform.getDirectoryPath(
                          dialogTitle: 'Select Wine Prefix Directory',
                        );
                        if (path != null) {
                          settings.defaultWinePrefixPath = path;
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Visual C++ Runtime',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    title: Text(settings.vcRedistPath.isEmpty 
                      ? 'Not set' 
                      : settings.vcRedistPath),
                    trailing: IconButton(
                      icon: const Icon(Icons.file_open),
                      onPressed: () async {
                        final result = await FilePicker.platform.pickFiles(
                          dialogTitle: 'Select VC++ Runtime Installer',
                          type: FileType.custom,
                          allowedExtensions: ['exe'],
                        );
                        if (result != null) {
                          settings.vcRedistPath = result.files.single.path!;
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AppearanceTab extends StatelessWidget {
  Future<void> _syncVersion(BuildContext context) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Checking latest version...'),
            ],
          ),
        ),
      );

      // Get latest version from GitHub releases
      final response = await http.get(Uri.parse(
        'https://api.github.com/repos/yourusername/wine-launcher/releases/latest'
      ));

      if (context.mounted) {
        Navigator.pop(context); // Close progress dialog

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final latestVersion = data['tag_name'].toString().replaceAll('v', '');
          const currentVersion = appVersion;

          if (latestVersion != currentVersion) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Version Mismatch'),
                content: Text(
                  'Current version: $currentVersion\n'
                  'Latest version: $latestVersion\n\n'
                  'Would you like to update?'
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Later'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      launchUrl(Uri.parse(data['html_url']));
                    },
                    child: const Text('Update'),
                  ),
                ],
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('You are on the latest version')),
            );
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close progress dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error checking version: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Theme',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: const Text('Dark Mode'),
                    value: themeProvider.isDarkMode,
                    onChanged: (_) => themeProvider.toggleTheme(),
                  ),
                ],
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Version',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    title: const Text('Check for Updates'),
                    subtitle: const Text('Current Version: 1.5'),
                    trailing: IconButton(
                      icon: const Icon(Icons.sync),
                      onPressed: () => _syncVersion(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrefixSelectionDialog extends StatefulWidget {
  final List<String> prefixes;

  const _PrefixSelectionDialog({required this.prefixes});

  @override
  State<_PrefixSelectionDialog> createState() => _PrefixSelectionDialogState();
}

class _PrefixSelectionDialogState extends State<_PrefixSelectionDialog> {
  final Set<String> _selectedPrefixes = {};

  String _getPrefixDisplayName(String path) {
    // Extract game name from path
    final parts = path.split('/');
    if (parts.length >= 2 && parts.last == 'prefix') {
      // Return the parent directory name (game name)
      return parts[parts.length - 2];
    }
    return path.split('/').last;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Wine Prefixes'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Select prefixes to apply the controller fix:'),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.prefixes.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return CheckboxListTile(
                      title: const Text('Select All'),
                      value: _selectedPrefixes.length == widget.prefixes.length,
                      onChanged: (bool? value) {
                        setState(() {
                          if (value == true) {
                            _selectedPrefixes.addAll(widget.prefixes);
                          } else {
                            _selectedPrefixes.clear();
                          }
                        });
                      },
                    );
                  }
                  final prefix = widget.prefixes[index - 1];
                  return CheckboxListTile(
                    title: Text(_getPrefixDisplayName(prefix)),
                    subtitle: Text(prefix),
                    value: _selectedPrefixes.contains(prefix),
                    onChanged: (bool? value) {
                      setState(() {
                        if (value == true) {
                          _selectedPrefixes.add(prefix);
                        } else {
                          _selectedPrefixes.remove(prefix);
                        }
                      });
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _selectedPrefixes.isEmpty
              ? null
              : () => Navigator.pop(context, _selectedPrefixes),
          child: const Text('Apply'),
        ),
      ],
    );
  }
} 