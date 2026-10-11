import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import 'package:chocolate_music/src/rust/third_party/netease/client.dart';
import 'package:chocolate_music/src/rust/third_party/netease/frb_api.dart' as ne;

/// 把 dio 的请求转给本地 Rust 实现的适配器（网易云）。
///
/// ## 这是什么
///
/// `NetEaseCloud.dart` 里每个 `Neteasecloud.dio.get('/xxx?a=b')` 原本打到自建服务器
/// （api-enhanced），服务器再把请求转发给网易云、把上游的响应体**重新包装**后返回
/// （`{code: 200, ...}`，形状因接口而异）。
///
/// 接入 Rust 后**不再需要那台服务器** —— 本 adapter 把请求截下来，走 FFI 直接调
/// Rust 里等价的那次请求，返回**和服务器一模一样**的响应体。于是
/// `NetEaseCloud.dart` 的解析代码一行都不用改。
///
/// ## ⚠️ 它不发 HTTP
///
/// 名字里有 dio，但 [fetch] 里**没有任何网络调用**。它只是借 dio 的接口形态做
/// 兼容层，所以看到 `Neteasecloud.dio.get(...)` 时不要以为在发 HTTP 请求。
///
/// ## ⚠️ 与酷狗 adapter 的关键差异：凭据走 Cookie 头
///
/// 酷狗那边 `KuGou.dart` 把 `token`/`userid`/`dfid` 塞在 **query 参数**里；
/// 网易云这边 `NetEaseCloud.dart` 用的是 **Cookie 头**：
///
/// ```dart
/// await Neteasecloud.dio.get('/song/url?id=X',
///     options: Options(headers: {'Cookie': this.cookies}));
/// ```
///
/// 所以本 adapter 必须把 `options.headers['Cookie']` 取出来传给 Rust。
///
/// ## 调用链
///
/// ```text
/// Neteasecloud.dio.get('/song/url?id=X')
///   → NetEaseCloudRustAdapter.fetch()        ← 本文件，进程内
///   → NetEaseClient.rawRequest(path, query, cookie)  ← FFI，进程内
///   → Rust 直连网易云上游                     ← 唯一一次真实网络请求
/// ```
///
/// ## 使用
///
/// 在 `main()` 里 `await RustLib.init()` 之后即可工作，无需其他初始化：
///
/// ```dart
/// static final Dio dio = _createDio();
///
/// static Dio _createDio() {
///   final dio = Dio(BaseOptions(baseUrl: "https://neteasecloud.xjinhui.asia"));
///   dio.httpClientAdapter = NetEaseCloudRustAdapter();
///   return dio;
/// }
/// ```
///
/// > `baseUrl` 已不再被访问，保留只是为了不动 `NetEaseCloud.dart` 的原有写法。
class NetEaseCloudRustAdapter implements HttpClientAdapter {
  NetEaseCloudRustAdapter({this.identityFileName = 'netease_identity.json'});

  /// 设备身份文件名，落在应用文档目录下。
  ///
  /// ⚠️ 必须放在**绝对路径**（移动端的当前工作目录不可写）。
  ///
  /// 与酷狗那套**分开存** —— 设备身份是每个平台独立的。
  final String identityFileName;

  NetEaseClient? _client;

  /// 懒加载 Rust 客户端。
  ///
  /// 不能放在构造函数里 —— `createClient` 是异步的，而 `Neteasecloud.dio` 是
  /// `static final`，初始化是同步的。
  Future<NetEaseClient> _ensureClient() async {
    if (_client != null) return _client!;

    final dir = await getApplicationDocumentsDirectory();
    _client = await ne.createClient(
      identityPath: '${dir.path}/$identityFileName',
    );
    return _client!;
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    // ⚠️ `options.uri` 已经把三者合并好了（见 dio 的 `RequestOptions.uri`）：
    //    ① baseUrl  ② path 里内嵌的查询串（`/x?id=1`）  ③ queryParameters
    final uri = options.uri;
    final path = uri.path;
    final query = Map<String, String>.from(uri.queryParameters);

    // ⚠️ 凭据在 Cookie 头里 —— 这是与酷狗 adapter 最大的不同
    final cookie = _cookieOf(options);

    final NetEaseClient client;
    try {
      client = await _ensureClient();
    } catch (e) {
      throw DioException(
        requestOptions: options,
        error: e,
        message: 'Rust 客户端创建失败。请确认 main() 里已 `await RustLib.init()`。',
      );
    }

    final String body;
    try {
      body = await client.rawRequest(
        path: path,
        query: query,
        cookie: cookie,
      );
    } catch (e) {
      // 与原实现一致：网络层失败时 dio 抛异常，由调用方的 try/catch 接住。
      throw DioException(requestOptions: options, error: e, message: '$e');
    }

    // 业务失败（`code != 200`）**不**算异常 —— 原服务器对这类响应也用 HTTP 200
    // （`SPECIAL_STATUS_CODES` 里的 800/801/802/803 等），由 `NetEaseCloud.dart`
    // 自己判断 `response.data['code']`。
    //
    // 注意 `Neteasecloud.dio` **没有** `validateStatus` 覆盖，所以这里必须回 200，
    // 否则 dio 会对 301（需要登录）之类直接抛异常。
    return ResponseBody.fromString(
      body,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  /// 从请求头里取 `Cookie`
  ///
  /// dio 的 `headers` 是 `Map<String, dynamic>`，且 key 大小写不保证 —— 做一次
  /// 不区分大小写的查找。
  String _cookieOf(RequestOptions options) {
    for (final entry in options.headers.entries) {
      if (entry.key.toLowerCase() == 'cookie') {
        return '${entry.value}';
      }
    }
    return '';
  }

  @override
  void close({bool force = false}) {
    // 客户端由 Rust 侧持有，无需在此释放。
  }
}
