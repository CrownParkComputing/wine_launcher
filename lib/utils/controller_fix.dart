import 'package:wine_launcher/services/wine_service.dart';

class ControllerFix {
  static Future<void> applyControllerFix(String prefixPath) async {
    final wineService = WineService();
    
    // Set DirectInput registry key
    await wineService.setRegistryValue(
      prefixPath,
      'HKEY_CURRENT_USER\Software\Wine\DirectInput',
      'MouseWarpOverride',
      'force'
    );

    // Set XInput registry key
    await wineService.setRegistryValue(
      prefixPath,
      'HKEY_CURRENT_USER\Software\Wine\XInput',
      'Version',
      'disabled'
    );

    // Set DInputToXInput registry key
    await wineService.setRegistryValue(
      prefixPath,
      'HKEY_CURRENT_USER\Software\Wine\DInputToXInput',
      'Enable',
      '1'
    );
  }
}
