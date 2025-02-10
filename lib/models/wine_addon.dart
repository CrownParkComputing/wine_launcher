class WineAddon {
  final String name;
  final String url;
  final String type; // e.g., 'dxvk', 'vkd3d', 'runtime'

  const WineAddon({
    required this.name,
    required this.url,
    required this.type,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'url': url,
    'type': type,
  };

  factory WineAddon.fromJson(Map<String, dynamic> json) => WineAddon(
    name: json['name'],
    url: json['url'],
    type: json['type'],
  );
} 