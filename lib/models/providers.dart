import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as p;
import 'package:wine_launcher/models/prefix_url.dart';
import 'package:wine_launcher/models/wine_prefix.dart';
import 'package:wine_launcher/services/logging_service.dart';
import 'package:wine_launcher/models/game.dart';
import 'package:wine_launcher/main.dart';  // Add this import
import 'package:wine_launcher/models/wine_addon.dart';

class ThemeProvider with ChangeNotifier {
  static const appDirName = '.wine_launcher';
  static const themeFileName = 'theme.json';
  late final Directory _appDir;
  late final File _themeFile;
  bool _isDarkMode = false;

  ThemeProvider() {
    _initializeThemeDirectory();
  }

  Future<void> _initializeThemeDirectory() async {
    final homeDir = Platform.environment['HOME'];
    if (homeDir == null) {
      LoggingService().log(
        'Could not find home directory',
        level: LogLevel.error,
      );
      return;
    }

    _appDir = Directory(p.join(homeDir, appDirName));
    _themeFile = File(p.join(_appDir.path, themeFileName));

    try {
      if (!await _appDir.exists()) {
        await _appDir.create();
      }

      // Check if we need to migrate from SharedPreferences
      if (!await _themeFile.exists()) {
        await _migrateFromSharedPreferences();
      }

      if (await _themeFile.exists()) {
        final jsonStr = await _themeFile.readAsString();
        final json = jsonDecode(jsonStr);
        _isDarkMode = json['isDarkMode'] ?? false;
        notifyListeners();
      }
    } catch (e) {
      LoggingService().log(
        'Error loading theme settings: $e',
        level: LogLevel.error,
      );
    }
  }

  Future<void> _migrateFromSharedPreferences() async {
    try {
      LoggingService().log(
        'Migrating theme settings from SharedPreferences...',
        level: LogLevel.info,
      );

      final prefs = await SharedPreferences.getInstance();
      _isDarkMode = prefs.getBool('isDarkMode') ?? false;

      // Save to new file
      await _themeFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert({'isDarkMode': _isDarkMode}),
      );

      // Clear old setting
      await prefs.remove('isDarkMode');

      LoggingService().log(
        'Successfully migrated theme settings to ${_themeFile.path}',
        level: LogLevel.info,
      );
    } catch (e) {
      LoggingService().log(
        'Error migrating theme settings: $e',
        level: LogLevel.error,
      );
    }
  }

  bool get isDarkMode => _isDarkMode;
  ThemeMode get themeMode => isDarkMode ? ThemeMode.dark : ThemeMode.light;

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    try {
      await _themeFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert({'isDarkMode': _isDarkMode}),
      );
    } catch (e) {
      LoggingService().log(
        'Error saving theme settings: $e',
        level: LogLevel.error,
      );
    }
    notifyListeners();
  }
}

class SettingsProvider extends ChangeNotifier {
  static const appDirName = '.wine_launcher';
  static const settingsFileName = 'settings.json';
  late final Directory _appDir;
  late final File _settingsFile;

  static const defaultDxvkAsyncUrl = 'https://github.com/Sporif/dxvk-async/releases/download/latest/dxvk-async-1.10.3.tar.gz';
  static const defaultVcRedistPath = '/home/jon/Downloads/Visual-C-Runtimes-All-in-One-Nov-2024/vcredist2015_2017_2019_2022_x64.exe';
  static const defaultVkd3dUrl = 'https://github.com/HansKristian-Work/vkd3d-proton/releases/download/v2.11/vkd3d-proton-2.11.tar.zst';

  // Add default base path in user's home directory
  static String get defaultBasePath {
    final homeDir = Platform.environment['HOME'];
    if (homeDir == null) return '';
    return p.join(homeDir, 'Games', 'wine_launcher');
  }

  static String get defaultGamesPath {
    final homeDir = Platform.environment['HOME'];
    if (homeDir == null) return '';
    return p.join(homeDir, 'Games');
  }

  SettingsProvider() {
    _initializeAppDirectory();
  }

  Future<void> _initializeAppDirectory() async {
    final homeDir = Platform.environment['HOME'];
    if (homeDir == null) {
      LoggingService().log(
        'Could not find home directory',
        level: LogLevel.error,
      );
      return;
    }

    _appDir = Directory(p.join(homeDir, appDirName));
    _settingsFile = File(p.join(_appDir.path, settingsFileName));

    try {
      // Create directory if it doesn't exist
      if (!await _appDir.exists()) {
        await _appDir.create();
        final logger = LoggingService();
        logger.log(
          'Created app directory: ${_appDir.path}',
          level: LogLevel.info,
        );
      }

      // Check if we need to migrate from SharedPreferences
      if (!await _settingsFile.exists()) {
        await _migrateFromSharedPreferences();
      }

      await _loadSettings();
    } catch (e) {
      final logger = LoggingService();
      logger.log(
        'Error initializing app directory: $e',
        level: LogLevel.error,
      );
    }
  }

  Future<void> _migrateFromSharedPreferences() async {
    try {
      LoggingService().log(
        'Migrating settings from SharedPreferences...',
        level: LogLevel.info,
      );

      final prefs = await SharedPreferences.getInstance();
      
      // Migrate settings
      _defaultWinePrefixPath = prefs.getString('defaultWinePrefixPath') ?? '';
      _gamesPath = prefs.getString('gamesPath') ?? '';
      _dxvkAsyncUrl = prefs.getString('dxvkAsyncUrl') ?? defaultDxvkAsyncUrl;
      _vkd3dUrl = prefs.getString('vkd3dUrl') ?? defaultVkd3dUrl;
      _vcRedistPath = prefs.getString('vcRedistPath') ?? defaultVcRedistPath;

      // Migrate prefix URLs
      final urlsJson = prefs.getStringList('prefixUrls') ?? [];
      _prefixUrls = urlsJson.map((json) {
        try {
          return PrefixUrl.fromJson(jsonDecode(json));
        } catch (e) {
          final logger = LoggingService();
          logger.log(
            'Error parsing legacy prefix URL: $e\nJSON: $json',
            level: LogLevel.error,
          );
          return const PrefixUrl(
            url: '',
            isProton: false,
            name: 'Invalid Entry',
          );
        }
      }).where((prefix) => prefix.url.isNotEmpty).toList();

      // Migrate addons with null safety
      final addonsList = prefs.getStringList('addons');
      _addons = addonsList
          ?.map((a) => WineAddon.fromJson(jsonDecode(a) as Map<String, dynamic>))
          .toList() ?? [];

      // Save migrated settings to file
      await _saveSettings();

      // Clear old SharedPreferences
      await prefs.clear();

      LoggingService().log(
        'Successfully migrated settings to ${_settingsFile.path}',
        level: LogLevel.info,
      );
    } catch (e) {
      final logger = LoggingService();
      logger.log(
        'Error migrating settings: $e',
        level: LogLevel.error,
      );
    }
  }

  Future<void> _loadSettings() async {
    try {
      if (await _settingsFile.exists()) {
        final jsonStr = await _settingsFile.readAsString();
        final json = jsonDecode(jsonStr);
        
        _defaultWinePrefixPath = json['defaultWinePrefixPath'] ?? '';
        _gamesPath = json['gamesPath'] ?? '';
        _prefixUrls = _loadPrefixUrls(json['prefixUrls'] ?? []);
        _dxvkAsyncUrl = json['dxvkAsyncUrl'] ?? defaultDxvkAsyncUrl;
        _vkd3dUrl = json['vkd3dUrl'] ?? defaultVkd3dUrl;
        _vcRedistPath = json['vcRedistPath'] ?? defaultVcRedistPath;
        _addons = (json['addons'] as List?)
            ?.map((a) => WineAddon.fromJson(a as Map<String, dynamic>))
            .toList() ?? [];
        
        notifyListeners();
      } else {
        // Create default settings file
        await _saveSettings();
      }
    } catch (e) {
      final logger = LoggingService();
      logger.log(
        'Error loading settings: $e',
        level: LogLevel.error,
      );
    }
  }

  Future<void> _saveSettings() async {
    try {
      final json = {
        'defaultWinePrefixPath': _defaultWinePrefixPath,
        'gamesPath': _gamesPath,
        'prefixUrls': _encodePrefixUrls(_prefixUrls),
        'dxvkAsyncUrl': _dxvkAsyncUrl,
        'vkd3dUrl': _vkd3dUrl,
        'vcRedistPath': _vcRedistPath,
        'addons': _addons.map((a) => a.toJson()).toList(),
      };

      await _settingsFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert(json),
      );
    } catch (e) {
      final logger = LoggingService();
      logger.log(
        'Error saving settings: $e',
        level: LogLevel.error,
      );
    }
  }

  List<PrefixUrl> _loadPrefixUrls(List<dynamic> urlsJson) {
    return urlsJson.map((json) {
      try {
        if (json is Map<String, dynamic>) {
          return PrefixUrl(
            url: json['url'] as String,
            isProton: json['isProton'] as bool,
            name: json['name'] as String,
          );
        }
        return PrefixUrl.fromJson(json);
      } catch (e) {
        LoggingService().log(
          'Error parsing prefix URL: $e\nJSON: $json',
          level: LogLevel.error,
        );
        return const PrefixUrl(
          url: '',
          isProton: false,
          name: 'Invalid Entry',
        );
      }
    }).where((prefix) => prefix.url.isNotEmpty).toList();
  }

  String _defaultWinePrefixPath = '';
  String get defaultWinePrefixPath => _defaultWinePrefixPath.isEmpty 
    ? defaultBasePath 
    : _defaultWinePrefixPath;
  set defaultWinePrefixPath(String value) {
    _defaultWinePrefixPath = value;
    
    // Create directory if it doesn't exist
    try {
      final dir = Directory(value);
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
        LoggingService().log(
          'Created prefix directory: $value',
          level: LogLevel.info,
        );
      }
    } catch (e) {
      LoggingService().log(
        'Error creating prefix directory: $e',
        level: LogLevel.error,
      );
    }

    _saveSettings();
    notifyListeners();
  }

  List<PrefixUrl> _prefixUrls = [];
  List<PrefixUrl> get prefixUrls => _prefixUrls;

  String _dxvkAsyncUrl = defaultDxvkAsyncUrl;
  String get dxvkAsyncUrl => _dxvkAsyncUrl;
  set dxvkAsyncUrl(String value) {
    _dxvkAsyncUrl = value;
    _saveSettings();
    notifyListeners();
  }

  String _vkd3dUrl = defaultVkd3dUrl;
  String get vkd3dUrl => _vkd3dUrl;
  set vkd3dUrl(String value) {
    _vkd3dUrl = value;
    _saveSettings();
    notifyListeners();
  }

  String _vcRedistPath = defaultVcRedistPath;
  String get vcRedistPath => _vcRedistPath;
  set vcRedistPath(String value) {
    _vcRedistPath = value;
    _saveSettings();
    notifyListeners();
  }

  String _gamesPath = '';
  String get gamesPath => _gamesPath.isEmpty ? defaultGamesPath : _gamesPath;
  set gamesPath(String value) {
    _gamesPath = value;
    try {
      final dir = Directory(value);
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
        LoggingService().log(
          'Created games directory: $value',
          level: LogLevel.info,
        );
      }
    } catch (e) {
      LoggingService().log(
        'Error creating games directory: $e',
        level: LogLevel.error,
      );
    }
    _saveSettings();
    notifyListeners();
  }

  void addPrefixUrl(String url, bool isProton) {
    final prefixUrl = PrefixUrl(
      url: url,
      isProton: isProton,
      name: isProton ? 'Proton' : 'Wine',
    );
    _prefixUrls.add(prefixUrl);
    _savePrefixUrls();
    notifyListeners();
  }

  void removePrefixUrl(int index) {
    if (index >= 0 && index < _prefixUrls.length) {
      _prefixUrls.removeAt(index);
      _savePrefixUrls();
      notifyListeners();
    }
  }

  void updatePrefixUrl(int index, String url, bool isProton) {
    if (index >= 0 && index < _prefixUrls.length) {
      _prefixUrls[index] = PrefixUrl(
        url: url,
        isProton: isProton,
        name: isProton ? 'Proton' : 'Wine',
      );
      _saveSettings();
      notifyListeners();
    }
  }

  void _savePrefixUrls() {
    _saveSettings();
  }

  List<dynamic> _encodePrefixUrls(List<PrefixUrl> urls) {
    return urls.map((url) => url.toJson()).toList();
  }

  List<WineAddon> _addons = [];
  List<WineAddon> get addons => List.unmodifiable(_addons);

  void addAddon(WineAddon addon) {
    _addons.add(addon);
    _saveSettings();
    notifyListeners();
  }

  void removeAddon(WineAddon addon) {
    _addons.removeWhere((a) => a.url == addon.url);
    _saveSettings();
    notifyListeners();
  }

  void updateAddon(WineAddon oldAddon, WineAddon newAddon) {
    final index = _addons.indexWhere((a) => a.url == oldAddon.url);
    if (index != -1) {
      _addons[index] = newAddon;
      _saveSettings();
      notifyListeners();
    }
  }
}

class GameProvider extends ChangeNotifier {
  final List<Game> _games = [];
  List<Game> get games => List.unmodifiable(_games);
  
  // Add a method to get games by category
  Map<String, List<Game>> get gamesByCategory {
    final map = <String, List<Game>>{};
    for (final game in _games) {
      final category = game.category.isEmpty ? 'Uncategorized' : game.category;
      map.putIfAbsent(category, () => []).add(game);
    }
    return map;
  }

  Future<void> scanGamesFolder(BuildContext context) async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final gamesPath = settings.gamesPath;

    if (gamesPath.isEmpty) {
      LoggingService().log('Games path is empty', level: LogLevel.warning);
      return;
    }

    try {
      final dir = Directory(gamesPath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      // Store existing games by name to preserve their data
      final existingGames = {
        for (var game in _games)
          game.name: game
      };

      final newGames = <Game>[];

      // Scan for game folders
      await for (final entity in dir.list()) {
        if (entity is Directory) {
          final gameName = p.basename(entity.path);
          final configFile = File(p.join(entity.path, 'game.json'));

          Game? game;
          if (await configFile.exists()) {
            try {
              final json = jsonDecode(await configFile.readAsString());
              game = Game.fromJson(json);
              
              // Preserve existing category if it exists
              if (existingGames.containsKey(gameName)) {
                final existingGame = existingGames[gameName]!;
                if (existingGame.category.isNotEmpty) {
                  game = game.copyWith(category: existingGame.category);
                }
              }
            } catch (e) {
              LoggingService().log(
                'Error loading game config for $gameName: $e',
                level: LogLevel.error,
              );
            }
          }

          // If we have an existing game with this name, use its data
          if (existingGames.containsKey(gameName)) {
            final existingGame = existingGames[gameName]!;
            // If we loaded new data, merge it with existing data
            if (game != null) {
              game = game.copyWith(
                category: existingGame.category.isNotEmpty 
                  ? existingGame.category 
                  : game.category,
                prefixPath: existingGame.prefixPath,
                isProton: existingGame.isProton,
                environment: existingGame.environment,
                launchOptions: existingGame.launchOptions,
              );
            } else {
              game = existingGame;
            }
          }

          // If we still don't have a game, create a new one
          game ??= Game(
            name: gameName,
            category: 'Uncategorized',
            exePath: '',
            environment: const {},
            launchOptions: const {},
          );

          newGames.add(game);
        }
      }

      // Update games list
      _games.clear();
      _games.addAll(newGames);

      LoggingService().log(
        'Scanned ${_games.length} games\n'
        'Categories: ${_games.map((g) => '${g.name}: ${g.category}').join('\n')}',
        level: LogLevel.debug,
      );

      notifyListeners();
      await saveGames();

    } catch (e) {
      LoggingService().log(
        'Error scanning games folder: $e',
        level: LogLevel.error,
      );
    }
  }

  Future<void> updateGame(Game game) async {
    final index = _games.indexWhere((g) => g.name == game.name);
    if (index != -1) {
      final oldGame = _games[index];
      _games[index] = game;
      
      LoggingService().log(
        'Updating game: ${game.name}\n'
        'Old category: ${oldGame.category}\n'
        'New category: ${game.category}\n'
        'Game data: ${game.toJson()}',
        level: LogLevel.debug,
      );
      
      await saveGames();
      notifyListeners();
    } else {
      LoggingService().log(
        'Failed to update game: ${game.name} - Game not found',
        level: LogLevel.error,
      );
    }
  }

  Future<void> saveGames() async {
    try {
      final context = navigatorKey.currentContext;
      if (context == null) {
        LoggingService().log(
          'No context available to save games',
          level: LogLevel.error,
        );
        return;
      }

      final settings = Provider.of<SettingsProvider>(context, listen: false);
      final gamesPath = settings.gamesPath;

      for (final game in _games) {
        final gameDir = Directory(p.join(gamesPath, game.name));
        if (!await gameDir.exists()) {
          await gameDir.create(recursive: true);
        }

        final configFile = File(p.join(gameDir.path, 'game.json'));
        final json = game.toJson();
        
        LoggingService().log(
          'Saving game: ${game.name}\n'
          'Category: ${game.category}\n'
          'JSON: $json',
          level: LogLevel.debug,
        );
        
        await configFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(json),
        );
      }
    } catch (e) {
      LoggingService().log(
        'Error saving games: $e',
        level: LogLevel.error,
      );
    }
  }

  Future<void> addGame(Game game) async {
    // Check if game with same name already exists
    final existingIndex = _games.indexWhere((g) => g.name == game.name);
    if (existingIndex != -1) {
      // Update existing game
      _games[existingIndex] = game;
      LoggingService().log(
        'Updated existing game: ${game.name} (Category: ${game.category})',
        level: LogLevel.debug,
      );
    } else {
      // Add new game
      _games.add(game);
      LoggingService().log(
        'Added new game: ${game.name} (Category: ${game.category})',
        level: LogLevel.debug,
      );
    }
    
    await saveGames();
    notifyListeners();
  }

  Future<void> removeGame(String id) async {
    _games.removeWhere((g) => g.id == id);
    await saveGames();
    notifyListeners();
  }
}

class PrefixProvider extends ChangeNotifier {
  final List<WinePrefix> _prefixes = [];
  List<WinePrefix> get prefixes => List.unmodifiable(_prefixes);
  BuildContext? _context;
  bool _isLoading = false;

  Future<void> loadPrefixes(BuildContext context) async {
    if (_isLoading) return;  // Prevent multiple simultaneous loads
    _isLoading = true;

    try {
      if (!context.mounted) return;
      
      _context = context;
      final settings = Provider.of<SettingsProvider>(context, listen: false);
      final basePath = settings.defaultWinePrefixPath;

      if (basePath.isEmpty) {
        LoggingService().log('Base path is empty', level: LogLevel.warning);
        return;
      }

      // Create base directories if they don't exist
      final wineDir = Directory(p.join(basePath, 'wine'));
      final protonDir = Directory(p.join(basePath, 'proton'));

      await wineDir.create(recursive: true);
      await protonDir.create(recursive: true);

      // Clear existing prefixes before loading
      _prefixes.clear();

      // Scan Wine prefixes
      if (await wineDir.exists()) {
        await _scanPrefixDirectory(wineDir, false);
      }

      // Scan Proton prefixes
      if (await protonDir.exists()) {
        await _scanPrefixDirectory(protonDir, true);
      }

      notifyListeners();
    } catch (e) {
      LoggingService().log('Error loading prefixes: $e', level: LogLevel.error);
    } finally {
      _isLoading = false;
    }
  }

  Future<void> _scanPrefixDirectory(Directory dir, bool isProton) async {
    if (_context == null) return;

    await for (final entity in dir.list()) {
      if (entity is Directory) {
        final prefixPath = entity.path;
        
        // Skip the base directory for Proton
        if (isProton && p.basename(prefixPath) == 'base') continue;

        // Check for key files that indicate a valid prefix
        final systemReg = File(p.join(prefixPath, 'system.reg'));
        final userReg = File(p.join(prefixPath, 'user.reg'));
        final system32Dir = Directory(p.join(prefixPath, 'drive_c', 'windows', 'system32'));

        if (await systemReg.exists() && 
            await userReg.exists() && 
            await system32Dir.exists()) {
          _prefixes.add(_createWinePrefix(
            name: p.basename(prefixPath),
            path: prefixPath,
            isProton: isProton,
          ));
        }
      }
    }
  }

  WinePrefix _createWinePrefix({
    required String name,
    required String path,
    required bool isProton,
  }) {
    if (_context == null) {
      throw StateError('Context not available');
    }

    return WinePrefix(
      context: _context!,
      name: name,
      path: path,
      isProton: isProton,
      sourceUrl: '',
      is64Bit: true,  // We could detect this from the prefix
      onStatusUpdate: (message, {bool isError = false}) {
        LoggingService().log(
          message, 
          level: isError ? LogLevel.error : LogLevel.info,
        );
      },
    );
  }

  void addPrefix(WinePrefix prefix) {
    _prefixes.add(prefix);
    notifyListeners();
  }

  void removePrefix(WinePrefix prefixToRemove) {
    _prefixes.removeWhere((prefix) => prefix.path == prefixToRemove.path);
    notifyListeners();
  }
} 