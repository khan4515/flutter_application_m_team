import 'package:dio/dio.dart';

import '../../models/app_models.dart';

class QbTransferInfo {
  final int upSpeed;
  final int dlSpeed;
  final int upTotal;
  final int dlTotal;
  const QbTransferInfo({required this.upSpeed, required this.dlSpeed, required this.upTotal, required this.dlTotal});
}

class QbService {
  QbService._();
  static final QbService instance = QbService._();

  String _buildBase(QbClientConfig c) {
    var h = c.host.trim();
    if (h.endsWith('/')) h = h.substring(0, h.length - 1);
    final hasScheme = h.startsWith('http://') || h.startsWith('https://');
    if (!hasScheme) {
      return 'http://$h:${c.port}';
    }
    try {
      final u = Uri.parse(h);
      if (u.hasPort) return h;
      return '$h:${c.port}';
    } catch (_) {
      return h;
    }
  }

  Dio _createDio(String base) {
    return Dio(BaseOptions(
      baseUrl: base,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 12),
      sendTimeout: const Duration(seconds: 12),
      headers: {
        'User-Agent': 'MTeamApp/1.0 (Flutter; Dio)',
      },
      validateStatus: (code) => code != null && code >= 200 && code < 500,
    ));
  }

  Future<void> testConnection({required QbClientConfig config, required String password}) async {
    final base = _buildBase(config);
    final dio = _createDio(base);
    try {
      final res = await dio.post(
        '/api/v2/auth/login',
        data: {
          'username': config.username,
          'password': password,
        },
        options: Options(contentType: Headers.formUrlEncodedContentType, followRedirects: false),
      );
      final sc = res.statusCode ?? 0;
      final body = (res.data ?? '').toString().toLowerCase();
      if (sc != 200 || !body.contains('ok')) {
        throw Exception('登录失败（HTTP $sc）');
      }
      // 可选：登录成功即可视为连通
    } on DioException catch (e) {
      final msg = e.response != null
          ? 'HTTP ${e.response?.statusCode}: ${e.response?.statusMessage ?? ''}'
          : (e.message ?? '网络错误');
      throw Exception('连接失败：$msg');
    }
  }

  Future<String> _loginAndGetCookie(QbClientConfig config, String password) async {
    final base = _buildBase(config);
    final dio = _createDio(base);
    final res = await dio.post(
      '/api/v2/auth/login',
      data: {
        'username': config.username,
        'password': password,
      },
      options: Options(contentType: Headers.formUrlEncodedContentType, followRedirects: false),
    );
    final sc = res.statusCode ?? 0;
    final body = (res.data ?? '').toString().toLowerCase();
    if (sc != 200 || !body.contains('ok')) {
      throw Exception('登录失败（HTTP $sc）');
    }
    final setCookie = res.headers.map['set-cookie']?.join('; ') ?? '';
    return setCookie;
  }

  Future<QbTransferInfo> fetchTransferInfo({required QbClientConfig config, required String password}) async {
    final base = _buildBase(config);
    final dio = _createDio(base);
    final cookie = await _loginAndGetCookie(config, password);
    final res = await dio.get(
      '/api/v2/transfer/info',
      options: Options(headers: cookie.isNotEmpty ? {'Cookie': cookie} : null),
    );
    if ((res.statusCode ?? 0) != 200) {
      throw Exception('获取传输信息失败（HTTP ${res.statusCode}）');
    }
    final data = res.data is Map ? (res.data as Map).cast<String, dynamic>() : <String, dynamic>{};
    final upSpeed = (data['up_info_speed'] ?? 0) is int ? data['up_info_speed'] as int : int.tryParse('${data['up_info_speed'] ?? 0}') ?? 0;
    final dlSpeed = (data['dl_info_speed'] ?? 0) is int ? data['dl_info_speed'] as int : int.tryParse('${data['dl_info_speed'] ?? 0}') ?? 0;
    final upTotal = (data['up_info_data'] ?? 0) is int ? data['up_info_data'] as int : int.tryParse('${data['up_info_data'] ?? 0}') ?? 0;
    final dlTotal = (data['dl_info_data'] ?? 0) is int ? data['dl_info_data'] as int : int.tryParse('${data['dl_info_data'] ?? 0}') ?? 0;
    return QbTransferInfo(upSpeed: upSpeed, dlSpeed: dlSpeed, upTotal: upTotal, dlTotal: dlTotal);
  }

  Future<List<String>> fetchCategories({required QbClientConfig config, required String password}) async {
    final base = _buildBase(config);
    final dio = _createDio(base);
    final cookie = await _loginAndGetCookie(config, password);
    final res = await dio.get(
      '/api/v2/torrents/categories',
      options: Options(headers: cookie.isNotEmpty ? {'Cookie': cookie} : null),
    );
    if ((res.statusCode ?? 0) != 200) {
      throw Exception('获取分类失败（HTTP ${res.statusCode}）');
    }
    final data = res.data;
    if (data is Map) {
      final map = data.cast<String, dynamic>();
      return map.keys.toList()..sort();
    }
    return <String>[];
  }

  Future<List<String>> fetchTags({required QbClientConfig config, required String password}) async {
    final base = _buildBase(config);
    final dio = _createDio(base);
    final cookie = await _loginAndGetCookie(config, password);
    final res = await dio.get(
      '/api/v2/torrents/tags',
      options: Options(headers: cookie.isNotEmpty ? {'Cookie': cookie} : null),
    );
    if ((res.statusCode ?? 0) != 200) {
      throw Exception('获取标签失败（HTTP ${res.statusCode}）');
    }
    final body = (res.data ?? '').toString();
    final sep = body.contains('\n') ? '\n' : ',';
    final list = body.split(sep).map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().toList();
    list.sort();
    return list;
  }

  // 新增：通过 URL 添加任务到 qBittorrent
  Future<void> addTorrentByUrl({
    required QbClientConfig config,
    required String password,
    required String url,
    String? category,
    List<String>? tags,
    String? savePath,
    bool? autoTMM,
  }) async {
    final base = _buildBase(config);
    final dio = _createDio(base);
    final cookie = await _loginAndGetCookie(config, password);

    final form = FormData.fromMap({
      'urls': url,
      if (category != null && category.isNotEmpty) 'category': category,
      if (tags != null && tags.isNotEmpty) 'tags': tags.join(','),
      if (savePath != null && savePath.trim().isNotEmpty) 'savepath': savePath.trim(),
      if (autoTMM != null) 'autoTMM': autoTMM ? 'true' : 'false',
    });

    final res = await dio.post(
      '/api/v2/torrents/add',
      data: form,
      options: Options(headers: cookie.isNotEmpty ? {'Cookie': cookie} : null),
    );

    if ((res.statusCode ?? 0) != 200) {
      throw Exception('发送任务失败（HTTP ${res.statusCode}）');
    }
  }
}