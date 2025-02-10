import 'dart:io';

class WineUtils {
  static Future<void> runWinecfg(String prefixPath) async {
    await Process.run('wine', ['winecfg'], 
      environment: {'WINEPREFIX': prefixPath}
    );
  }

  static Future<void> runWinetricks(String prefixPath) async {
    await Process.run('winetricks', [], 
      environment: {'WINEPREFIX': prefixPath}
    );
  }

  static Future<void> openExplorer(String prefixPath) async {
    await Process.run('wine', ['explorer'], 
      environment: {'WINEPREFIX': prefixPath}
    );
  }

  static Future<void> runRegedit(String prefixPath) async {
    await Process.run('wine', ['regedit'], 
      environment: {'WINEPREFIX': prefixPath}
    );
  }

  static Future<void> installDXVK(String prefixPath) async {
    // Implementation depends on your DXVK installation method
  }

  static Future<void> installVKD3D(String prefixPath) async {
    // Implementation depends on your VKD3D installation method
  }

  static Future<void> installVC(String prefixPath) async {
    await Process.run('winetricks', ['vcrun2019'], 
      environment: {'WINEPREFIX': prefixPath}
    );
  }
} 