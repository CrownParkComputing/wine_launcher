import 'dart:io';
import 'package:wine_launcher/services/logging_service.dart';

class DownloadService {
  static final DownloadService _instance = DownloadService._internal();
  factory DownloadService() => _instance;
  DownloadService._internal();

  Future<void> downloadFile(String url, String destination) async {
    try {
      LoggingService().log('Starting download from: $url', level: LogLevel.info);
      
      final response = await HttpClient().getUrl(Uri.parse(url));
      final httpResponse = await response.close();
      
      final file = File(destination);
      await file.create(recursive: true);
      await httpResponse.pipe(file.openWrite());
      
      LoggingService().log('Download completed: $destination', level: LogLevel.info);
    } catch (e) {
      LoggingService().log('Download failed: $e', level: LogLevel.error);
      rethrow;
    }
  }

  Future<bool> verifyDownload(String filePath, int expectedSize) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        LoggingService().log(
          'File not found: $filePath',
          level: LogLevel.error,
        );
        return false;
      }
      
      final size = await file.length();
      if (size != expectedSize) {
        LoggingService().log(
          'File size mismatch: expected $expectedSize bytes, got $size bytes',
          level: LogLevel.error,
        );
        return false;
      }
      
      LoggingService().log(
        'File verification successful: $filePath',
        level: LogLevel.info,
      );
      return true;
    } catch (e) {
      LoggingService().log(
        'File verification failed: $e',
        level: LogLevel.error,
      );
      return false;
    }
  }

  Future<void> deleteFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        LoggingService().log(
          'File deleted: $filePath',
          level: LogLevel.info,
        );
      }
    } catch (e) {
      LoggingService().log(
        'Failed to delete file: $e',
        level: LogLevel.error,
      );
      rethrow;
    }
  }

  static Future<void> extractArchive(
    String filePath,
    String extractDir,
    Function(String) onStatus,
  ) async {
    // Move extraction logic here
  }
} 