import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';
import 'package:wine_launcher/services/logging_service.dart';
import 'package:wine_launcher/models/prefix_settings.dart';
import 'package:wine_launcher/services/dxvk_service.dart';
import 'package:wine_launcher/services/vkd3d_service.dart';
import 'package:wine_launcher/services/runtime_service.dart';
import 'package:wine_launcher/services/download_service.dart';
import 'package:provider/provider.dart';
import 'package:wine_launcher/models/providers.dart';

class WinePrefix extends ChangeNotifier {
  static const protonBinaryNames = ['proton', 'proton.sh', 'proton-run'];

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
    );
    _runtimeService = RuntimeService(
      context: context,
      prefixPath: path,
      is64Bit: is64Bit,
      onStatusUpdate: onStatusUpdate,
    );
  }

  Future<void> _loadSettings() async {
    final settingsFile = File('$path/prefix_settings.json');
    if (await settingsFile.exists()) {
      final jsonStr = await settingsFile.readAsString();
      settings = PrefixSettings.fromJson(jsonDecode(jsonStr));
    } else {
      settings = PrefixSettings();
      await _saveSettings();
    }
  }

  Future<void> _saveSettings() async {
    final settingsFile = File('$path/prefix_settings.json');
    await settingsFile.writeAsString(jsonEncode(settings.toJson()));
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
          'WINEARCH': is64Bit ? 'win64' : 'win32',
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
  Future<void> installVKD3D() async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final vkd3dUrl = settings.vkd3dUrl;

    try {
      onStatusUpdate('Downloading VKD3D...');
      
      final downloadDir = Directory(p.join(path, 'downloads'));
      await downloadDir.create(recursive: true);
      
      final fileName = p.basename(vkd3dUrl);
      final downloadPath = p.join(downloadDir.path, fileName);
      
      await DownloadService().downloadFile(vkd3dUrl, downloadPath);
      
      onStatusUpdate('Extracting VKD3D...');
      
      // Extract to a temporary directory
      final tempDir = await Directory.systemTemp.createTemp('vkd3d_');
      await Process.run('tar', ['-xf', downloadPath, '-C', tempDir.path]);
      
      // Copy DLLs to the prefix
      final system32Dir = p.join(path, 'drive_c', 'windows', 'system32');
      final syswow64Dir = p.join(path, 'drive_c', 'windows', 'syswow64');
      
      await _copyVKD3DDlls(tempDir.path, system32Dir, syswow64Dir);
      
      // Cleanup
      await tempDir.delete(recursive: true);
      await File(downloadPath).delete();
      
      // Update prefix settings
      this.settings = this.settings.copyWith(vkd3dInstalled: true);
      await _saveSettings();
      notifyListeners();
      
      onStatusUpdate('VKD3D installed successfully');
    } catch (e) {
      onStatusUpdate('Failed to install VKD3D: $e', isError: true);
      rethrow;
    }
  }

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

  Future<void> _copyVKD3DDlls(String sourceDir, String system32Dir, String syswow64Dir) async {
    try {
      // Find all VKD3D DLLs in the source directory
      final result = await Process.run('find', [
        sourceDir,
        '-name',
        '*.dll',
        '-type',
        'f'
      ]);

      final dllPaths = result.stdout.toString().trim().split('\n')
        .where((path) => path.isNotEmpty)
        .toList();

      LoggingService().log(
        'Found VKD3D DLLs:\n${dllPaths.join('\n')}',
        level: LogLevel.info,
      );

      // Copy 64-bit DLLs to system32
      for (final dllPath in dllPaths.where((p) => p.contains('x64'))) {
        final dllName = p.basename(dllPath);
        final targetPath = p.join(system32Dir, dllName);
        await File(dllPath).copy(targetPath);
        LoggingService().log(
          'Copied 64-bit DLL: $dllName',
          level: LogLevel.info,
        );
      }

      // Copy 32-bit DLLs to syswow64
      for (final dllPath in dllPaths.where((p) => p.contains('x86'))) {
        final dllName = p.basename(dllPath);
        final targetPath = p.join(syswow64Dir, dllName);
        await File(dllPath).copy(targetPath);
        LoggingService().log(
          'Copied 32-bit DLL: $dllName',
          level: LogLevel.info,
        );
      }

      LoggingService().log(
        'Successfully copied all VKD3D DLLs',
        level: LogLevel.info,
      );
    } catch (e) {
      LoggingService().log(
        'Error copying VKD3D DLLs: $e',
        level: LogLevel.error,
      );
      rethrow;
    }
  }
} 