import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wine_launcher/services/wine_service_base.dart';
import 'package:wine_launcher/services/logging_service.dart';
import 'package:wine_launcher/models/providers.dart';
import 'package:http/http.dart' as http;

class DxvkService extends WineServiceBase {
  final BuildContext context;
  late final String _dxvkAsyncUrl;
  
  DxvkService({
    required this.context,
    required super.prefixPath,
    required super.is64Bit,
    required super.onStatusUpdate,
  }) {
    _dxvkAsyncUrl = context.read<SettingsProvider>().dxvkAsyncUrl;
  }

  Future<void> installDXVK() async {
    try {
      // Create directories
      final system32Dir = Directory('$prefixPath/drive_c/windows/system32');
      final syswow64Dir = Directory('$prefixPath/drive_c/windows/syswow64');
      await system32Dir.create(recursive: true);
      if (is64Bit) {
        await syswow64Dir.create(recursive: true);
      }

      // Download DXVK files
      final downloadDir = Directory('$prefixPath/downloads');
      await downloadDir.create(recursive: true);

      const dllFiles = {
        'x32': ['d3d9.dll', 'd3d10core.dll', 'd3d11.dll', 'dxgi.dll'],
        'x64': ['d3d9.dll', 'd3d10core.dll', 'd3d11.dll', 'dxgi.dll'],
      };

      // Copy DLLs
      bool allFilesPresent = true;
      for (final dll in dllFiles['x32']!) {
        if (!await File('${syswow64Dir.path}/$dll').exists()) {
          allFilesPresent = false;
          break;
        }
      }

      if (is64Bit) {
        for (final dll in dllFiles['x64']!) {
          if (!await File('${system32Dir.path}/$dll').exists()) {
            allFilesPresent = false;
            break;
          }
        }
      }

      if (allFilesPresent) {
        onStatusUpdate('DXVK files already present', isError: true);
        return;
      }

      // Copy 32-bit DLLs
      for (final dll in dllFiles['x32']!) {
        final source = File('$prefixPath/downloads/dxvk/x32/$dll');
        final target = File('${syswow64Dir.path}/$dll');
        if (await source.exists()) {
          await source.copy(target.path);
        }
      }

      // Copy 64-bit DLLs if needed
      if (is64Bit) {
        for (final dll in dllFiles['x64']!) {
          final source = File('$prefixPath/downloads/dxvk/x64/$dll');
          final target = File('${system32Dir.path}/$dll');
          if (await source.exists()) {
            await source.copy(target.path);
          }
        }
      }

      onStatusUpdate('Successfully installed DXVK');
    } catch (e) {
      LoggingService().log('Error installing DXVK: $e', level: LogLevel.error);
      onStatusUpdate('Error installing DXVK: $e', isError: true);
    }
  }

  Future<void> installDXVKAsync() async {
    try {
      // Create directories
      final system32Dir = Directory('$prefixPath/drive_c/windows/system32');
      final syswow64Dir = Directory('$prefixPath/drive_c/windows/syswow64');
      await system32Dir.create(recursive: true);
      if (is64Bit) {
        await syswow64Dir.create(recursive: true);
      }

      // Use stored URL instead of reading from context
      final downloadDir = Directory('$prefixPath/downloads');
      await downloadDir.create(recursive: true);
      final downloadPath = '${downloadDir.path}/dxvk-async.tar.gz';

      onStatusUpdate('Downloading DXVK-ASYNC...');
      final response = await http.get(Uri.parse(_dxvkAsyncUrl));
      if (response.statusCode != 200) {
        throw Exception('Failed to download DXVK-ASYNC');
      }
      await File(downloadPath).writeAsBytes(response.bodyBytes);

      // Extract files
      onStatusUpdate('Extracting DXVK-ASYNC...');
      final extractDir = '${downloadDir.path}/dxvk-async';
      await Directory(extractDir).create(recursive: true);
      
      final extractResult = await Process.run(
        'tar',
        ['-xzf', downloadPath, '-C', extractDir],
        environment: baseEnvironment,
      );

      if (extractResult.exitCode != 0) {
        throw Exception('Failed to extract DXVK-ASYNC');
      }

      // Copy DLLs
      const dllFiles = {
        'x32': ['d3d9.dll', 'd3d10core.dll', 'd3d11.dll', 'dxgi.dll'],
        'x64': ['d3d9.dll', 'd3d10core.dll', 'd3d11.dll', 'dxgi.dll'],
      };

      // Copy 32-bit DLLs
      for (final dll in dllFiles['x32']!) {
        final source = File('$extractDir/x32/$dll');
        final target = File('${syswow64Dir.path}/$dll');
        if (await source.exists()) {
          await source.copy(target.path);
        }
      }

      // Copy 64-bit DLLs if needed
      if (is64Bit) {
        for (final dll in dllFiles['x64']!) {
          final source = File('$extractDir/x64/$dll');
          final target = File('${system32Dir.path}/$dll');
          if (await source.exists()) {
            await source.copy(target.path);
          }
        }
      }

      // Cleanup
      await File(downloadPath).delete();
      await Directory(extractDir).delete(recursive: true);

      onStatusUpdate('Successfully installed DXVK-ASYNC');
    } catch (e) {
      LoggingService().log('Error installing DXVK-ASYNC: $e', level: LogLevel.error);
      onStatusUpdate('Error installing DXVK-ASYNC: $e', isError: true);
    }
  }

  Future<void> uninstallDXVK() async {
    try {
      final dllFiles = is64Bit ? [
        'system32/d3d9.dll',
        'system32/d3d10core.dll',
        'system32/d3d11.dll',
        'system32/dxgi.dll',
        'syswow64/d3d9.dll',
        'syswow64/d3d10core.dll',
        'syswow64/d3d11.dll',
        'syswow64/dxgi.dll',
      ] : [
        'system32/d3d9.dll',
        'system32/d3d10core.dll',
        'system32/d3d11.dll',
        'system32/dxgi.dll',
      ];

      for (final dll in dllFiles) {
        final file = File('$prefixPath/drive_c/windows/$dll');
        if (await file.exists()) {
          await file.delete();
        }
      }

      onStatusUpdate('Successfully uninstalled DXVK');
    } catch (e) {
      LoggingService().log('Error uninstalling DXVK: $e', level: LogLevel.error);
      onStatusUpdate('Error uninstalling DXVK: $e', isError: true);
    }
  }

  Future<void> uninstallDXVKAsync() async {
    try {
      final dllFiles = is64Bit ? [
        'system32/d3d9.dll',
        'system32/d3d10core.dll',
        'system32/d3d11.dll',
        'system32/dxgi.dll',
        'syswow64/d3d9.dll',
        'syswow64/d3d10core.dll',
        'syswow64/d3d11.dll',
        'syswow64/dxgi.dll',
      ] : [
        'system32/d3d9.dll',
        'system32/d3d10core.dll',
        'system32/d3d11.dll',
        'system32/dxgi.dll',
      ];

      for (final dll in dllFiles) {
        final file = File('$prefixPath/drive_c/windows/$dll');
        if (await file.exists()) {
          await file.delete();
        }
      }

      onStatusUpdate('Successfully uninstalled DXVK-ASYNC');
    } catch (e) {
      LoggingService().log('Error uninstalling DXVK-ASYNC: $e', level: LogLevel.error);
      onStatusUpdate('Error uninstalling DXVK-ASYNC: $e', isError: true);
    }
  }
} 