import 'dart:io';
import 'package:path/path.dart' as path;
import '../models/settings_model.dart';
import 'package:wine_launcher/services/logging_service.dart';

class GameScanner {
  static const _excludedFolders = ['wine_launcher', '.wine', 'wine-launcher', 'wine launcher'];

  static Future<List<String>> scanForGames() async {
    List<String> games = [];
    List<String> sourceFolders = await SettingsModel.loadGameFolders();
    
    for (String sourceFolder in sourceFolders) {
      try {
        final directory = Directory(sourceFolder);
        if (await directory.exists()) {
          await for (final entity in directory.list()) {
            if (entity is Directory) {
              String folderName = path.basename(entity.path);
              String fullPath = entity.path;
              
              // Check for excluded patterns in both folder name and full path
              bool shouldExclude = _excludedFolders.any((pattern) =>
                  folderName.toLowerCase().contains(pattern.toLowerCase()) ||
                  fullPath.toLowerCase().contains(pattern.toLowerCase()));
                  
              if (!shouldExclude) {
                games.add(fullPath);
              }
            }
          }
        }
      } catch (e) {
        LoggingService().log('Error scanning directory $sourceFolder: $e', level: LogLevel.error);
      }
    }
    
    // Debug log the found games
    LoggingService().log('Found games: ${games.join(', ')}', level: LogLevel.debug);
    
    return games;
  }
}
