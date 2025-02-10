class PrefixUrl {
  final String url;
  final bool isProton;
  final String name;

  const PrefixUrl({
    required this.url,
    required this.isProton,
    required this.name,
  });

  Map<String, dynamic> toJson() => {
        'url': url,
        'isProton': isProton,
        'name': name,
      };

  factory PrefixUrl.fromJson(Map<String, dynamic> json) {
    return PrefixUrl(
      url: json['url'] as String,
      isProton: json['isProton'] as bool,
      name: json['name'] as String,
    );
  }
} 