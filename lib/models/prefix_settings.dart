class PrefixSettings {
  final bool dxvkInstalled;
  final bool dxvkAsyncInstalled;
  final bool vkd3dInstalled;
  final bool vcRuntimeInstalled;
  final String name;
  final String path;
  final bool isProton;
  final String sourceUrl;
  final bool is64Bit;

  const PrefixSettings({
    this.dxvkInstalled = false,
    this.dxvkAsyncInstalled = false,
    this.vkd3dInstalled = false,
    this.vcRuntimeInstalled = false,
    required this.name,
    required this.path,
    required this.isProton,
    required this.sourceUrl,
    required this.is64Bit,
  });

  PrefixSettings copyWith({
    bool? dxvkInstalled,
    bool? dxvkAsyncInstalled,
    bool? vkd3dInstalled,
    bool? vcRuntimeInstalled,
    String? name,
    String? path,
    bool? isProton,
    String? sourceUrl,
    bool? is64Bit,
  }) {
    return PrefixSettings(
      dxvkInstalled: dxvkInstalled ?? this.dxvkInstalled,
      dxvkAsyncInstalled: dxvkAsyncInstalled ?? this.dxvkAsyncInstalled,
      vkd3dInstalled: vkd3dInstalled ?? this.vkd3dInstalled,
      vcRuntimeInstalled: vcRuntimeInstalled ?? this.vcRuntimeInstalled,
      name: name ?? this.name,
      path: path ?? this.path,
      isProton: isProton ?? this.isProton,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      is64Bit: is64Bit ?? this.is64Bit,
    );
  }

  Map<String, dynamic> toJson() => {
    'dxvkInstalled': dxvkInstalled,
    'dxvkAsyncInstalled': dxvkAsyncInstalled,
    'vkd3dInstalled': vkd3dInstalled,
    'vcRuntimeInstalled': vcRuntimeInstalled,
    'name': name,
    'path': path,
    'isProton': isProton,
    'sourceUrl': sourceUrl,
    'is64Bit': is64Bit,
  };

  factory PrefixSettings.fromJson(Map<String, dynamic> json) => PrefixSettings(
    dxvkInstalled: json['dxvkInstalled'] as bool? ?? false,
    dxvkAsyncInstalled: json['dxvkAsyncInstalled'] as bool? ?? false,
    vkd3dInstalled: json['vkd3dInstalled'] as bool? ?? false,
    vcRuntimeInstalled: json['vcRuntimeInstalled'] as bool? ?? false,
    name: json['name'] as String,
    path: json['path'] as String,
    isProton: json['isProton'] as bool,
    sourceUrl: json['sourceUrl'] as String,
    is64Bit: json['is64Bit'] as bool,
  );
} 