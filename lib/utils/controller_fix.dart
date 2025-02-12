import 'package:wine_launcher/services/wine_service.dart';
import 'package:wine_launcher/services/logging_service.dart';

class ControllerFix {
  static Future<void> apply(String prefixPath) async {
    try {
      LoggingService().log('Applying controller fix...', level: LogLevel.info);

      // Disable hidraw
      await WineService.setRegistryValue(
        prefixPath,
        'HKEY_LOCAL_MACHINE\\System\\CurrentControlSet\\Services\\winebus',
        'DisableHidraw',
        'REG_DWORD',
        '1',
      );

      // Enable SDL
      await WineService.setRegistryValue(
        prefixPath,
        'HKEY_LOCAL_MACHINE\\System\\CurrentControlSet\\Services\\winebus',
        'Enable SDL',
        'REG_DWORD',
        '1',
      );

      // Enable XInput
      await WineService.setRegistryValue(
        prefixPath,
        'HKEY_LOCAL_MACHINE\\System\\CurrentControlSet\\Services\\winebus',
        'Enable XInput',
        'REG_DWORD',
        '1',
      );

      LoggingService().log('Controller fix applied successfully', level: LogLevel.info);
    } catch (e) {
      LoggingService().log('Error applying controller fix: $e', level: LogLevel.error);
      rethrow;
    }
  }
}
