import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wine_launcher/models/providers.dart';
import 'package:wine_launcher/models/prefix_url.dart';
import 'package:file_picker/file_picker.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 0,
          bottom: const TabBar(
            tabs: [
              Tab(
                icon: Icon(Icons.folder),
                text: 'Paths',
              ),
              Tab(
                icon: Icon(Icons.source),
                text: 'Sources',
              ),
              Tab(
                icon: Icon(Icons.settings),
                text: 'Appearance',
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Paths Tab
            _PathsTab(),
            
            // Sources Tab
            _SourcesTab(),
            
            // Appearance Tab
            _AppearanceTab(),
          ],
        ),
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

class _SourcesTab extends StatefulWidget {
  @override
  State<_SourcesTab> createState() => _SourcesTabState();
}

class _SourcesTabState extends State<_SourcesTab> {
  final _urlController = TextEditingController();
  final _dxvkAsyncUrlController = TextEditingController();
  final _vkd3dUrlController = TextEditingController();
  bool _isProton = false;

  @override
  void dispose() {
    _urlController.dispose();
    _dxvkAsyncUrlController.dispose();
    _vkd3dUrlController.dispose();
    super.dispose();
  }

  void _showAddSourceDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Source'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'URL',
                hintText: 'Enter Wine/Proton download URL',
              ),
            ),
            const SizedBox(height: 16),
            StatefulBuilder(
              builder: (context, setState) => SwitchListTile(
                title: const Text('Is Proton?'),
                value: _isProton,
                onChanged: (value) {
                  setState(() {
                    _isProton = value;
                  });
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (_urlController.text.isNotEmpty) {
                final settings = context.read<SettingsProvider>();
                settings.addPrefixUrl(
                  PrefixUrl(
                    url: _urlController.text,
                    isProton: _isProton,
                    title: _urlController.text.split('/').last,
                  ),
                );
                _urlController.clear();
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditDXVKDialog(BuildContext context) {
    final settings = context.read<SettingsProvider>();
    _dxvkAsyncUrlController.text = settings.dxvkAsyncUrl;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit DXVK-Async Source'),
        content: TextField(
          controller: _dxvkAsyncUrlController,
          decoration: const InputDecoration(
            labelText: 'URL',
            hintText: 'Enter DXVK-Async download URL',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (_dxvkAsyncUrlController.text.isNotEmpty) {
                settings.dxvkAsyncUrl = _dxvkAsyncUrlController.text;
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showEditVKD3DDialog(BuildContext context) {
    final settings = context.read<SettingsProvider>();
    _vkd3dUrlController.text = settings.vkd3dUrl;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit VKD3D Source'),
        content: TextField(
          controller: _vkd3dUrlController,
          decoration: const InputDecoration(
            labelText: 'URL',
            hintText: 'Enter VKD3D download URL',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (_vkd3dUrlController.text.isNotEmpty) {
                settings.vkd3dUrl = _vkd3dUrlController.text;
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Wine/Proton Sources',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () => _showAddSourceDialog(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...settings.prefixUrls.asMap().entries.map(
                    (entry) => ListTile(
                      leading: Icon(
                        entry.value.isProton 
                          ? Icons.sports_esports 
                          : Icons.wine_bar,
                      ),
                      title: Text(entry.value.url),
                      subtitle: Text(entry.value.isProton ? 'Proton' : 'Wine'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => settings.removePrefixUrl(entry.key),
                      ),
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
                    'DXVK-Async Source',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    title: Text(settings.dxvkAsyncUrl),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _showEditDXVKDialog(context),
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
                    'VKD3D Source',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    title: Text(settings.vkd3dUrl),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _showEditVKD3DDialog(context),
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
        ],
      ),
    );
  }
} 