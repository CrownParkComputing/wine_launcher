import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:wine_launcher/models/providers.dart';
import 'package:wine_launcher/services/logging_service.dart';
import 'package:wine_launcher/models/prefix_url.dart';
import 'package:wine_launcher/models/wine_prefix.dart';
import 'package:wine_launcher/models/wine_addon.dart';
import 'package:file_picker/file_picker.dart';

mixin WineColorMixin {
  Color _getTypeColor(bool isProton) {
    return isProton 
      ? const Color(0xFF2D1B36)  // Darker purple for Proton
      : const Color(0xFF1B2D36); // Darker blue for Wine
  }
}

class WineSetupPage extends StatefulWidget {
  const WineSetupPage({super.key});

  @override
  State<WineSetupPage> createState() => _WineSetupPageState();
}

class _WineSetupPageState extends State<WineSetupPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Map<String, double> _downloadProgress = {};
  final Map<String, String> _downloadStatus = {};
  final TextEditingController _prefixNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadExistingPrefixes();
  }

  Future<void> _loadExistingPrefixes() async {
    final settings = context.read<SettingsProvider>();
    final basePath = settings.defaultWinePrefixPath;
    if (basePath.isEmpty) {
      LoggingService().log('Base path is empty', level: LogLevel.warning);
      return;
    }

    // Let PrefixProvider handle loading
    Provider.of<PrefixProvider>(context, listen: false).loadPrefixes(context);
  }

  Future<void> _selectAndRunExe(WinePrefix prefix) async {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);

    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Select EXE to run',
        type: FileType.custom,
        allowedExtensions: ['exe'],
      );

      if (result != null) {
        final exePath = result.files.single.path!;
        await prefix.runExe(exePath);

        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(content: Text('Running $exePath')),
        );
      }
    } catch (e) {
    if (!mounted) return;
        messenger.showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
  }

  Future<void> _installAddon(BuildContext context, WinePrefix prefix, String url) async {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final settings = context.read<SettingsProvider>();
    
    try {
      final addon = settings.addons.firstWhere((a) => a.url == url);
      
      // Show confirmation dialog if already installed
      if (prefix.hasAddon(addon.type)) {
        final shouldUpdate = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Addon Already Installed'),
            content: Text('${addon.name} is already installed. Would you like to update it?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Update'),
              ),
            ],
          ),
        );
        
        if (shouldUpdate != true) return;
      }
      
      switch (addon.type) {
        case 'dxvk':
          await prefix.installDXVK();
          break;
        case 'vkd3d':
          await prefix.installVKD3D();
          break;
        case 'runtime':
          await prefix.installVisualCRuntime();
          break;
      }

      if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(
          content: Text('Successfully ${prefix.hasAddon(addon.type) ? 'updated' : 'installed'} ${addon.name}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
    if (!mounted) return;
      messenger.showSnackBar(
          SnackBar(
          content: Text('Error installing add-on: $e'),
            backgroundColor: Colors.red,
          ),
        );
    }
  }

  Future<void> _showAddAddonDialog(BuildContext context) async {
    final nameController = TextEditingController();
    final urlController = TextEditingController();
    String selectedType = 'dxvk';

    try {
      final result = await showDialog<Map<String, String>>(
      context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Add Wine Add-on'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'Enter add-on name',
                ),
              ),
              TextField(
                controller: urlController,
                decoration: const InputDecoration(
                  labelText: 'URL',
                  hintText: 'Enter download URL',
                ),
              ),
              DropdownButtonFormField<String>(
                value: selectedType,
                items: const [
                  DropdownMenuItem(value: 'dxvk', child: Text('DXVK')),
                  DropdownMenuItem(value: 'vkd3d', child: Text('VKD3D')),
                  DropdownMenuItem(value: 'runtime', child: Text('Visual C++ Runtime')),
                ],
                onChanged: (value) => selectedType = value!,
                decoration: const InputDecoration(labelText: 'Type'),
              ),
            ],
          ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
              onPressed: () {
                if (nameController.text.isNotEmpty && urlController.text.isNotEmpty) {
                  Navigator.pop(dialogContext, {
                    'name': nameController.text,
                    'url': urlController.text,
                    'type': selectedType,
                  });
                }
              },
              child: const Text('Add'),
          ),
        ],
      ),
    );

      if (result != null && mounted) {
        final settings = Provider.of<SettingsProvider>(context, listen: false);
        final addon = WineAddon(
          name: result['name']!,
          url: result['url']!,
          type: result['type']!,
        );
        settings.addAddon(addon);
      }
    } finally {
      nameController.dispose();
      urlController.dispose();
    }
  }

  Future<void> _showCreatePrefixDialog(BuildContext context, PrefixUrl source) async {
    bool is64Bit = true;
    final controller = TextEditingController();
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final prefixProvider = Provider.of<PrefixProvider>(context, listen: false);
    
    try {
      final result = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('Create New ${source.isProton ? "Proton" : "Wine"} Prefix'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
          children: [
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Prefix Name',
                  hintText: 'Enter a name for the new prefix',
                ),
              ),
              const SizedBox(height: 16),
              StatefulBuilder(
                builder: (context, setState) => SwitchListTile(
                  title: const Text('64-bit Architecture'),
                  subtitle: Text(is64Bit ? 'win64' : 'win32'),
                  value: is64Bit,
                  onChanged: (value) {
                    setState(() {
                      is64Bit = value;
                    });
                  },
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
          onPressed: () {
                if (controller.text.isNotEmpty) {
                  Navigator.pop(context, true);
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      );

      if (result == true && mounted) {
        final prefix = await WinePrefix.create(
          name: controller.text,
          basePath: settings.defaultWinePrefixPath,
          source: source,
          is64Bit: is64Bit,
          onProgress: (progress, status) {
            // You could add a progress indicator here if needed
          },
        );
        if (mounted) {
          prefixProvider.addPrefix(prefix);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Created prefix ${prefix.name}')),
          );
        }
      }
    } finally {
      controller.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final prefixProvider = context.watch<PrefixProvider>();
        final defaultPath = settings.defaultWinePrefixPath;
        final prefixes = prefixProvider.prefixes;

        if (defaultPath.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.folder_off, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  'Wine prefix path not set',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.settings),
                  label: const Text('Open Settings'),
                  onPressed: () {
                Navigator.pushNamed(context, '/settings');
                  },
                ),
              ],
            ),
          );
        }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wine Setup'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Installed Prefixes'),
            Tab(text: 'Prefix Sources'),
            Tab(text: 'Add-ons'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _InstalledPrefixesTab(
            prefixes: prefixes,
            settings: settings,
            onRunExe: _selectAndRunExe,
            onInstallAddon: _installAddon,
            onCreatePrefix: _showCreatePrefixDialog,
          ),
          _PrefixSourcesTab(
            prefixUrls: settings.prefixUrls,
            onCreatePrefix: (source) => _showCreatePrefixDialog(context, source),
            downloadProgress: _downloadProgress,
            downloadStatus: _downloadStatus,
          ),
          _AddonsTab(
            addons: settings.addons,
            onAddAddon: (addon) => settings.addAddon(addon),
            onRemoveAddon: (addon) => settings.removeAddon(addon),
            onShowAddDialog: _showAddAddonDialog,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _prefixNameController.dispose();
    _tabController.dispose();
    super.dispose();
  }
}

// Create new widget for Installed Prefixes tab
class _InstalledPrefixesTab extends StatefulWidget {
  final List<WinePrefix> prefixes;
  final SettingsProvider settings;
  final Function(WinePrefix) onRunExe;
  final Function(BuildContext, WinePrefix, String) onInstallAddon;
  final Function(BuildContext, PrefixUrl) onCreatePrefix;

  const _InstalledPrefixesTab({
    required this.prefixes,
    required this.settings,
    required this.onRunExe,
    required this.onInstallAddon,
    required this.onCreatePrefix,
  });

  @override
  State<_InstalledPrefixesTab> createState() => _InstalledPrefixesTabState();
}

class _InstalledPrefixesTabState extends State<_InstalledPrefixesTab> with WineColorMixin {
  @override
  Widget build(BuildContext context) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                    Row(
                      children: [
                        const Icon(Icons.wine_bar, color: Colors.purple),
                        const SizedBox(width: 8),
                    Text(
                          'Installed Prefixes',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.purple,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    PopupMenuButton<PrefixUrl>(
                      icon: const Icon(Icons.add_circle, color: Colors.purple),
                      tooltip: 'Create New Prefix',
                      itemBuilder: (context) => widget.settings.prefixUrls.map((source) => 
                        PopupMenuItem(
                          value: source,
                          child: ListTile(
                            leading: Icon(
                              source.isProton ? Icons.sports_esports : Icons.wine_bar,
                              color: _getTypeColor(source.isProton),
                            ),
                            title: Text(source.name),
                            subtitle: Text('From: ${source.url}'),
                          ),
                        ),
                      ).toList(),
                      onSelected: (source) => widget.onCreatePrefix(context, source),
                                  ),
                                ],
                              ),
                const SizedBox(height: 16),
                ...widget.prefixes.map((prefix) => _buildPrefixCard(context, prefix)),
                if (widget.prefixes.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            children: [
                          Icon(Icons.folder_off, size: 48, color: Colors.grey),
                              SizedBox(height: 8),
                              Text(
                            'No prefixes installed',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
      ],
    );
  }

  Widget _buildPrefixCard(BuildContext context, WinePrefix prefix) {
    return Card(
      color: _getTypeColor(prefix.isProton),
                child: Column(
                  children: [
          ListTile(
            leading: Icon(
              prefix.isProton ? Icons.sports_esports : Icons.wine_bar,
              color: Colors.white,
            ),
                        title: Text(
                          prefix.name,
              style: const TextStyle(
                color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
            subtitle: Text(
              '${prefix.isProton ? "Proton" : "Wine"} ${prefix.is64Bit ? "64-bit" : "32-bit"}',
              style: const TextStyle(
                color: Colors.white70,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _showDeletePrefixDialog(context, prefix),
                  tooltip: 'Delete Prefix',
                ),
                PopupMenuButton<String>(
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'winecfg',
                      child: Text('Wine Configuration'),
                    ),
                    const PopupMenuItem(
                      value: 'regedit',
                      child: Text('Registry Editor'),
                    ),
                    const PopupMenuItem(
                      value: 'winetricks',
                      child: Text('Winetricks'),
                    ),
                    const PopupMenuItem(
                      value: 'gamecontrollers',
                      child: Text('Game Controllers'),
                    ),
                  ],
                  onSelected: (value) async {
                    switch (value) {
                      case 'winecfg':
                        await prefix.runWinecfg();
                        break;
                      case 'regedit':
                        await prefix.runRegedit();
                        break;
                      case 'winetricks':
                        await prefix.runWinetricks();
                        break;
                      case 'gamecontrollers':
                        await prefix.runJoyConfig();
                        break;
                    }
                  },
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.extension, color: Colors.white),
                  tooltip: 'Add-ons',
                  itemBuilder: (context) => [
                    ...widget.settings.addons.map((addon) => PopupMenuItem(
                      value: addon.url,
                      child: Text(addon.name),
                    )),
                  ],
                  onSelected: (url) => widget.onInstallAddon(context, prefix, url),
                ),
                                    ElevatedButton.icon(
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Run'),
                                      style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                                        foregroundColor: Colors.white,
                                      ),
                  onPressed: () => widget.onRunExe(prefix),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDeletePrefixDialog(BuildContext context, WinePrefix prefix) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Prefix'),
        content: Text('Are you sure you want to delete the prefix "${prefix.name}"?\nThis cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final prefixProvider = Provider.of<PrefixProvider>(dialogContext, listen: false);
              Navigator.pop(dialogContext); // Close dialog before async operation
              prefixProvider.removePrefix(prefix);
              try {
                await Directory(prefix.path).delete(recursive: true);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Prefix deleted successfully')),
                );
              } catch (e) {
                LoggingService().log(
                  'Error deleting prefix directory: $e',
                  level: LogLevel.error,
                );
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error deleting prefix: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// Create new widget for Prefix Sources tab
class _PrefixSourcesTab extends StatelessWidget with WineColorMixin {
  final List<PrefixUrl> prefixUrls;
  final Function(PrefixUrl) onCreatePrefix;
  final Map<String, double> downloadProgress;
  final Map<String, String> downloadStatus;

  const _PrefixSourcesTab({
    required this.prefixUrls,
    required this.onCreatePrefix,
    required this.downloadProgress,
    required this.downloadStatus,
  });

  void _showAddSourceDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        final urlController = TextEditingController();
        bool isProton = false;

        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Add Wine/Proton Source'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: urlController,
                  decoration: const InputDecoration(
                    labelText: 'URL',
                    hintText: 'Enter download URL',
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Is Proton'),
                  value: isProton,
                  onChanged: (value) {
                    setState(() {
                      isProton = value;
                    });
                  },
                                    ),
                                  ],
                                ),
            actions: [
              TextButton(
                onPressed: () {
                  urlController.dispose();
                  Navigator.pop(context);
                },
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  if (urlController.text.isNotEmpty) {
                    final settings = context.read<SettingsProvider>();
                    settings.addPrefixUrl(urlController.text, isProton);
                    urlController.dispose();
                    Navigator.pop(context);
                  }
                },
                child: const Text('Add'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSourceCard(BuildContext context, PrefixUrl source) {
    return Card(
      color: _getTypeColor(source.isProton),
      child: ListTile(
        leading: Icon(
          source.isProton ? Icons.sports_esports : Icons.wine_bar,
          color: Colors.white,
        ),
        title: Text(
          source.name,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          source.url,
          style: const TextStyle(color: Colors.white70),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
                                            children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.white),
              onPressed: () => _showEditSourceDialog(context, source),
              tooltip: 'Edit Source',
            ),
                                              IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () {
                final settings = context.read<SettingsProvider>();
                final index = settings.prefixUrls.indexOf(source);
                settings.removePrefixUrl(index);
              },
                                              ),
                                            ],
                                          ),
      ),
    );
  }

  void _showEditSourceDialog(BuildContext context, PrefixUrl source) {
    final urlController = TextEditingController(text: source.url);
    bool isProton = source.isProton;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Source'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: urlController,
                decoration: const InputDecoration(
                  labelText: 'URL',
                  hintText: 'Enter download URL',
                ),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Is Proton'),
                value: isProton,
                onChanged: (value) {
                  setState(() {
                    isProton = value;
                  });
                },
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
                if (urlController.text.isNotEmpty) {
                  final settings = context.read<SettingsProvider>();
                  final index = settings.prefixUrls.indexOf(source);
                  settings.updatePrefixUrl(index, urlController.text, isProton);
                  Navigator.pop(context);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
                                            children: [
        Card(
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.source, color: Colors.blue),
                                              const SizedBox(width: 8),
                                              Text(
                          'Available Prefix Sources',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                          ),
                                              ),
                                            ],
                                          ),
                    IconButton(
                      icon: const Icon(Icons.add_circle),
                      color: Colors.blue,
                      onPressed: () => _showAddSourceDialog(context),
                      tooltip: 'Add New Source',
                                        ),
                                    ],
                                  ),
                const SizedBox(height: 16),
                ...prefixUrls.map((source) => _buildSourceCard(context, source)),
                              ],
                            ),
                          ),
        ),
      ],
    );
  }
}

// Create new widget for Add-ons tab
class _AddonsTab extends StatelessWidget {
  final List<WineAddon> addons;
  final Function(WineAddon) onAddAddon;
  final Function(WineAddon) onRemoveAddon;
  final Function(BuildContext) onShowAddDialog;

  const _AddonsTab({
    required this.addons,
    required this.onAddAddon,
    required this.onRemoveAddon,
    required this.onShowAddDialog,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 4,
                        child: Padding(
            padding: const EdgeInsets.all(16),
                          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.extension, color: Colors.green),
                        const SizedBox(width: 8),
                              Text(
                          'Wine Add-ons',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                              ),
                            ],
                          ),
                    IconButton(
                      icon: const Icon(Icons.add_circle),
                      color: Colors.green,
                      onPressed: () => onShowAddDialog(context),
                      tooltip: 'Add New Add-on',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...addons.map((addon) => Card(
                  color: Colors.grey.shade800,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.extension, color: Colors.white),
                    title: Text(
                      addon.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      addon.url,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => onRemoveAddon(addon),
                          tooltip: 'Delete Add-on',
                        ),
                      ],
                    ),
                  ),
                )),
                  ],
                ),
              ),
            ),
          ],
    );
  }
} 