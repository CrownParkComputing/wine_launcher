import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:wine_launcher/services/logging_service.dart';
import 'package:wine_launcher/models/prefix_settings.dart';
import 'package:wine_launcher/services/dxvk_service.dart';
import 'package:wine_launcher/services/vkd3d_service.dart';
import 'package:wine_launcher/services/runtime_service.dart';
import 'package:wine_launcher/models/prefix_url.dart';
import 'package:wine_launcher/main.dart';  // For navigatorKey

class WinePrefix extends ChangeNotifier {
  static const protonBinaryNames = ['proton', 'proton.sh', 'proton-run'];

  static Future<WinePrefix> create({
    required String name,
    required String basePath,
    required PrefixUrl source,
    required bool is64Bit,
    required Function(double progress, String status) onProgress,
  }) async {
    final prefixType = source.isProton ? 'proton' : 'wine';
    final fileName = source.url.split('/').last;
    final downloadDir = Directory(p.join(basePath, 'downloads'));
    final downloadPath = p.join(downloadDir.path, fileName);
    final extractDir = p.join(basePath, prefixType, 'base');
    final prefixPath = p.join(basePath, prefixType, name);

    // Validate architecture for Proton
    if (source.isProton && !is64Bit) {
      throw Exception('Proton only supports 64-bit prefixes');
    }

    LoggingService().log(
      'Starting prefix creation:\n'
      'Type: $prefixType\n'
      'Name: $name\n'
      'URL: ${source.url}\n'
      'Architecture: ${is64Bit ? "64-bit" : "32-bit"}\n'
      'Download path: $downloadPath\n'
      'Extract dir: $extractDir',
      level: LogLevel.info,
    );

    // Create directories
    await downloadDir.create(recursive: true);
    await Directory(extractDir).create(recursive: true);

    // Download and extract
    await _downloadAndExtract(
      source.url,
      downloadPath,
      extractDir,
      onProgress,
    );

    try {
      // Initialize prefix
      await _initializePrefix(
        prefixPath,
        extractDir,
        is64Bit,
        source.isProton,
      );
    } catch (e) {
      // Clean up on failure
      if (await Directory(prefixPath).exists()) {
        await Directory(prefixPath).delete(recursive: true);
      }
      rethrow;
    }

    return WinePrefix(
      context: navigatorKey.currentContext!,
      name: name,
      path: prefixPath,
      isProton: source.isProton,
      sourceUrl: source.url,
      is64Bit: is64Bit,
      onStatusUpdate: (msg, {isError = false}) {
        LoggingService().log(msg, level: isError ? LogLevel.error : LogLevel.info);
      },
    );
  }

  static Future<void> _downloadAndExtract(
    String url,
    String downloadPath,
    String extractDir,
    Function(double progress, String status) onProgress,
  ) async {
    // Download section
    final response = await http.Client().send(
      http.Request('GET', Uri.parse(url))..headers['Accept'] = '*/*',
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to download: HTTP ${response.statusCode}');
    }

    final contentLength = response.contentLength ?? 0;
    if (contentLength == 0) {
      throw Exception('Invalid content length from server');
    }

    final file = File(downloadPath);
    final sink = file.openWrite();
    int received = 0;

    await for (final chunk in response.stream) {
      sink.add(chunk);
      received += chunk.length;
      onProgress(
        received / contentLength,
        'Downloading: ${(received / 1024 / 1024).toStringAsFixed(2)}MB / ${(contentLength / 1024 / 1024).toStringAsFixed(2)}MB',
      );
    }

    await sink.close();

    // Extract
    onProgress(0.8, 'Extracting files...');
    final fileName = downloadPath.split('/').last;
    final extractCommand = fileName.endsWith('.tar.gz') || fileName.endsWith('.tgz')
        ? ['tar', '-xzf', downloadPath, '-C', extractDir]
        : fileName.endsWith('.tar.xz')
            ? ['tar', '-xJf', downloadPath, '-C', extractDir]
            : fileName.endsWith('.zip')
                ? ['unzip', downloadPath, '-d', extractDir]
                : throw Exception('Unsupported archive format: $fileName');

    final result = await Process.run(extractCommand[0], extractCommand.sublist(1));
    if (result.exitCode != 0) {
      throw Exception('Failed to extract archive: ${result.stderr}');
    }

    // Clean up
    await file.delete();
  }

  static Future<void> _initializePrefix(
    String prefixPath,
    String extractDir,
    bool is64Bit,
    bool isProton,
  ) async {
    await Directory(prefixPath).create(recursive: true);

    final env = {
      'WINEPREFIX': prefixPath,
      'WINEARCH': is64Bit ? 'win64' : 'win32',
      'WINEDLLOVERRIDES': 'mscoree,mshtml=',
      'PATH': '$extractDir/bin:${Platform.environment['PATH']}',
    };

    // First, ensure WINEPREFIX is empty or doesn't exist
    if (await Directory(prefixPath).exists()) {
      await Directory(prefixPath).delete(recursive: true);
      await Directory(prefixPath).create(recursive: true);
    }

    // Initialize prefix with wineboot
    LoggingService().log(
      'Initializing prefix with WINEARCH=${env['WINEARCH']}',
      level: LogLevel.info,
    );

    final result = await Process.run('wineboot', ['-u'], environment: env);
    if (result.exitCode != 0) {
      LoggingService().log(
        'Failed to initialize prefix: ${result.stderr}',
        level: LogLevel.error,
      );
      throw Exception('Failed to initialize prefix: ${result.stderr}');
    }

    // Verify architecture
    final system32Dir = Directory('$prefixPath/drive_c/windows/system32');
    final syswow64Dir = Directory('$prefixPath/drive_c/windows/syswow64');
    
    if (is64Bit && !await syswow64Dir.exists()) {
      throw Exception('Failed to create 64-bit prefix: syswow64 directory missing');
    }
    
    if (!is64Bit && await syswow64Dir.exists()) {
      throw Exception('32-bit prefix contains syswow64 directory');
    }
    
    if (!await system32Dir.exists()) {
      throw Exception('Failed to create prefix: system32 directory missing');
    }
  }

  final BuildContext context;
  final String name;
  final String path;
  final bool isProton;
  final String sourceUrl;
  final bool is64Bit;
  final Function(String message, {bool isError}) onStatusUpdate;
  late PrefixSettings settings;
  late Directory system32Dir;
  late Directory syswow64Dir;

  late final DxvkService _dxvkService;
  late final Vkd3dService _vkd3dService;
  late final RuntimeService _runtimeService;

  WinePrefix({
    required this.context,
    required this.name,
    required this.path,
    required this.isProton,
    required this.sourceUrl,
    required this.is64Bit,
    required this.onStatusUpdate,
  }) {
    _loadSettings();
    system32Dir = Directory('$path/drive_c/windows/system32');
    syswow64Dir = Directory('$path/drive_c/windows/syswow64');
    _initializeServices();
  }

  void _initializeServices() {
    _dxvkService = DxvkService(
      context: context,
      prefixPath: path,
      is64Bit: is64Bit,
      onStatusUpdate: onStatusUpdate,
    );
    _vkd3dService = Vkd3dService(
      prefixPath: path,
      is64Bit: is64Bit,
      onStatusUpdate: onStatusUpdate,
      context: context,
    );
    _runtimeService = RuntimeService(
      context: context,
      prefixPath: path,
      is64Bit: is64Bit,
      onStatusUpdate: onStatusUpdate,
    );
  }

  void _loadSettings() {
    final settingsFile = File('$path/prefix_settings.json');
    try {
      // Create directory if it doesn't exist
      settingsFile.parent.createSync(recursive: true);

      if (settingsFile.existsSync()) {
        final jsonStr = settingsFile.readAsStringSync();
        settings = PrefixSettings.fromJson(jsonDecode(jsonStr));
      } else {
        // Create default settings
        settings = PrefixSettings(
          name: name,
          path: path,
          isProton: isProton,
          sourceUrl: sourceUrl,
          is64Bit: is64Bit,
        );
        _saveSettings();
      }
    } catch (e) {
      LoggingService().log(
        'Error loading prefix settings: $e',
        level: LogLevel.error,
      );
      // Create default settings even on error
      settings = PrefixSettings(
        name: name,
        path: path,
        isProton: isProton,
        sourceUrl: sourceUrl,
        is64Bit: is64Bit,
      );
    }
  }

  void _saveSettings() {
    final settingsFile = File('$path/prefix_settings.json');
    try {
      // Create directory if it doesn't exist
      settingsFile.parent.createSync(recursive: true);

      final jsonStr = const JsonEncoder.withIndent('  ').convert(settings.toJson());
      settingsFile.writeAsStringSync(jsonStr);
    } catch (e) {
      LoggingService().log(
        'Error saving prefix settings: $e',
        level: LogLevel.error,
      );
    }
  }

  Future<void> runWinecfg() async {
    final env = {
      'WINEPREFIX': path,
      'WINEARCH': is64Bit ? 'win64' : 'win32',
    };
    
    try {
      onStatusUpdate('Opening Wine Configuration...');
      final result = await Process.run('winecfg', [], environment: env);
      if (result.exitCode != 0) {
        LoggingService().log(
          'Failed to run winecfg: ${result.stderr}',
          level: LogLevel.error,
        );
        onStatusUpdate('Failed to open Wine Configuration', isError: true);
      } else {
        onStatusUpdate('Wine Configuration closed');
      }
    } catch (e) {
      LoggingService().log('Error running winecfg: $e', level: LogLevel.error);
      onStatusUpdate('Error opening Wine Configuration: $e', isError: true);
    }
  }

  Future<void> runExplorer() async {
    final env = {
      'WINEPREFIX': path,
      'WINEARCH': is64Bit ? 'win64' : 'win32',
    };
    
    try {
      onStatusUpdate('Opening Wine Explorer...');
      final result = await Process.run('wine', ['explorer'], environment: env);
      if (result.exitCode != 0) {
        LoggingService().log(
          'Failed to run explorer: ${result.stderr}',
          level: LogLevel.error,
        );
        onStatusUpdate('Failed to open Wine Explorer', isError: true);
      } else {
        onStatusUpdate('Wine Explorer closed');
      }
    } catch (e) {
      LoggingService().log('Error running explorer: $e', level: LogLevel.error);
      onStatusUpdate('Error opening Wine Explorer: $e', isError: true);
    }
  }

  Future<void> runExe(String exePath) async {
    if (!File(exePath).existsSync()) {
      LoggingService().log('EXE file not found: $exePath', level: LogLevel.error);
      onStatusUpdate('EXE file not found', isError: true);
      return;
    }

    final exeDir = Directory(p.dirname(exePath));
    LoggingService().log(
      'Running EXE:\n'
      'Prefix: $name (${isProton ? "Proton" : "Wine"}, ${is64Bit ? "64-bit" : "32-bit"})\n'
      'Prefix Path: $path\n'
      'EXE Path: $exePath\n'
      'Working Directory: ${exeDir.path}',
      level: LogLevel.info,
    );

    try {
      if (isProton) {
        // For Proton prefixes, use PROTON_USE_WINED3D11 and other Proton-specific variables
        final env = {
          'STEAM_COMPAT_CLIENT_INSTALL_PATH': path,
          'STEAM_COMPAT_DATA_PATH': path,
          'PROTON_LOG': '1',  // Enable Proton logging
          'PROTON_DUMP_DEBUG_COMMANDS': '1',  // Show commands being executed
          'PROTON_ENABLE_NVAPI': '1',  // Enable NVIDIA NVAPI support
          'PROTON_HIDE_NVIDIA_GPU': '0',
          'PROTON_ENABLE_NGX_UPDATER': '1',
          'DXVK_ASYNC': '1',  // Enable async pipelines
          'DXVK_HUD': 'fps,frametimes',  // Show performance overlay
          'VKD3D_DEBUG': 'none',  // Disable vkd3d debug output
          'VKD3D_CONFIG': 'dxr',  // Enable DXR (DirectX Raytracing)
          'VKD3D_FEATURE_LEVEL': '12_1',  // Set DX12 feature level
          'WINEPREFIX': path,
          'WINEARCH': is64Bit ? 'win64' : 'win32',
        };

        // Find proton binary
        final protonBin = await _findProtonBinary();
        if (protonBin == null) {
          throw Exception('Could not find proton binary');
        }

        final result = await Process.run(
          protonBin,
          ['run', exePath],
          environment: env,
          workingDirectory: exeDir.path,
          runInShell: true,
        );

        if (result.exitCode != 0) {
          LoggingService().log(
            'Failed to run exe with Proton:\n${result.stderr}',
            level: LogLevel.error,
          );
          onStatusUpdate('Failed to run executable with Proton', isError: true);
        } else {
          LoggingService().log(
            'Successfully launched EXE with Proton',
            level: LogLevel.info,
          );
          onStatusUpdate('Successfully launched executable with Proton');
        }
      } else {
        // Minimal Wine environment
        final env = {
          'WINEPREFIX': path,
          'WINEARCH': settings.is64Bit ? 'win64' : 'win32',
          'WINEDEBUG': '-all',  // Disable debug output
          'PATH': Platform.environment['PATH'] ?? '',
        };

        final result = await Process.run(
          'wine',
          [exePath],
          environment: env,  // Use the environment variables
          workingDirectory: exeDir.path,
          runInShell: true,
        );

        if (result.exitCode != 0) {
          LoggingService().log(
            'Failed to run exe:\n${result.stderr}',
            level: LogLevel.error,
          );
          onStatusUpdate('Failed to run executable', isError: true);
        } else {
          LoggingService().log(
            'Successfully launched EXE',
            level: LogLevel.info,
          );
          onStatusUpdate('Successfully launched executable');
        }
      }
    } catch (e) {
      LoggingService().log('Error running exe: $e', level: LogLevel.error);
      onStatusUpdate('Error running executable: $e', isError: true);
    }
  }

  Future<String?> _findProtonBinary() async {
    try {
      // First check in the Proton base directory
      final baseDir = Directory(p.join(p.dirname(p.dirname(path)), 'base'));
      if (await baseDir.exists()) {
        final entries = await baseDir.list().toList();
        for (final entry in entries) {
          if (entry is Directory && entry.path.contains('Proton')) {
            // Found a Proton directory, look for the binary
            for (final binary in protonBinaryNames) {
              final binaryPath = p.join(entry.path, binary);
              if (await File(binaryPath).exists()) {
                LoggingService().log(
                  'Found Proton binary at: $binaryPath',
                  level: LogLevel.info,
                );
                return binaryPath;
              }
            }
          }
        }
      }

      // If not found in base dir, try the prefix directory
      for (final binary in protonBinaryNames) {
        final binaryPath = p.join(path, 'bin', binary);
        if (await File(binaryPath).exists()) {
          LoggingService().log(
            'Found Proton binary in prefix at: $binaryPath',
            level: LogLevel.info,
          );
          return binaryPath;
        }
      }

      // Last resort: recursive search
      final result = await Process.run('find', [
        p.dirname(p.dirname(path)),  // Search from parent of prefix dir
        '-name',
        'proton',
        '-type',
        'f',
        '-executable'
      ]);

      final paths = result.stdout.toString().trim().split('\n');
      for (final path in paths) {
        if (path.isNotEmpty && await File(path).exists()) {
          LoggingService().log(
            'Found Proton binary via search at: $path',
            level: LogLevel.info,
          );
          return path;
        }
      }

      LoggingService().log(
        'Could not find Proton binary in any location',
        level: LogLevel.error,
      );
    } catch (e) {
      LoggingService().log('Error finding proton binary: $e', level: LogLevel.error);
    }
    return null;
  }

  Future<void> installDXVK() => _dxvkService.installDXVK();
  Future<void> installDXVKAsync() => _dxvkService.installDXVKAsync();
  Future<void> uninstallDXVK() => _dxvkService.uninstallDXVK();
  Future<void> uninstallDXVKAsync() => _dxvkService.uninstallDXVKAsync();
  Future<void> installVKD3D() => _vkd3dService.install();
  Future<void> uninstallVKD3D() => _vkd3dService.uninstall();
  Future<void> installVisualCRuntime() => _runtimeService.installVisualCRuntime();

  Future<void> runWinetricks() async {
    final env = {
      'WINEPREFIX': path,
      'WINEARCH': is64Bit ? 'win64' : 'win32',
    };
    
    try {
      onStatusUpdate('Opening Winetricks...');
      final result = await Process.run('winetricks', [], environment: env);
      if (result.exitCode != 0) {
        LoggingService().log(
          'Failed to run winetricks: ${result.stderr}',
          level: LogLevel.error,
        );
        onStatusUpdate('Failed to open Winetricks', isError: true);
      } else {
        onStatusUpdate('Winetricks closed');
      }
    } catch (e) {
      LoggingService().log('Error running winetricks: $e', level: LogLevel.error);
      onStatusUpdate('Error opening Winetricks: $e', isError: true);
    }
  }

  void updateSettings(PrefixSettings newSettings) {
    settings = newSettings;
    _saveSettings();
    notifyListeners();
  }

  String get bits => is64Bit ? '64-bit' : '32-bit';

  Future<void> runRegedit() async {
    await Process.run('wine', ['regedit'], 
      environment: {
        'WINEPREFIX': path,
        if (isProton) ...{
          'PROTON_NO_ESYNC': '1',
          'PROTON_NO_FSYNC': '1',
        },
      }
    );
  }

  bool hasAddon(String type) {
    switch (type) {
      case 'dxvk':
        return File(p.join(path, 'drive_c/windows/system32/d3d11.dll')).existsSync();
      case 'vkd3d':
        return File(p.join(path, 'drive_c/windows/system32/d3d12.dll')).existsSync();
      case 'runtime':
        return File(p.join(path, 'drive_c/windows/system32/msvcp140.dll')).existsSync();
      default:
        return false;
    }
  }

  Future<void> runJoyConfig() async {
    await Process.run('wine', ['control', 'joy.cpl'], 
      environment: {
        'WINEPREFIX': path,
        if (isProton) ...{
          'PROTON_NO_ESYNC': '1',
          'PROTON_NO_FSYNC': '1',
        },
      }
    );
  }

  Future<void> applyControllerFix() async {
    try {
      LoggingService().log('Applying controller fix for prefix: $name', level: LogLevel.info);
      
      // Apply registry fixes
      final result1 = await Process.run('wine', [
        'reg',
        'add',
        'HKEY_LOCAL_MACHINE\\System\\CurrentControlSet\\Services\\winebus',
        '/v',
        'DisableHidraw',
        '/t',
        'REG_DWORD',
        '/d',
        '1'
      ], environment: {
        'WINEPREFIX': path
      });

      if (result1.exitCode != 0) {
        throw Exception('Failed to apply first registry fix: ${result1.stderr}');
      }

      final result2 = await Process.run('wine', [
        'reg',
        'add',
        'HKEY_LOCAL_MACHINE\\System\\CurrentControlSet\\Services\\winebus',
        '/v',
        'Enable SDL',
        '/t',
        'REG_DWORD',
        '/d',
        '1'
      ], environment: {
        'WINEPREFIX': path
      });

      if (result2.exitCode != 0) {
        throw Exception('Failed to apply second registry fix: ${result2.stderr}');
      }

      LoggingService().log('Successfully applied controller fix for prefix: $name', level: LogLevel.info);
    } catch (e) {
      LoggingService().log('Error applying controller fix: $e', level: LogLevel.error);
      rethrow;
    }
  }

  Future<void> setWineRegistryKey(String key, Map<String, String> values) async {
    final regFile = File('$path/user.reg');
    var content = await regFile.readAsString();
    
    // Create key if it doesn't exist
    if (!content.contains('[$key]')) {
      content += '\n\n[$key]';
    }
    
    // Add or update values
    for (final entry in values.entries) {
      final pattern = RegExp('"${entry.key}"=".*"');
      final newValue = '"${entry.key}"="${entry.value}"';
      
      if (content.contains(pattern)) {
        content = content.replaceAll(pattern, newValue);
      } else {
        content += '\n$newValue';
      }
    }
    
    await regFile.writeAsString(content);
    
    // Reload registry
    await Process.run('wineboot', ['-u'], 
      environment: {
        'WINEPREFIX': path,
        if (isProton) ...{
          'PROTON_NO_ESYNC': '1',
          'PROTON_NO_FSYNC': '1',
        },
      },
    );
  }

  Future<bool> checkVulkanSupport() async {
    try {
      final result = await Process.run('vulkaninfo', ['--summary']);
      if (result.exitCode != 0) {
        LoggingService().log(
          'Vulkan not properly configured: ${result.stderr}',
          level: LogLevel.error,
        );
        return false;
      }
      return true;
    } catch (e) {
      LoggingService().log(
        'Error checking Vulkan support: $e',
        level: LogLevel.error,
      );
      return false;
    }
  }
}
