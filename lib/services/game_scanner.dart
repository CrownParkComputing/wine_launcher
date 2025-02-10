import 'dart:io';
import 'package:path/path.dart' as path;
import '../models/settings_model.dart';
import 'package:wine_launcher/services/logging_service.dart';

class GameScanner {
  static const _excludedFolders = ['wine_launcher', '.wine'];

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
              if (!_excludedFolders.contains(folderName)) {
                games.add(entity.path);
              }
            }
          }
        }
      } catch (e) {
        LoggingService().log('Error scanning directory $sourceFolder: $e', level: LogLevel.error);
      }
    }
    
    return games;
  }
} 