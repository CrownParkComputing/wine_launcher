import 'package:uuid/uuid.dart';

class Game {
  final String id;
  final String name;
  final String category;
  final String exePath;
  final String? prefixPath;
  final bool? isProton;
  final String? coverImagePath;
  final Map<String, String> environment;
  final Map<String, String> launchOptions;

  bool get hasPrefix => prefixPath != null && prefixPath!.isNotEmpty;

  Game({
    String? id,
    required this.name,
    this.category = '',
    required this.exePath,
    this.prefixPath,
    this.isProton,
    this.coverImagePath,
    required this.environment,
    required this.launchOptions,
  }) : id = id ?? const Uuid().v4();

  Game copyWith({
    String? name,
    String? category,
    String? exePath,
    String? prefixPath,
    bool? isProton,
    String? coverImagePath,
    Map<String, String>? environment,
    Map<String, String>? launchOptions,
  }) {
    return Game(
      id: id,
      name: name ?? this.name,
      category: category ?? this.category,
      exePath: exePath ?? this.exePath,
      prefixPath: prefixPath ?? this.prefixPath,
      isProton: isProton ?? this.isProton,
      coverImagePath: coverImagePath ?? this.coverImagePath,
      environment: environment ?? Map.from(this.environment),
      launchOptions: launchOptions ?? Map.from(this.launchOptions),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'exePath': exePath,
      'prefixPath': prefixPath,
      'isProton': isProton,
      'coverImagePath': coverImagePath,
      'environment': environment,
      'launchOptions': launchOptions,
    };
  }

  factory Game.fromJson(Map<String, dynamic> json) {
    return Game(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String? ?? '',
      exePath: json['exePath'] as String,
      prefixPath: json['prefixPath'] as String?,
      isProton: json['isProton'] as bool?,
      coverImagePath: json['coverImagePath'] as String?,
      environment: Map<String, String>.from(json['environment'] as Map),
      launchOptions: Map<String, String>.from(json['launchOptions'] as Map),
    );
  }

  @override
  String toString() {
    return 'Game(id: $id, name: $name, category: $category)';
  }
} 