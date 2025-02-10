import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wine_launcher/services/wine_service_base.dart';
import 'package:wine_launcher/services/logging_service.dart';
import 'package:wine_launcher/models/providers.dart';
import 'package:http/http.dart' as http;

class DxvkService extends WineServiceBase {
  final BuildContext context;
  late final Directory system32Dir;
  late final Directory syswow64Dir;
  final SettingsProvider settingsProvider;
  
  DxvkService({
    required this.context,
    required String prefixPath,
    required bool is64Bit,
    required Function(String, {bool isError}) onStatusUpdate,
  }) : settingsProvider = Provider.of<SettingsProvider>(context, listen: false),
      super(
        prefixPath: prefixPath,
        is64Bit: is64Bit,
        onStatusUpdate: onStatusUpdate,
      ) {
    system32Dir = Directory('$prefixPath/drive_c/windows/system32');
    syswow64Dir = Directory('$prefixPath/drive_c/windows/syswow64');
  }

  Future<void> installDXVK() async {
    try {
      onStatusUpdate('Installing DXVK...');
      
      final addon = settingsProvider.addons.firstWhere((a) => a.type == 'dxvk');
      
      await _copyDXVKFiles(addon.url, is64Bit ? 'x64' : 'x32', system32Dir);
      
      // Configure DLL overrides and renderer settings
      final regFile = File('$prefixPath/user.reg');
      var content = await regFile.readAsString();
      
      // Add DLL overrides
      if (!content.contains('[Software\\\\Wine\\\\DllOverrides]')) {
        content += '\n\n[Software\\\\Wine\\\\DllOverrides]';
      }
      content += '\n"dxgi"="native,builtin"';
      content += '\n"d3d11"="native,builtin"';
      content += '\n"d3d10core"="native,builtin"';
      content += '\n"d3d9"="native,builtin"';
      
      // Add Direct3D settings
      if (!content.contains('[Software\\\\Wine\\\\Direct3D]')) {
        content += '\n\n[Software\\\\Wine\\\\Direct3D]';
      }
      content += '\n"renderer"="vulkan"';
      content += '\n"MaxVersionGL"="dword:00040006"';
      content += '\n"MultiplayerSynchronous"="dword:00000000"';
      content += '\n"StrictShaderModels"="dword:00000000"';
      content += '\n"CheckFloatConstants"="dword:00000000"';
      content += '\n"csmt"="dword:00000001"';
      content += '\n"UseGLSL"="dword:00000001"';
      content += '\n"VideoMemorySize"="dword:00000800"';  // 2GB VRAM
      
      // Add Vulkan settings
      if (!content.contains('[Software\\\\Wine\\\\Vulkan]')) {
        content += '\n\n[Software\\\\Wine\\\\Vulkan]';
      }
      content += '\n"DxvkAsyncPipeCompiler"="dword:00000001"';
      content += '\n"DxvkHud"="fps,devinfo,gpuload"';
      content += '\n"DxvkNumCompilerThreads"="dword:00000004"';
      content += '\n"DxvkUseRawSsbo"="dword:00000001"';
      
      // Create shader cache directory
      final shaderCacheDir = Directory('$prefixPath/drive_c/shader-cache');
      await shaderCacheDir.create(recursive: true);
      
      // Create cache directory
      final cacheDir = Directory('$prefixPath/drive_c/dxvk-cache');
      await cacheDir.create(recursive: true);
      
      // Reload registry
      await Process.run('wineboot', ['-u'], 
        environment: {
          'WINEPREFIX': prefixPath,
        },
      );

      onStatusUpdate('DXVK installation complete');
    } catch (e) {
      onStatusUpdate('Failed to install DXVK: $e', isError: true);
      rethrow;
    }
  }

  Future<void> installDXVKAsync() async {
    final settings = context.read<SettingsProvider>();
    // Remove existing DXVK files if present
    if (await _isDXVKInstalled()) {
      await uninstallDXVKAsync();
    }

    final dxvkAsyncAddon = settings.addons.firstWhere(
      (addon) => addon.type == 'dxvk-async',
      orElse: () => throw Exception('DXVK Async addon not found in settings'),
    );

    onStatusUpdate('Installing DXVK Async...');

    try {
      // Create directories
      final system32Dir = Directory('$prefixPath/drive_c/windows/system32');
      final syswow64Dir = Directory('$prefixPath/drive_c/windows/syswow64');
      await system32Dir.create(recursive: true);
      if (is64Bit) {
        await syswow64Dir.create(recursive: true);
      }

      // Copy DLLs to system32
      await _copyDXVKFiles(dxvkAsyncAddon.url, 'x64', system32Dir);
      
      // Copy 32-bit DLLs if needed
      if (is64Bit) {
        await _copyDXVKFiles(dxvkAsyncAddon.url, 'x32', syswow64Dir);
      }

      onStatusUpdate('DXVK Async installation complete');
    } catch (e) {
      onStatusUpdate('Failed to install DXVK Async: $e', isError: true);
      rethrow;
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

  Future<bool> _isDXVKInstalled() async {
    final system32Dir = Directory('$prefixPath/drive_c/windows/system32');
    final syswow64Dir = Directory('$prefixPath/drive_c/windows/syswow64');

    if (is64Bit) {
      for (final dll in ['d3d9.dll', 'd3d10core.dll', 'd3d11.dll', 'dxgi.dll']) {
        if (!await File('${system32Dir.path}/$dll').exists()) {
          return false;
        }
      }
      for (final dll in ['d3d9.dll', 'd3d10core.dll', 'd3d11.dll', 'dxgi.dll']) {
        if (!await File('${syswow64Dir.path}/$dll').exists()) {
          return false;
        }
      }
    } else {
      for (final dll in ['d3d9.dll', 'd3d10core.dll', 'd3d11.dll', 'dxgi.dll']) {
        if (!await File('${system32Dir.path}/$dll').exists()) {
          return false;
        }
      }
    }
    return true;
  }

  Future<void> _copyDXVKFiles(String url, String arch, Directory system32Dir) async {
    final downloadDir = Directory('$prefixPath/downloads');
    await downloadDir.create(recursive: true);
    final downloadPath = '${downloadDir.path}/dxvk.tar.gz';

    onStatusUpdate('Downloading DXVK...');
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('Failed to download DXVK');
    }
    await File(downloadPath).writeAsBytes(response.bodyBytes);

    onStatusUpdate('Extracting DXVK...');
    final extractDir = '${downloadDir.path}/dxvk';
    await Directory(extractDir).create(recursive: true);
    
    final extractResult = await Process.run(
      'tar',
      ['-xzf', downloadPath, '-C', extractDir],
      environment: baseEnvironment,
    );

    if (extractResult.exitCode != 0) {
      throw Exception('Failed to extract DXVK');
    }

    // List contents of extracted directory for debugging
    final listResult = await Process.run('find', [extractDir]);
    LoggingService().log(
      'Extracted archive contents:\n${listResult.stdout}',
      level: LogLevel.info,
    );

    // Copy DLLs
    const dllFiles = ['d3d9.dll', 'd3d10core.dll', 'd3d11.dll', 'dxgi.dll'];

    for (final dll in dllFiles) {
      // Search recursively for the DLL
      final findResult = await Process.run(
        'find',
        [extractDir, '-name', dll],
        environment: baseEnvironment,
      );
      
      final paths = findResult.stdout.toString().trim().split('\n')
        .where((path) => path.isNotEmpty)
        .where((path) => path.contains(arch) || path.contains('x$arch'))
        .toList();

      if (paths.isEmpty) {
        LoggingService().log(
          'Could not find $dll for architecture $arch in extracted archive.',
          level: LogLevel.error,
        );
        continue;
      }

      final source = File(paths.first);
      final target = File('${system32Dir.path}/$dll');
      LoggingService().log(
        'Copying ${source.path} to ${target.path}',
        level: LogLevel.info,
      );
      await source.copy(target.path);
    }

    // Cleanup
    await File(downloadPath).delete();
    await Directory(extractDir).delete(recursive: true);

    onStatusUpdate('Successfully installed DXVK');
  }
} 