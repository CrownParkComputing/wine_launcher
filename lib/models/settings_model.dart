import 'package:shared_preferences/shared_preferences.dart';

class SettingsModel {
  List<String> gameSourceFolders;
  static const String _gameFoldersKey = 'game_source_folders';

  SettingsModel({
    this.gameSourceFolders = const [],
  });

  Future<void> saveGameFolders() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_gameFoldersKey, gameSourceFolders);
  }

  static Future<List<String>> loadGameFolders() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_gameFoldersKey) ?? [];
  }

  void addGameFolder(String path) {
    if (!gameSourceFolders.contains(path)) {
      gameSourceFolders.add(path);
      saveGameFolders();
    }
  }

  void removeGameFolder(String path) {
    gameSourceFolders.remove(path);
    saveGameFolders();
  }
} 