import 'dart:io';
import 'package:wine_launcher/services/wine_service_base.dart';
import 'package:wine_launcher/services/logging_service.dart';
import 'package:http/http.dart' as http;

class Vkd3dService extends WineServiceBase {
  static const vkd3dUrl = 'https://github.com/HansKristian-Work/vkd3d-proton/releases/download/v2.11/vkd3d-proton-2.11.tar.zst';

  Vkd3dService({
    required super.prefixPath,
    required super.is64Bit,
    required super.onStatusUpdate,
  });

  Future<void> install() async {
    try {
      // Create directories
      final system32Dir = Directory('$prefixPath/drive_c/windows/system32');
      final syswow64Dir = Directory('$prefixPath/drive_c/windows/syswow64');
      await system32Dir.create(recursive: true);
      if (is64Bit) {
        await syswow64Dir.create(recursive: true);
      }

      // Download VKD3D
      final downloadDir = Directory('$prefixPath/downloads');
      await downloadDir.create(recursive: true);
      final downloadPath = '${downloadDir.path}/vkd3d-proton.tar.zst';

      onStatusUpdate('Downloading VKD3D...');
      final response = await http.get(Uri.parse(vkd3dUrl));
      if (response.statusCode != 200) {
        throw Exception('Failed to download VKD3D');
      }
      await File(downloadPath).writeAsBytes(response.bodyBytes);

      // Extract files
      onStatusUpdate('Extracting VKD3D...');
      final extractDir = '${downloadDir.path}/vkd3d';
      await Directory(extractDir).create(recursive: true);

      // First decompress zst
      final decompressResult = await Process.run(
        'zstd',
        ['-d', downloadPath, '-o', '$downloadPath.tar'],
      );

      if (decompressResult.exitCode != 0) {
        throw Exception('Failed to decompress VKD3D archive');
      }

      // Then extract tar
      final extractResult = await Process.run(
        'tar',
        ['-xf', '$downloadPath.tar', '-C', extractDir],
      );

      if (extractResult.exitCode != 0) {
        throw Exception('Failed to extract VKD3D archive');
      }

      // Copy DLLs
      const dllFiles = {
        'x32': ['d3d12.dll', 'd3d12core.dll'],
        'x64': ['d3d12.dll', 'd3d12core.dll'],
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
      await File('$downloadPath.tar').delete();
      await Directory(extractDir).delete(recursive: true);

      onStatusUpdate('Successfully installed VKD3D');
    } catch (e) {
      LoggingService().log('Error installing VKD3D: $e', level: LogLevel.error);
      onStatusUpdate('Error installing VKD3D: $e', isError: true);
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
} 