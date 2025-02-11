import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../models/game.dart';
import '../models/providers.dart' as models;
import '../dialogs/add_game_dialog.dart';

class GamesPage extends StatelessWidget {
  const GamesPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final gameProvider = Provider.of<GameProvider>(context);
    final List<Game> games = gameProvider.games;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Games'),
      ),
      body: ListView.builder(
        itemCount: games.length,
        itemBuilder: (context, index) {
          final Game game = games[index];
          return ListTile(
            title: Text(game.name),
            subtitle: Text(game.exePath),
            trailing: IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () {
                gameProvider.removeGame(game);
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final game = await showDialog<Game>(
            context: context,
            builder: (context) {
              final prefixProvider = Provider.of<models.PrefixProvider>(context, listen: false);
              final settingsProvider = Provider.of<models.SettingsProvider>(context, listen: false);
              return AddGameDialog(
                availablePrefixes: prefixProvider.prefixes,
                gamesPath: settingsProvider.gamesPath,
              );
            },
          );
          
          if (game != null) {
            gameProvider.addGame(game);
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
