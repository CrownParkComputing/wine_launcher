import 'dart:io';  // Add this for File class
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wine_launcher/models/providers.dart';
import 'package:wine_launcher/models/game.dart';
import 'package:wine_launcher/models/wine_prefix.dart';
import 'package:wine_launcher/dialogs/add_game_dialog.dart';
import 'package:wine_launcher/services/logging_service.dart';
import 'package:path/path.dart' as p;

class GameLauncherPage extends StatefulWidget {
  const GameLauncherPage({super.key});

  @override
  State<GameLauncherPage> createState() => _GameLauncherPageState();
}

class _GameLauncherPageState extends State<GameLauncherPage> {
  final Map<String, bool> _expandedCategories = {};

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    if (!mounted) return;
    
    // Store context references before async operations
    final prefixProvider = Provider.of<PrefixProvider>(context, listen: false);
    final gameProvider = Provider.of<GameProvider>(context, listen: false);
    
    try {
      // Load prefixes first
      await prefixProvider.loadPrefixes(context);
      if (!mounted) return;
      
      // Then load games
      await gameProvider.scanGamesFolder(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showAddGameDialog() async {
    if (!mounted) return;
    
    // Store context references
    final prefixProvider = context.read<PrefixProvider>();
    final settings = context.read<SettingsProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    
    final prefixes = prefixProvider.prefixes;

    // Only show error if we really have no prefixes
    if (prefixes.isEmpty) {
      LoggingService().log(
        'No prefixes available when trying to add game',
        level: LogLevel.warning,
      );
      
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Please create a Wine prefix first in the Wine Setup tab'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Go to Wine Setup',
            textColor: Colors.white,
            onPressed: () {
              navigator.pushNamed('/wine_setup');
            },
          ),
        ),
      );
      return;
    }

    if (!mounted) return;
    final game = await showDialog<Game>(
      context: context,
      builder: (context) => Consumer<PrefixProvider>(
        builder: (context, prefixProvider, _) => AddGameDialog(
          availablePrefixes: prefixProvider.prefixes,
          gamesPath: settings.gamesPath,
        ),
      ),
    );

    if (game != null && mounted) {
      await context.read<GameProvider>().addGame(game);
    }
  }

  // Add a method to get unique categories
  Set<String> _getExistingCategories() {
    final gameProvider = context.read<GameProvider>();
    return gameProvider.games
        .map((game) => game.category)
        .where((category) => category.isNotEmpty)
        .toSet();
  }

  // Update the dialog to show category suggestions
  Future<void> _editGame(Game game) async {
    final prefixProvider = context.read<PrefixProvider>();
    final settings = context.read<SettingsProvider>();
    final categories = _getExistingCategories();
    
    // Make sure prefixes are loaded
    await prefixProvider.loadPrefixes(context);

    if (!mounted) return;

    final updatedGame = await showDialog<Game>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Consumer<PrefixProvider>(
        builder: (context, prefixProvider, _) => AddGameDialog(
          existingGame: game,
          availablePrefixes: prefixProvider.prefixes,
          gamesPath: settings.gamesPath,
          existingCategories: categories,  // Pass categories to dialog
        ),
      ),
    );

    if (updatedGame != null && mounted) {
      LoggingService().log(
        'Updating game ${game.name} to ${updatedGame.name}',
        level: LogLevel.info,
      );
      
      try {
        await context.read<GameProvider>().updateGame(updatedGame);
        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Game updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        LoggingService().log(
          'Error updating game: $e',
          level: LogLevel.error,
        );
        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update game: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteGame(Game game) async {
    LoggingService().log(
      'Attempting to delete game: ${game.name}',
      level: LogLevel.info,
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Game'),
        content: Text('Are you sure you want to delete "${game.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      LoggingService().log(
        'Deleting game: ${game.name}',
        level: LogLevel.info,
      );
      await context.read<GameProvider>().removeGame(game.id);
    }
  }

  Future<void> _launchGame(Game game) async {
    if (!game.hasPrefix) {
      LoggingService().log(
        'Game ${game.name} has no prefix, showing prefix selector',
        level: LogLevel.info,
      );
      await _selectPrefixForGame(game);
      return;
    }

    try {
      LoggingService().log(
        'Launching game: ${game.name} with exe: ${game.exePath}',
        level: LogLevel.info,
      );

      final prefix = context.read<PrefixProvider>().prefixes
          .firstWhere((p) => p.path == game.prefixPath);
      await prefix.runExe(game.exePath);
    } catch (e) {
      LoggingService().log(
        'Failed to launch game ${game.name}: $e',
        level: LogLevel.error,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to launch game: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _selectPrefixForGame(Game game) async {
    final prefixes = context.read<PrefixProvider>().prefixes;
    
    if (prefixes.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please create a Wine prefix first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Find currently selected prefix if any
    WinePrefix? currentPrefix;
    if (game.hasPrefix) {
      try {
        currentPrefix = prefixes.firstWhere(
          (p) => p.path == game.prefixPath,
        );
      } catch (e) {
        LoggingService().log(
          'Previously selected prefix not found: ${game.prefixPath}',
          level: LogLevel.warning,
        );
      }
    }

    final prefix = await showDialog<WinePrefix>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Wine Prefix'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: prefixes.length,
            itemBuilder: (context, index) {
              final prefix = prefixes[index];
              final isSelected = prefix.path == currentPrefix?.path;
              
              return ListTile(
                leading: Icon(
                  prefix.isProton ? Icons.sports_esports : Icons.wine_bar,
                  color: prefix.isProton ? Colors.purple : Colors.blue,
                ),
                title: Text(prefix.name),
                subtitle: Text(
                  prefix.isProton ? 'Proton' : 'Wine',
                  style: TextStyle(
                    color: prefix.isProton ? Colors.purple.shade700 : Colors.blue.shade700,
                  ),
                ),
                trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.green) : null,
                selected: isSelected,
                onTap: () => Navigator.pop(context, prefix),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (prefix != null && mounted) {
      final updatedGame = game.copyWith(
        prefixPath: prefix.path,
        isProton: prefix.isProton,
      );
      
      LoggingService().log(
        'Updating game ${game.name} with prefix ${prefix.name}',
        level: LogLevel.info,
      );
      
      await context.read<GameProvider>().updateGame(updatedGame);
    }
  }

  Future<void> _openGameFolder(Game game) async {
    if (!mounted) return;
    
    final settings = context.read<SettingsProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final gameDir = Directory(p.join(settings.gamesPath, game.name));
    
    try {
      if (!await gameDir.exists()) {
        await gameDir.create(recursive: true);
      }

      // Open folder in system file manager
      final result = await Process.run('xdg-open', [gameDir.path]);
      if (result.exitCode != 0) {
        throw Exception('Failed to open folder: ${result.stderr}');
      }
      
      LoggingService().log(
        'Opened game folder: ${gameDir.path}',
        level: LogLevel.info,
      );
    } catch (e) {
      LoggingService().log(
        'Error opening game folder: $e',
        level: LogLevel.error,
      );
      
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to open game folder: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<GameProvider, SettingsProvider, PrefixProvider>(
      builder: (context, gameProvider, settingsProvider, prefixProvider, _) {
        final games = gameProvider.games;
        final gamesPath = settingsProvider.gamesPath;

        if (gamesPath.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.folder_off, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  'Games folder not set',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.settings),
                  label: const Text('Open Settings'),
                  onPressed: () {
                    Navigator.pushNamed(context, '/settings');
                  },
                ),
              ],
            ),
          );
        }

        if (games.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.sports_esports_outlined, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  'No games found',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Add games by creating folders in:\n${settingsProvider.gamesPath}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          );
        }

        // Group games by category with better Uncategorized handling
        final gamesByCategory = <String, List<Game>>{};
        // First add all categorized games
        for (final game in games) {
          if (game.category.isNotEmpty) {
            gamesByCategory.putIfAbsent(game.category, () => []).add(game);
          }
        }
        // Then add uncategorized games at the end
        final uncategorizedGames = games.where((game) => game.category.isEmpty).toList();
        if (uncategorizedGames.isNotEmpty) {
          gamesByCategory['Uncategorized'] = uncategorizedGames;
        }

        return Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Add Game button
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Add Game'),
                  onPressed: () => _showAddGameDialog(),
                ),
              ),

              // Game categories
              ...gamesByCategory.entries.map((entry) {
                final category = entry.key;
                final categoryGames = entry.value;

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ExpansionTile(
                    initiallyExpanded: _expandedCategories[category] ?? true,
                    onExpansionChanged: (expanded) {
                      setState(() {
                        _expandedCategories[category] = expanded;
                      });
                    },
                    title: Text(
                      category,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    children: categoryGames.map((game) {
                      final isUncategorized = category == 'Uncategorized';
                      
                      return ListTile(
                        leading: game.coverImagePath != null
                            ? Image.file(
                                File(game.coverImagePath!),
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover,
                              )
                            : const Icon(Icons.games),
                        title: Text(game.name),
                        subtitle: game.hasPrefix
                            ? Builder(
                                builder: (context) {
                                  final prefixes = context.read<PrefixProvider>().prefixes;
                                  final prefix = prefixes.firstWhere(
                                    (p) => p.path == game.prefixPath,
                                    orElse: () => WinePrefix(
                                      context: context,
                                      name: 'Unknown',
                                      path: game.prefixPath!,
                                      isProton: game.isProton ?? false,
                                      sourceUrl: '',
                                      is64Bit: true,
                                      onStatusUpdate: (_, {bool isError = false}) {},
                                    ),
                                  );
                                  return Text(
                                    '${prefix.name} (${game.isProton! ? 'Proton' : 'Wine'})',
                                    style: TextStyle(
                                      color: game.isProton!
                                          ? Colors.purple.shade700
                                          : Colors.blue.shade700,
                                    ),
                                  );
                                },
                              )
                            : const Text(
                                'Configure prefix in Settings',
                                style: TextStyle(color: Colors.orange),
                              ),
                        trailing: SizedBox(
                          width: 250,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.folder),
                                onPressed: () => _openGameFolder(game),
                                tooltip: 'Open Game Folder',
                                style: IconButton.styleFrom(
                                  foregroundColor: isUncategorized ? Colors.white : null,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () => _editGame(game),
                                tooltip: 'Edit Game',
                                style: IconButton.styleFrom(
                                  foregroundColor: isUncategorized ? Colors.white : null,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () => _deleteGame(game),
                                tooltip: 'Delete Game',
                                style: IconButton.styleFrom(
                                  foregroundColor: isUncategorized ? Colors.white : null,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.play_arrow, size: 20),
                                  label: const Text('Play', style: TextStyle(fontSize: 13)),
                                  onPressed: game.hasPrefix ? () => _launchGame(game) : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isUncategorized ? Colors.grey.shade800 : null,
                                    disabledBackgroundColor: isUncategorized ? Colors.grey.shade900 : Colors.grey.shade300,
                                    foregroundColor: isUncategorized ? Colors.white : null,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
} 