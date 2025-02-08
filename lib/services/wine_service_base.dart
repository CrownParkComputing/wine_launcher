abstract class WineServiceBase {
  final String prefixPath;
  final bool is64Bit;
  final Function(String message, {bool isError}) onStatusUpdate;

  WineServiceBase({
    required this.prefixPath,
    required this.is64Bit,
    required this.onStatusUpdate,
  });

  Map<String, String> get baseEnvironment => {
    'WINEPREFIX': prefixPath,
    'WINEARCH': is64Bit ? 'win64' : 'win32',
    'WINE_DISABLE_WINEDBG': '1',
  };
} 