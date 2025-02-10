import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wine_launcher/services/wine_service_base.dart';
import 'package:wine_launcher/services/logging_service.dart';
import 'package:wine_launcher/models/providers.dart';

class RuntimeService extends WineServiceBase {
  final BuildContext context;
  late final String _vcRedistPath;

  RuntimeService({
    required this.context,
    required String prefixPath,
    required bool is64Bit,
    required Function(String, {bool isError}) onStatusUpdate,
  }) : super(
    prefixPath: prefixPath,
    is64Bit: is64Bit,
    onStatusUpdate: onStatusUpdate,
  ) {
    _vcRedistPath = context.read<SettingsProvider>().vcRedistPath;
  }

  Future<void> installVisualCRuntime() async {
    if (!File(_vcRedistPath).existsSync()) {
      LoggingService().log(
        'Visual C++ Runtime installer not found at: $_vcRedistPath',
        level: LogLevel.error,
      );
      onStatusUpdate('Visual C++ Runtime installer not found', isError: true);
      return;
    }

    LoggingService().log(
      'Installing Visual C++ Runtime',
      level: LogLevel.info,
    );
    onStatusUpdate('Installing Visual C++ Runtime...');

    try {
      // Create system directories if they don't exist
      final system32Dir = Directory('$prefixPath/drive_c/windows/system32');
      final syswow64Dir = Directory('$prefixPath/drive_c/windows/syswow64');
      await system32Dir.create(recursive: true);
      if (is64Bit) {
        await syswow64Dir.create(recursive: true);
      }

      // Set up environment with additional variables
      final env = {
        ...baseEnvironment,
        'WINEDLLOVERRIDES': 'mscoree,mshtml=',  // Prevent Gecko/Mono prompts
        'DISPLAY': Platform.environment['DISPLAY'] ?? ':0',
      };

      // Run the installer
      final result = await Process.run(
        'wine',
        [_vcRedistPath],
        environment: env,
        runInShell: true,
      );

      if (result.exitCode != 0) {
        LoggingService().log(
          'Failed to install Visual C++ Runtime:\n${result.stderr}',
          level: LogLevel.error,
        );
        onStatusUpdate('Failed to install Visual C++ Runtime', isError: true);
        return;
      }

      // Verify installation by checking for key DLLs
      final dllsToCheck = is64Bit ? {
        'system32': [
          'msvcp140.dll',
          'vcruntime140.dll',
          'vcruntime140_1.dll',
          'concrt140.dll',
        ],
        'syswow64': [
          'msvcp140.dll',
          'vcruntime140.dll',
          'concrt140.dll',
        ],
      } : {
        'system32': [
          'msvcp140.dll',
          'vcruntime140.dll',
          'concrt140.dll',
        ],
      };

      bool allDllsPresent = true;
      for (final entry in dllsToCheck.entries) {
        final dirPath = '$prefixPath/drive_c/windows/${entry.key}';
        for (final dll in entry.value) {
          if (!await File('$dirPath/$dll').exists()) {
            LoggingService().log(
              'Missing DLL after installation: $dirPath/$dll',
              level: LogLevel.warning,
            );
            allDllsPresent = false;
          }
        }
      }

      if (!allDllsPresent) {
        onStatusUpdate(
          'Visual C++ Runtime installation completed with warnings - some components may be missing',
          isError: true,
        );
      } else {
        LoggingService().log(
          'Successfully installed Visual C++ Runtime',
          level: LogLevel.info,
        );
        onStatusUpdate('Successfully installed Visual C++ Runtime');
      }

      // Run wineboot to ensure registry is updated
      await Process.run(
        'wineboot',
        ['-u'],
        environment: env,
        runInShell: true,
      );

    } catch (e) {
      LoggingService().log(
        'Error installing Visual C++ Runtime: $e',
        level: LogLevel.error,
      );
      onStatusUpdate('Error installing Visual C++ Runtime: $e', isError: true);
    }
  }

  Future<void> uninstallVisualCRuntime() async {
    try {
      // Get the uninstaller path from registry or use default location
      final uninstallerPath = await _findVCRedistUninstaller();
      if (uninstallerPath == null) {
        throw Exception('Could not find Visual C++ Runtime uninstaller');
      }

      final env = {
        ...baseEnvironment,
        'WINEDLLOVERRIDES': 'mscoree,mshtml=',
        'DISPLAY': Platform.environment['DISPLAY'] ?? ':0',
      };

      final result = await Process.run(
        'wine',
        [uninstallerPath, '/uninstall', '/quiet'],
        environment: env,
        runInShell: true,
      );

      if (result.exitCode != 0) {
        throw Exception('Uninstaller failed: ${result.stderr}');
      }

      onStatusUpdate('Successfully uninstalled Visual C++ Runtime');
    } catch (e) {
      LoggingService().log(
        'Error uninstalling Visual C++ Runtime: $e',
        level: LogLevel.error,
      );
      onStatusUpdate('Error uninstalling Visual C++ Runtime: $e', isError: true);
    }
  }

  Future<String?> _findVCRedistUninstaller() async {
    // Common locations for the uninstaller
    final locations = [
      '$prefixPath/drive_c/Program Files (x86)/Microsoft Visual Studio/Shared/VC/redist/MSVC/14.20.27508/vc_redist.x64.exe',
      '$prefixPath/drive_c/Program Files (x86)/Microsoft Visual Studio/Shared/VC/redist/MSVC/14.29.30037/vc_redist.x64.exe',
      '$prefixPath/drive_c/Program Files (x86)/Microsoft Visual Studio/Shared/VC/redist/MSVC/14.29.30133/vc_redist.x64.exe',
    ];

    for (final location in locations) {
      if (await File(location).exists()) {
        return location;
      }
    }

    return null;
  }
} 