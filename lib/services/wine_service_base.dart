abstract class WineServiceBase {
  final String prefixPath;
  final bool is64Bit;
  final Function(String, {bool isError}) onStatusUpdate;

  Map<String, String> get baseEnvironment => {
    'WINEPREFIX': prefixPath,
    'WINEARCH': is64Bit ? 'win64' : 'win32',
    'WINE_DISABLE_WINEDBG': '1',
    'PROTON_ENABLE_NVAPI': '1',
    // Vulkan settings
    'ENABLE_VKBASALT': '0',
    'VKD3D_CONFIG': 'dxr,dxr11',
    'VKD3D_FEATURE_LEVEL': '12_2',
    'DXVK_FRAME_RATE': '0',
    'DXVK_ASYNC': '1',
    'DXVK_STATE_CACHE': '1',
    '__GL_SHADER_DISK_CACHE': '1',
    '__GL_SHADER_DISK_CACHE_PATH': '$prefixPath/drive_c/shader-cache',
    '__GL_SHADER_DISK_CACHE_SKIP_CLEANUP': '1',
    'MESA_SHADER_CACHE_DIR': '$prefixPath/drive_c/shader-cache',
    'MESA_GL_VERSION_OVERRIDE': '4.6',
    'MESA_GLSL_VERSION_OVERRIDE': '460',
    'DXVK_STATE_CACHE_PATH': '$prefixPath/drive_c/dxvk-cache',
  };

  const WineServiceBase({
    required this.prefixPath,
    required this.is64Bit,
    required this.onStatusUpdate,
  });
} 