class PrefixSettings {
  final bool dxvkInstalled;
  final bool dxvkAsyncInstalled;
  final bool vkd3dInstalled;
  final bool vcRuntimeInstalled;

  PrefixSettings({
    this.dxvkInstalled = false,
    this.dxvkAsyncInstalled = false,
    this.vkd3dInstalled = false,
    this.vcRuntimeInstalled = false,
  });

  PrefixSettings copyWith({
    bool? dxvkInstalled,
    bool? dxvkAsyncInstalled,
    bool? vkd3dInstalled,
    bool? vcRuntimeInstalled,
  }) {
    return PrefixSettings(
      dxvkInstalled: dxvkInstalled ?? this.dxvkInstalled,
      dxvkAsyncInstalled: dxvkAsyncInstalled ?? this.dxvkAsyncInstalled,
      vkd3dInstalled: vkd3dInstalled ?? this.vkd3dInstalled,
      vcRuntimeInstalled: vcRuntimeInstalled ?? this.vcRuntimeInstalled,
    );
  }

  Map<String, dynamic> toJson() => {
    'dxvkInstalled': dxvkInstalled,
    'dxvkAsyncInstalled': dxvkAsyncInstalled,
    'vkd3dInstalled': vkd3dInstalled,
    'vcRuntimeInstalled': vcRuntimeInstalled,
  };

  factory PrefixSettings.fromJson(Map<String, dynamic> json) => PrefixSettings(
    dxvkInstalled: json['dxvkInstalled'] as bool? ?? false,
    dxvkAsyncInstalled: json['dxvkAsyncInstalled'] as bool? ?? false,
    vkd3dInstalled: json['vkd3dInstalled'] as bool? ?? false,
    vcRuntimeInstalled: json['vcRuntimeInstalled'] as bool? ?? false,
  );
} 