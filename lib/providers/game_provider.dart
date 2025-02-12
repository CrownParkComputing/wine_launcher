import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/game.dart';
import '../services/logging_service.dart';

class GameProvider with ChangeNotifier {
  final List<Game> _games = [];

  List<Game> get games => _games;

  void addGame(Game game) {
    // Validate game path before adding
    if (!_isValidGamePath(game.exePath)) {
      LoggingService().log(
        'Attempted to add invalid game path: ${game.exePath}',
        level: LogLevel.warning,
      );
      return;
    }
    
    _games.add(game);
    notifyListeners();
  }

  void removeGame(Game game) {
    _games.remove(game);
    notifyListeners();
  }

  bool _isValidGamePath(String path) {
    // Check if path contains any excluded patterns
    const excludedPatterns = ['wine_launcher', 'wine-launcher', 'wine launcher'];
    return !excludedPatterns.any((pattern) => 
      path.toLowerCase().contains(pattern.toLowerCase())
    );
  }
}
