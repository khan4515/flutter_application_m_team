import 'dart:convert';

class SiteConfig {
  final String name;
  final String baseUrl; // e.g. https://kp.m-team.cc/
  final String? apiKey; // x-api-key

  const SiteConfig({
    required this.name,
    required this.baseUrl,
    this.apiKey,
  });

  SiteConfig copyWith({String? name, String? baseUrl, String? apiKey}) => SiteConfig(
        name: name ?? this.name,
        baseUrl: baseUrl ?? this.baseUrl,
        apiKey: apiKey ?? this.apiKey,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'baseUrl': baseUrl,
        'apiKey': apiKey,
      };

  factory SiteConfig.fromJson(Map<String, dynamic> json) => SiteConfig(
        name: json['name'] as String,
        baseUrl: json['baseUrl'] as String,
        apiKey: json['apiKey'] as String?,
      );

  @override
  String toString() => jsonEncode(toJson());
}

class QbClientConfig {
  final String id; // uuid or custom id
  final String name;
  final String host; // ip or domain
  final int port;
  final String username;
  final String? password; // stored securely, may be null when loaded from prefs-only

  const QbClientConfig({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    required this.username,
    this.password,
  });

  QbClientConfig copyWith({
    String? id,
    String? name,
    String? host,
    int? port,
    String? username,
    String? password,
  }) => QbClientConfig(
        id: id ?? this.id,
        name: name ?? this.name,
        host: host ?? this.host,
        port: port ?? this.port,
        username: username ?? this.username,
        password: password ?? this.password,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'host': host,
        'port': port,
        'username': username,
        // password intentionally excluded from plain json by default
      };

  factory QbClientConfig.fromJson(Map<String, dynamic> json) => QbClientConfig(
        id: json['id'] as String,
        name: json['name'] as String,
        host: json['host'] as String,
        port: (json['port'] as num).toInt(),
        username: json['username'] as String,
      );
}

class Defaults {
  static const List<SiteConfig> presetSites = [
    SiteConfig(name: 'M-Team api 主站', baseUrl: 'https://api.m-team.cc/'),
    SiteConfig(name: 'M-Team api 副站', baseUrl: 'https://api2.m-team.cc/'),
    SiteConfig(name: 'M-Team 旧风格api', baseUrl: 'https://api.m-team.io/'),
  ];
}