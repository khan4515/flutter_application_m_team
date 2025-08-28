import 'package:dio/dio.dart';

import '../../models/app_models.dart';

class QbTransferInfo {
  final int upSpeed;
  final int dlSpeed;
  final int upTotal;
  final int dlTotal;
  const QbTransferInfo({
    required this.upSpeed,
    required this.dlSpeed,
    required this.upTotal,
    required this.dlTotal,
  });
}

class QbService {
  QbService._();
  static final QbService instance = QbService._();

  // Cookie 缓存相关字段
  String? _cachedCookie;
  QbClientConfig? _cachedConfig;
  String? _cachedPassword;
  DateTime? _lastLoginTime;

  // Cookie 有效期（默认30分钟）
  static const Duration _cookieValidDuration = Duration(minutes: 30);

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
    return Dio(
      BaseOptions(
        baseUrl: base,
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 12),
        sendTimeout: const Duration(seconds: 12),
        headers: {'User-Agent': 'MTeamApp/1.0 (Flutter; Dio)'},
        validateStatus: (code) => code != null && code >= 200 && code < 500,
      ),
    );
  }

  /// 清除缓存的 cookie
  void clearCache() {
    _cachedCookie = null;
    _cachedConfig = null;
    _cachedPassword = null;
    _lastLoginTime = null;
  }

  /// 检查缓存的 cookie 是否有效
  bool _isCacheValid(QbClientConfig config, String password) {
    if (_cachedCookie == null || 
        _cachedConfig == null || 
        _cachedPassword == null || 
        _lastLoginTime == null) {
      return false;
    }
    
    // 检查配置是否相同
    if (_cachedConfig!.host != config.host ||
        _cachedConfig!.port != config.port ||
        _cachedConfig!.username != config.username ||
        _cachedPassword != password) {
      return false;
    }
    
    // 检查时间是否过期
    final now = DateTime.now();
    if (now.difference(_lastLoginTime!) > _cookieValidDuration) {
      return false;
    }
    
    return true;
  }

  /// 获取有效的 cookie，如果缓存无效则重新登录
  Future<String> _getValidCookie(QbClientConfig config, String password) async {
    if (_isCacheValid(config, password)) {
      return _cachedCookie!;
    }
    
    // 缓存无效，重新登录
    final cookie = await _loginAndGetCookie(config, password);
    
    // 更新缓存
    _cachedCookie = cookie;
    _cachedConfig = config;
    _cachedPassword = password;
    _lastLoginTime = DateTime.now();
    
    return cookie;
  }

  /// 执行需要认证的 API 请求，自动处理 cookie 失效重试
  Future<Response<T>> _executeAuthenticatedRequest<T>(
    QbClientConfig config,
    String password,
    Future<Response<T>> Function(String cookie) request,
  ) async {
    try {
      final cookie = await _getValidCookie(config, password);
      return await request(cookie);
    } catch (e) {
      // 如果请求失败，可能是 cookie 失效，清除缓存并重试一次
      if (e is DioException && e.response?.statusCode == 403) {
        clearCache();
        final cookie = await _getValidCookie(config, password);
        return await request(cookie);
      }
      rethrow;
    }
  }

  Future<void> testConnection({
    required QbClientConfig config,
    required String password,
  }) async {
    final base = _buildBase(config);
    final dio = _createDio(base);
    try {
      final res = await dio.post(
        '/api/v2/auth/login',
        data: {'username': config.username, 'password': password},
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          followRedirects: false,
        ),
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

  Future<String> _loginAndGetCookie(
    QbClientConfig config,
    String password,
  ) async {
    final base = _buildBase(config);
    final dio = _createDio(base);
    final res = await dio.post(
      '/api/v2/auth/login',
      data: {'username': config.username, 'password': password},
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        followRedirects: false,
      ),
    );
    final sc = res.statusCode ?? 0;
    final body = (res.data ?? '').toString().toLowerCase();
    if (sc != 200 || !body.contains('ok')) {
      throw Exception('登录失败（HTTP $sc）');
    }
    final setCookie = res.headers.map['set-cookie']?.join('; ') ?? '';
    return setCookie;
  }

  Future<QbTransferInfo> fetchTransferInfo({
    required QbClientConfig config,
    required String password,
  }) async {
    final base = _buildBase(config);
    final dio = _createDio(base);
    
    final res = await _executeAuthenticatedRequest<Map<String, dynamic>>(
      config,
      password,
      (cookie) => dio.get(
        '/api/v2/transfer/info',
        options: Options(headers: cookie.isNotEmpty ? {'Cookie': cookie} : null),
      ),
    );
    
    if ((res.statusCode ?? 0) != 200) {
      throw Exception('获取传输信息失败（HTTP ${res.statusCode}）');
    }
    final data = res.data is Map
        ? (res.data as Map).cast<String, dynamic>()
        : <String, dynamic>{};
    final upSpeed = (data['up_info_speed'] ?? 0) is int
        ? data['up_info_speed'] as int
        : int.tryParse('${data['up_info_speed'] ?? 0}') ?? 0;
    final dlSpeed = (data['dl_info_speed'] ?? 0) is int
        ? data['dl_info_speed'] as int
        : int.tryParse('${data['dl_info_speed'] ?? 0}') ?? 0;
    final upTotal = (data['up_info_data'] ?? 0) is int
        ? data['up_info_data'] as int
        : int.tryParse('${data['up_info_data'] ?? 0}') ?? 0;
    final dlTotal = (data['dl_info_data'] ?? 0) is int
        ? data['dl_info_data'] as int
        : int.tryParse('${data['dl_info_data'] ?? 0}') ?? 0;
    return QbTransferInfo(
      upSpeed: upSpeed,
      dlSpeed: dlSpeed,
      upTotal: upTotal,
      dlTotal: dlTotal,
    );
  }

  Future<List<String>> fetchCategories({
    required QbClientConfig config,
    required String password,
  }) async {
    final base = _buildBase(config);
    final dio = _createDio(base);
    
    final res = await _executeAuthenticatedRequest<Map<String, dynamic>>(
      config,
      password,
      (cookie) => dio.get(
        '/api/v2/torrents/categories',
        options: Options(headers: cookie.isNotEmpty ? {'Cookie': cookie} : null),
      ),
    );
    
    if ((res.statusCode ?? 0) != 200) {
      throw Exception('获取分类失败（HTTP ${res.statusCode}）');
    }
    final data = res.data;
    if (data is Map) {
      final map = (data as Map).cast<String, dynamic>();
      return map.keys.toList()..sort();
    }
    return <String>[];
  }

  Future<List<String>> fetchTags({
    required QbClientConfig config,
    required String password,
  }) async {
    final base = _buildBase(config);
    final dio = _createDio(base);
    
    final res = await _executeAuthenticatedRequest(
      config,
      password,
      (cookie) => dio.get(
        '/api/v2/torrents/tags',
        options: Options(headers: cookie.isNotEmpty ? {'Cookie': cookie} : null),
      ),
    );
    
    if ((res.statusCode ?? 0) != 200) {
      throw Exception('获取标签失败（HTTP ${res.statusCode}）');
    }
    
    final data = res.data;
    if (data is List) {
      // 如果服务器直接返回 List<dynamic>，转换为 List<String>
      return data.map((e) => e.toString()).toList();
    } else if (data is String) {
      // 如果服务器返回字符串格式的数组，解析它
      if (data.trim().startsWith('[') && data.trim().endsWith(']')) {
        // 移除外层的 [] 并按逗号分割
        final content = data.trim().substring(1, data.trim().length - 1);
        if (content.trim().isEmpty) {
          return <String>[];
        }
        return content.split(',').map((tag) => tag.trim()).toList();
      } else {
        // 按换行符或逗号分割
        return data.split(RegExp(r'[\n,]')).map((tag) => tag.trim()).where((tag) => tag.isNotEmpty).toList();
      }
    }
    
    return <String>[];
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

    final form = FormData.fromMap({
      'urls': url,
      if (category != null && category.isNotEmpty) 'category': category,
      if (tags != null && tags.isNotEmpty) 'tags': tags.join(','),
      if (savePath != null && savePath.trim().isNotEmpty)
        'savepath': savePath.trim(),
      if (autoTMM != null) 'autoTMM': autoTMM ? 'true' : 'false',
    });

    final res = await _executeAuthenticatedRequest(
      config,
      password,
      (cookie) => dio.post(
        '/api/v2/torrents/add',
        data: form,
        options: Options(headers: cookie.isNotEmpty ? {'Cookie': cookie} : null),
      ),
    );

    if ((res.statusCode ?? 0) != 200) {
      throw Exception('发送任务失败（HTTP ${res.statusCode}）');
    }
  }
}