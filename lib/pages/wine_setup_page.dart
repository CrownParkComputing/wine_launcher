import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:wine_launcher/models/providers.dart';
import 'package:wine_launcher/services/logging_service.dart';
import 'package:wine_launcher/models/prefix_url.dart';
import 'package:wine_launcher/models/wine_prefix.dart';
import 'package:http/http.dart' as http;

class WineSetupPage extends StatefulWidget {
  const WineSetupPage({super.key});

  @override
  State<WineSetupPage> createState() => _WineSetupPageState();
}

class _WineSetupPageState extends State<WineSetupPage> {
  final Map<String, double> _downloadProgress = {};
  final Map<String, String> _downloadStatus = {};
  final TextEditingController _prefixNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
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

  void _showCreatePrefixDialog(BuildContext context, PrefixUrl source) {
    bool is64Bit = true;  // Default to 64-bit

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Prefix'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _prefixNameController,
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
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (_prefixNameController.text.isNotEmpty) {
                _createPrefix(source, _prefixNameController.text, is64Bit);
                Navigator.pop(context);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<bool> _verifyDownload(String filePath, int expectedSize) async {
    final file = File(filePath);
    if (!await file.exists()) return false;
    
    final size = await file.length();
    if (size != expectedSize) {
      LoggingService().log(
        'File size mismatch: expected $expectedSize bytes, got $size bytes',
        level: LogLevel.error,
      );
      return false;
    }
    
    return true;
  }

  Future<void> _createPrefix(PrefixUrl source, String prefixName, bool is64Bit) async {
    if (!mounted) return;

    // Store context references before async operations
    final settings = context.read<SettingsProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final basePath = settings.defaultWinePrefixPath;

    if (basePath.isEmpty) {
      LoggingService().log('Base path is empty', level: LogLevel.error);
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('No installation path set'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    _showSnackBar('Starting prefix creation: $prefixName');

    final prefixType = source.isProton ? 'proton' : 'wine';
    final fileName = source.url.split('/').last;
    final downloadDir = Directory(p.join(basePath, 'downloads'));
    final downloadPath = p.join(downloadDir.path, fileName);
    final extractDir = p.join(basePath, prefixType, 'base');

    LoggingService().log(
      'Starting prefix creation:\n'
      'Type: $prefixType\n'
      'Name: $prefixName\n'
      'URL: ${source.url}\n'
      'Download path: $downloadPath\n'
      'Extract dir: $extractDir',
      level: LogLevel.info,
    );

    if (mounted) {
      setState(() {
        _downloadStatus[prefixName] = 'Starting setup...';
        _downloadProgress[prefixName] = 0.0;
      });
    }

    try {
      // Create directories
      LoggingService().log('Creating required directories...', level: LogLevel.info);
      await downloadDir.create(recursive: true);
      await Directory(extractDir).create(recursive: true);

      // Check if we already have the download
      if (await File(downloadPath).exists()) {
        _showSnackBar('Found existing download, verifying...');
        
        final response = await http.head(Uri.parse(source.url));
        final expectedSize = int.parse(response.headers['content-length'] ?? '0');
        
        if (await _verifyDownload(downloadPath, expectedSize)) {
          _showSnackBar('Using existing download');
          if (mounted) {
            setState(() {
              _downloadStatus[prefixName] = 'Using existing download...';
              _downloadProgress[prefixName] = 0.4;
            });
          }
        } else {
          _showSnackBar('Existing download is corrupt, re-downloading...', isError: true);
          await File(downloadPath).delete();
        }
      }

      if (!await File(downloadPath).exists()) {
        _showSnackBar('Starting download...');
        // Download section
        final response = await http.Client().send(
          http.Request('GET', Uri.parse(source.url))
            ..headers['Accept'] = '*/*',
        );

        LoggingService().log(
          'Download response: ${response.statusCode} - ${response.headers}',
          level: LogLevel.info,
      );

      if (response.statusCode != 200) {
          throw Exception('Failed to download: HTTP ${response.statusCode}');
        }

        final contentLength = response.contentLength ?? 0;
        if (contentLength == 0) {
          throw Exception('Invalid content length from server');
        }

        LoggingService().log(
          'Download size: ${(contentLength / 1024 / 1024).toStringAsFixed(2)} MB',
          level: LogLevel.info,
        );

        final file = File(downloadPath);
        final sink = file.openWrite();
        int received = 0;

        try {
          await for (final chunk in response.stream) {
            sink.add(chunk);
            received += chunk.length;
            if (mounted) {
              setState(() {
                _downloadProgress[prefixName] = contentLength > 0 ? received / contentLength : 0;
                _downloadStatus[prefixName] = 'Downloading: ${(received / 1024 / 1024).toStringAsFixed(2)}MB / ${(contentLength / 1024 / 1024).toStringAsFixed(2)}MB';
              });
            }
            if (received % (5 * 1024 * 1024) == 0) {
              LoggingService().log(
                'Downloaded: ${(received / 1024 / 1024).toStringAsFixed(2)}MB / ${(contentLength / 1024 / 1024).toStringAsFixed(2)}MB',
                level: LogLevel.info,
              );
            }
          }

          await sink.close();
          
          if (!await _verifyDownload(downloadPath, contentLength)) {
            _showSnackBar('Download verification failed', isError: true);
            throw Exception('Download verification failed');
          }
          
          _showSnackBar('Download completed successfully');
        } catch (e) {
          await sink.close();
          if (await file.exists()) {
            await file.delete();
          }
          throw Exception('Download failed: $e');
        }
      }

      // Test archive
      _showSnackBar('Testing archive integrity...');
      final testCommand = fileName.endsWith('.tar.gz') || fileName.endsWith('.tgz')
          ? ['tar', '-tzf', downloadPath]
          : fileName.endsWith('.tar.xz')
              ? ['tar', '-tJf', downloadPath]
              : fileName.endsWith('.zip')
                  ? ['unzip', '-t', downloadPath]
                  : throw Exception('Unsupported archive format: $fileName');

      final testResult = await Process.run(testCommand[0], testCommand.sublist(1));
      if (testResult.exitCode != 0) {
        LoggingService().log(
          'Archive test failed:\n${testResult.stderr}',
          level: LogLevel.error,
        );
        await File(downloadPath).delete();
        throw Exception('Archive is corrupt, please try again');
      }

      // Extract
      _showSnackBar('Extracting files...');
      final extractCommand = fileName.endsWith('.tar.gz') || fileName.endsWith('.tgz')
          ? ['tar', '-xzf', downloadPath, '-C', extractDir]
          : fileName.endsWith('.tar.xz')
              ? ['tar', '-xJf', downloadPath, '-C', extractDir]
              : fileName.endsWith('.zip')
                  ? ['unzip', downloadPath, '-d', extractDir]
                  : throw Exception('Unsupported archive format: $fileName');

      LoggingService().log(
        'Running extraction command: ${extractCommand.join(" ")}',
        level: LogLevel.info,
      );

      final extractResult = await Process.run(
        extractCommand[0],
        extractCommand.sublist(1),
        workingDirectory: extractDir,
        runInShell: true,
      );

      if (extractResult.exitCode != 0) {
        _showSnackBar('Extraction failed', isError: true);
        throw Exception('Failed to extract archive');
      }

      _showSnackBar('Files extracted successfully');

      // After extraction, find the actual wine/proton directory
      if (mounted) {
        setState(() {
          _downloadStatus[prefixName] = 'Locating binaries...';
          _downloadProgress[prefixName] = 0.6;
        });
      }

      // Find the wine binary in the extracted files
      final binPath = await _findWineBinary(extractDir, source);
      if (binPath == null) {
        throw Exception('Could not find wine binary in extracted package');
      }

      LoggingService().log(
        'Found wine binary at: $binPath',
        level: LogLevel.info,
      );

      // Create the actual prefix directory
      final prefixPath = p.join(basePath, prefixType, prefixName);
      await Directory(prefixPath).create(recursive: true);

      // Initialize the prefix with the downloaded Wine/Proton
      final env = {
        'WINEPREFIX': prefixPath,
        'WINEARCH': is64Bit ? 'win64' : 'win32',
        'PATH': '${p.dirname(binPath)}:${Platform.environment['PATH']}',
      };

      if (mounted) {
        setState(() {
          _downloadStatus[prefixName] = 'Initializing prefix...';
          _downloadProgress[prefixName] = 0.8;
        });
      }

      final result = await Process.run('wineboot', ['-i'], environment: env);
      if (result.exitCode != 0) {
        _showSnackBar('Failed to initialize prefix', isError: true);
        throw Exception('Failed to initialize prefix: ${result.stderr}');
      }

      if (mounted) {
        setState(() {
          _downloadStatus[prefixName] = 'Setup complete';
          _downloadProgress[prefixName] = 1.0;
        });
      }

      _showSnackBar('Successfully created prefix: $prefixName');

      // Clean up
      await File(downloadPath).delete();
      _showSnackBar('Cleaned up temporary files');

      // Add the prefix to PrefixProvider
      // ignore: use_build_context_synchronously
      context.read<PrefixProvider>().addPrefix(WinePrefix(
        // ignore: use_build_context_synchronously
        context: context,
        name: prefixName,
        path: prefixPath,
        isProton: source.isProton,
        sourceUrl: source.url,
        is64Bit: is64Bit,
        onStatusUpdate: _showSnackBar,
      ));

    } catch (e) {
      LoggingService().log('Error creating prefix: $e', level: LogLevel.error);
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Error creating prefix: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<String?> _findWineBinary(String baseDir, PrefixUrl source) async {
    final wineBinaryNames = source.isProton ? ['proton', 'wine64', 'wine'] : ['wine64', 'wine'];
    
    LoggingService().log(
      'Searching for binaries in: $baseDir',
      level: LogLevel.info,
    );

    try {
      // First try to find in bin directory
      final binDir = Directory(p.join(baseDir, 'bin'));
      if (await binDir.exists()) {
        for (final binary in wineBinaryNames) {
          final binaryPath = p.join(binDir.path, binary);
          if (await File(binaryPath).exists()) {
            return binaryPath;
          }
        }
      }

      // Then try recursive search
      for (final binary in wineBinaryNames) {
        final result = await Process.run('find', [
          baseDir,
          '-name',
          binary,
          '-type',
          'f',
          '-executable'
        ]);

        final paths = result.stdout.toString().trim().split('\n');
        for (final path in paths) {
          if (path.isNotEmpty && await File(path).exists()) {
            return path;
          }
        }
      }

      // Log all files in extraction directory for debugging
      final result = await Process.run('find', [baseDir, '-type', 'f']);
      LoggingService().log(
        'Files in extraction directory:\n${result.stdout}',
        level: LogLevel.info,
      );

    } catch (e) {
      LoggingService().log('Error finding wine binary: $e', level: LogLevel.error);
    }
    return null;
  }

  Future<void> _selectAndRunExe(WinePrefix prefix) async {
    if (!mounted) return;

    try {
      final process = await Process.run('zenity', [
        '--file-selection',
        '--title=Select EXE file',
        '--file-filter=*.exe',
      ]);

      if (!mounted) return;  // Check mounted after async gap

      if (process.exitCode == 0 && process.stdout.toString().trim().isNotEmpty) {
        final exePath = process.stdout.toString().trim();
        LoggingService().log('Selected EXE: $exePath', level: LogLevel.info);
        
        if (mounted) {  // Check mounted before running exe
          await prefix.runExe(exePath);
        }
      }
    } catch (e) {
      LoggingService().log('Error selecting EXE: $e', level: LogLevel.error);
      
      if (mounted) {  // Check mounted before showing error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting EXE: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Color _getTypeColor(bool isProton) {
    return isProton ? Colors.purple.shade50 : Colors.blue.shade50;
  }

  Color _getTypeTextColor(bool isProton) {
    return isProton ? Colors.purple.shade900 : Colors.blue.shade900;
  }

  Color _getTypeButtonColor(bool isProton) {
    return isProton ? Colors.purple.shade700 : Colors.blue.shade700;
  }

  Icon _getTypeIcon(bool isProton) {
    return Icon(
      isProton ? Icons.sports_esports : Icons.wine_bar,
      color: _getTypeTextColor(isProton),
    );
  }

  Future<void> _deletePrefix(WinePrefix prefix) async {
    if (!mounted) return;

    // Store messenger before async gap
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Prefix'),
        content: Text('Are you sure you want to delete "${prefix.name}"?\nThis cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (!mounted) return;  // Check mounted after dialog

    if (confirmed == true) {
      try {
        final directory = Directory(prefix.path);
        if (await directory.exists()) {
          await directory.delete(recursive: true);
          if (mounted) {
            context.read<PrefixProvider>().removePrefix(prefix.path);
            messenger.showSnackBar(  // Use stored messenger
              SnackBar(
                content: Text('Successfully deleted prefix: ${prefix.name}'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      } catch (e) {
        LoggingService().log('Error deleting prefix: $e', level: LogLevel.error);
        if (mounted) {
          messenger.showSnackBar(  // Use stored messenger
            SnackBar(
              content: Text('Error deleting prefix: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _showSnackBar(String message, {bool isError = false}) async {
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error : Icons.info,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade700 : Colors.blue.shade700,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            messenger.hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<SettingsProvider, PrefixProvider>(
      builder: (context, settings, prefixProvider, _) {
        final prefixUrls = settings.prefixUrls;
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
                    Navigator.pushNamed(
                      context,
                      '/settings',
                    );
                  },
                ),
              ],
            ),
          );
        }

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
                      children: [
                        const Icon(Icons.source, color: Colors.green),
                        const SizedBox(width: 8),
                    Text(
                          'Available Prefix Sources',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ...prefixUrls.map((prefix) => Card(
                      color: _getTypeColor(prefix.isProton),
                      child: Column(
                        children: [
                          ListTile(
                            leading: _getTypeIcon(prefix.isProton),
                            title: Text(
                      prefix.url,
                              style: TextStyle(color: Colors.grey.shade900),
                            ),
                            subtitle: Text(
                              prefix.isProton ? 'Proton' : 'Wine',
                              style: TextStyle(
                                color: _getTypeTextColor(prefix.isProton),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            trailing: ElevatedButton.icon(
                              icon: const Icon(Icons.add),
                              label: const Text('Create Prefix'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _getTypeButtonColor(prefix.isProton),
                                foregroundColor: Colors.white,
                              ),
                              onPressed: _downloadProgress.containsKey(prefix.url) ? null : 
                                () => _showCreatePrefixDialog(context, prefix),
                            ),
                          ),
                          if (_downloadProgress.containsKey(prefix.url)) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  LinearProgressIndicator(
                                    value: _downloadProgress[prefix.url],
                                    backgroundColor: Colors.grey.shade200,
                                    valueColor: AlwaysStoppedAnimation(
                                      _getTypeTextColor(prefix.isProton),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _downloadStatus[prefix.url] ?? '',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                                ],
                              ),
                    ),
                    const SizedBox(height: 8),
                          ],
                        ],
                      ),
                    )),
                    if (prefixUrls.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Icon(Icons.warning_amber, size: 48, color: Colors.grey),
                              SizedBox(height: 8),
                              Text(
                                'No prefix sources available.\nAdd them in Settings.',
                                textAlign: TextAlign.center,
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
            const SizedBox(height: 16),
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.folder_special, color: Colors.orange),
                        const SizedBox(width: 8),
                    Text(
                          'Installed Prefixes',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ...prefixes.map((prefix) => Card(
                      color: _getTypeColor(prefix.isProton),
                      child: ExpansionTile(
                        leading: _getTypeIcon(prefix.isProton),
                        title: Text(
                          prefix.name,
                          style: TextStyle(color: Colors.grey.shade900),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  prefix.isProton ? 'Proton' : 'Wine',
                                  style: TextStyle(
                                    color: _getTypeTextColor(prefix.isProton),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  prefix.is64Bit ? '64-bit' : '32-bit',
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            if (_downloadStatus.containsKey(prefix.name))
                              Text(
                                _downloadStatus[prefix.name] ?? '',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.grey.shade800,
                                ),
                              ),
                          ],
                        ),
                        children: [
                          if (_downloadProgress.containsKey(prefix.name))
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              child: LinearProgressIndicator(
                                value: _downloadProgress[prefix.name],
                                backgroundColor: Colors.grey.shade200,
                                valueColor: AlwaysStoppedAnimation(
                                  _getTypeTextColor(prefix.isProton),
                                ),
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.settings),
                                      label: const Text('Winecfg'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.grey.shade700,
                                        foregroundColor: Colors.white,
                                      ),
                                      onPressed: () => prefix.runWinecfg(),
                                    ),
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.build),
                                      label: const Text('Winetricks'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.grey.shade700,
                                        foregroundColor: Colors.white,
                                      ),
                                      onPressed: () => prefix.runWinetricks(),
                                    ),
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.folder),
                                      label: const Text('Explorer'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.grey.shade700,
                                        foregroundColor: Colors.white,
                                      ),
                                      onPressed: () => prefix.runExplorer(),
                                    ),
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.play_arrow),
                                      label: const Text('Run EXE'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green.shade600,
                                        foregroundColor: Colors.white,
                                      ),
                                      onPressed: () => _selectAndRunExe(prefix),
                                    ),
                                    if (!prefix.isProton)
                                      ElevatedButton.icon(
                                        icon: const Icon(Icons.build),
                                        label: const Text('Install VC++'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.orange.shade600,
                                          foregroundColor: Colors.white,
                                        ),
                                        onPressed: () => prefix.installVisualCRuntime(),
                                      ),
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.delete),
                                      label: const Text('Delete'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red.shade600,
                                        foregroundColor: Colors.white,
                                      ),
                                      onPressed: () => _deletePrefix(prefix),
                                    ),
                                  ],
                                ),
                                if (!prefix.isProton) ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: [
                                      if (!prefix.settings.dxvkInstalled && !prefix.settings.dxvkAsyncInstalled) ...[
                                        ElevatedButton.icon(
                                          icon: const Icon(Icons.extension),
                                          label: const Text('Install DXVK'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.indigo.shade600,
                                            foregroundColor: Colors.white,
                                          ),
                                          onPressed: () => prefix.installDXVK(),
                                        ),
                                        ElevatedButton.icon(
                                          icon: const Icon(Icons.extension),
                                          label: const Text('DXVK-ASYNC'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.indigo.shade600,
                                            foregroundColor: Colors.white,
                                          ),
                                          onPressed: () => prefix.installDXVKAsync(),
                                        ),
                                      ] else ...[
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: Colors.green.shade100,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(Icons.check_circle, color: Colors.green.shade700),
                                              const SizedBox(width: 8),
                                              Text(
                                                prefix.settings.dxvkInstalled ? 'DXVK Installed' : 'DXVK-ASYNC Installed',
                                                style: TextStyle(color: Colors.green.shade700),
                                              ),
                                              const SizedBox(width: 8),
                                              IconButton(
                                                icon: const Icon(Icons.delete_outline, size: 20),
                                                color: Colors.red.shade400,
                                                onPressed: () => prefix.settings.dxvkInstalled 
                                                  ? prefix.uninstallDXVK() 
                                                  : prefix.uninstallDXVKAsync(),
                                                tooltip: 'Uninstall',
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                      if (!prefix.settings.vkd3dInstalled)
                                        ElevatedButton.icon(
                                          icon: const Icon(Icons.extension),
                                          label: const Text('Install VKD3D'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.indigo.shade600,
                                            foregroundColor: Colors.white,
                                          ),
                                          onPressed: () => prefix.installVKD3D(),
                                        )
                                      else
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: Colors.green.shade100,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(Icons.check_circle, color: Colors.green.shade700),
                                              const SizedBox(width: 8),
                                              Text(
                                                'VKD3D Installed',
                                                style: TextStyle(color: Colors.green.shade700),
                                              ),
                                              const SizedBox(width: 8),
                                              IconButton(
                                                icon: const Icon(Icons.delete_outline, size: 20),
                                                color: Colors.red.shade400,
                                                onPressed: () => prefix.uninstallVKD3D(),
                                                tooltip: 'Uninstall',
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    )),
                    if (prefixes.isEmpty)
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
      },
    );
  }

  @override
  void dispose() {
    _prefixNameController.dispose();
    super.dispose();
  }
} 