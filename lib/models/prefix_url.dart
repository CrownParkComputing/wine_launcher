class PrefixUrl {
  final String url;
  final bool isProton;
  final String title;

  const PrefixUrl({
    required this.url,
    required this.isProton,
    required this.title,
  });

  Map<String, dynamic> toJson() => {
        'url': url,
        'isProton': isProton,
        'title': title,
      };

  factory PrefixUrl.fromJson(Map<String, dynamic> json) {
    return PrefixUrl(
      url: json['url'] as String,
      isProton: json['isProton'] as bool,
      title: json['title'] as String,
    );
  }
} 