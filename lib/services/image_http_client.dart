import 'package:dio/dio.dart';

class ImageHttpClient {
  ImageHttpClient._();
  static final ImageHttpClient instance = ImageHttpClient._();

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
    sendTimeout: const Duration(seconds: 30),
    headers: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
      'Accept': 'image/webp,image/apng,image/*,*/*;q=0.8',
      'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
      'Cache-Control': 'no-cache',
      'Pragma': 'no-cache',
    },
  ));

  /// 获取图片数据
  Future<Response<List<int>>> fetchImage(String url) async {
    // 根据不同的图片域名设置不同的Referer
    String? referer;
    if (url.contains('doubanio.com')) {
      referer = 'https://www.douban.com/';
    } else if (url.contains('m-team.cc')) {
      referer = 'https://kp.m-team.cc/';
    }

    return await _dio.get<List<int>>(
      url,
      options: Options(
        responseType: ResponseType.bytes,
        headers: {
          if (referer != null) 'Referer': referer,
        },
      ),
    );
  }
}