import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:wine_launcher/models/game.dart';
import 'package:wine_launcher/services/prefix_service.dart';

class GameService {
  final PrefixService _prefixService;

  GameService(this._prefixService);

  Future<void> addGame(Game game) async {
    // Validate required fields
    if (game.name.isEmpty) {
      throw Exception('Game name cannot be empty');
    }
    if (game.exePath.isEmpty) {
      throw Exception('Executable path cannot be empty');
    }

    // Verify executable exists
    final exeFile = File(game.exePath);
    if (!await exeFile.exists()) {
      throw Exception('Executable file does not exist');
    }

    // If game has prefix, verify it exists
    if (game.hasPrefix) {
      final prefix = await _prefixService.getPrefixByPath(game.prefixPath!);
      if (prefix == null) {
        throw Exception('Associated Wine prefix not found');
      }
    }

    // Create game directory if it doesn't exist
    final gameDir = Directory(p.join(_prefixService.gamesPath, game.name));
    if (!await gameDir.exists()) {
      await gameDir.create(recursive: true);
    }

    // Save game configuration
    final configFile = File(p.join(gameDir.path, 'game.json'));
    await configFile.writeAsString(jsonEncode(game.toJson()));
  }

  Future<void> removeGame(String gameId) async {
    // Implementation
  }

  Future<List<Game>> getGames() async {
    // Implementation
    return [];
  }

  Future<void> launchGame(String gameId) async {
    // Implementation
  }
}
