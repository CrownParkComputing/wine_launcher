import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:wine_launcher/services/logging_service.dart';

class WineService {
  static Future<String?> findWineBinary(String baseDir, bool isProton) async {
    final wineBinaryNames = isProton ? ['proton', 'wine64', 'wine'] : ['wine64', 'wine'];
    
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

  static Future<void> initializePrefix(String prefixPath, bool is64Bit, String binPath) async {
    final env = {
      'WINEPREFIX': prefixPath,
      'WINEARCH': is64Bit ? 'win64' : 'win32',
      'PATH': '${p.dirname(binPath)}:${Platform.environment['PATH']}',
    };

    try {
      LoggingService().log(
        'Initializing prefix:\n'
        'Path: $prefixPath\n'
        'Architecture: ${is64Bit ? "64-bit" : "32-bit"}\n'
        'Binary: $binPath',
        level: LogLevel.info,
      );

      final result = await Process.run(
        'wineboot',
        ['-i'],
        environment: env,
        runInShell: true,
      );

      if (result.exitCode != 0) {
        throw Exception('Failed to initialize prefix: ${result.stderr}');
      }

      LoggingService().log('Prefix initialized successfully', level: LogLevel.info);
    } catch (e) {
      LoggingService().log('Error initializing prefix: $e', level: LogLevel.error);
      rethrow;
    }
  }

  static Future<bool> verifyPrefixStructure(String prefixPath) async {
    final requiredFiles = ['system.reg', 'user.reg', 'userdef.reg'];
    
    try {
      for (final file in requiredFiles) {
        final filePath = p.join(prefixPath, file);
        if (!await File(filePath).exists()) {
          LoggingService().log(
            'Missing required file: $file',
            level: LogLevel.error,
          );
          return false;
        }
      }
      return true;
    } catch (e) {
      LoggingService().log(
        'Error verifying prefix structure: $e',
        level: LogLevel.error,
      );
      return false;
    }
  }
} 