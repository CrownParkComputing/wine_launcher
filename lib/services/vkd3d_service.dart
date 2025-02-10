import 'dart:io';
import 'package:wine_launcher/services/wine_service_base.dart';
import 'package:wine_launcher/services/logging_service.dart';
import 'package:http/http.dart' as http;
import 'package:wine_launcher/models/providers.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class Vkd3dService extends WineServiceBase {
  static const vkd3dUrl = 'https://github.com/HansKristian-Work/vkd3d-proton/releases/download/v2.11/vkd3d-proton-2.11.tar.zst';

  late final Directory system32Dir;
  late final Directory syswow64Dir;
  final SettingsProvider settingsProvider;

  Vkd3dService({
    required String prefixPath,
    required bool is64Bit,
    required Function(String, {bool isError}) onStatusUpdate,
    required BuildContext context,
  }) : settingsProvider = Provider.of<SettingsProvider>(context, listen: false),
      super(
        prefixPath: prefixPath,
        is64Bit: is64Bit,
        onStatusUpdate: onStatusUpdate,
      ) {
    system32Dir = Directory('$prefixPath/drive_c/windows/system32');
    syswow64Dir = Directory('$prefixPath/drive_c/windows/syswow64');
  }

  Future<void> install() async {
    try {
      onStatusUpdate('Installing VKD3D...');
      
      final addon = settingsProvider.addons.firstWhere((a) => a.type == 'vkd3d');
      
      await _copyVKD3DFiles(addon.url, is64Bit ? 'x64' : 'x32', system32Dir);
      
      // Configure DLL overrides
      final regFile = File('$prefixPath/user.reg');
      var content = await regFile.readAsString();
      
      // Add DLL overrides
      if (!content.contains('[Software\\\\Wine\\\\DllOverrides]')) {
        content += '\n\n[Software\\\\Wine\\\\DllOverrides]';
      }
      content += '\n"d3d12"="native,builtin"';
      content += '\n"d3d12core"="native,builtin"';
      
      // Add VKD3D settings
      if (!content.contains('[Software\\\\Wine\\\\VKD3D]')) {
        content += '\n\n[Software\\\\Wine\\\\VKD3D]';
      }
      content += '\n"debug"="none"';
      content += '\n"feature_level"="12_2"';
      content += '\n"async_pipeline_compilation"="dword:00000001"';
      content += '\n"pipeline_library_size"="dword:00100000"';
      content += '\n"gpu_descriptor_heap_size"="dword:00020000"';
      content += '\n"pipeline_library_path"="$prefixPath/drive_c/vkd3d-cache"';
      
      await regFile.writeAsString(content);
      
      // Create cache directory
      final cacheDir = Directory('$prefixPath/drive_c/vkd3d-cache');
      await cacheDir.create(recursive: true);
      
      // Reload registry
      await Process.run('wineboot', ['-u'], 
        environment: {
          'WINEPREFIX': prefixPath,
        },
      );

      onStatusUpdate('VKD3D installation complete');
    } catch (e) {
      onStatusUpdate('Failed to install VKD3D: $e', isError: true);
      rethrow;
    }
  }

  Future<void> uninstall() async {
    try {
      final dllFiles = is64Bit ? [
        'system32/d3d12.dll',
        'system32/d3d12core.dll',
        'syswow64/d3d12.dll',
        'syswow64/d3d12core.dll',
      ] : [
        'system32/d3d12.dll',
        'system32/d3d12core.dll',
      ];

      for (final dll in dllFiles) {
        final file = File('$prefixPath/drive_c/windows/$dll');
        if (await file.exists()) {
          await file.delete();
        }
      }

      onStatusUpdate('Successfully uninstalled VKD3D');
    } catch (e) {
      LoggingService().log('Error uninstalling VKD3D: $e', level: LogLevel.error);
      onStatusUpdate('Error uninstalling VKD3D: $e', isError: true);
    }
  }

  Future<void> _copyVKD3DFiles(String url, String arch, Directory system32Dir) async {
    final downloadDir = Directory('$prefixPath/downloads');
    await downloadDir.create(recursive: true);
    final downloadPath = '${downloadDir.path}/vkd3d.tar.zst';
    final tarPath = '${downloadDir.path}/vkd3d.tar';

    onStatusUpdate('Downloading VKD3D...');
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('Failed to download VKD3D');
    }
    await File(downloadPath).writeAsBytes(response.bodyBytes);

    onStatusUpdate('Extracting VKD3D...');
    final extractDir = '${downloadDir.path}/vkd3d';
    await Directory(extractDir).create(recursive: true);
    
    // First decompress zst to tar
    final decompressResult = await Process.run(
      'zstd',
      ['-d', downloadPath, '-o', tarPath],
      environment: baseEnvironment,
    );

    if (decompressResult.exitCode != 0) {
      throw Exception('Failed to decompress VKD3D: ${decompressResult.stderr}');
    }

    // Then extract tar
    final extractResult = await Process.run(
      'tar',
      ['-xf', tarPath, '-C', extractDir],
      environment: baseEnvironment,
    );

    if (extractResult.exitCode != 0) {
      throw Exception('Failed to extract VKD3D: ${extractResult.stderr}');
    }

    // List contents of extracted directory for debugging
    final listResult = await Process.run('find', [extractDir]);
    LoggingService().log(
      'Extracted archive contents:\n${listResult.stdout}',
      level: LogLevel.info,
    );

    // Copy DLLs
    const dllFiles = ['d3d12.dll', 'd3d12core.dll'];

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
    await File(tarPath).delete();
    await Directory(extractDir).delete(recursive: true);
  }
} 