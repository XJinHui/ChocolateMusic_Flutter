import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import 'package:chocolate_music/src/rust/client.dart';
import 'package:chocolate_music/src/rust/frb_api.dart';

/// 把 dio 的请求转给本地 Rust 实现的适配器。
///
/// ## 这是什么
///
/// `KuGou.dart` 里每个 `KuGou.dio.get('/xxx?a=b')` 原本打到自建服务器
/// （KuGouMusicApi），服务器再把请求转发给酷狗、并把上游的响应体原样返回
/// （`server.js` 的收尾就一句 `res.status(...).send(moduleResponse.body)`）。
///
/// 接入 Rust 后**不再需要那台服务器** —— 本 adapter 把请求截下来，走 FFI 直接调
/// Rust 里等价的那次请求，返回**和服务器一模一样**的响应体。于是 `KuGou.dart`
/// 的解析代码（`response.data["status"]`、`response.data['data']['songs']` …）
/// 一行都不用改。
///
/// ## ⚠️ 它不发 HTTP
///
/// 名字里有 dio，但 [fetch] 里**没有任何网络调用**。它只是借 dio 的接口形态做
/// 兼容层，所以看到 `KuGou.dio.get(...)` 时不要以为在发 HTTP 请求。
///
/// ## 调用链
///
/// ```text
/// KuGou.dio.get('/login/qr/key?timestamp=1')
///   → KuGouRustAdapter.fetch()             ← 本文件，进程内
///   → KuGouClient.rawRequest(path, query)  ← FFI，进程内
///   → Rust 直连酷狗上游                     ← 唯一一次真实网络请求
/// ```
///
/// ## 使用
///
/// 在 `main()` 里 `await RustLib.init()` 之后即可工作，无需其他初始化：
///
/// ```dart
/// static final Dio dio = Dio(
///   BaseOptions(baseUrl: "https://kugou.xjinhui.asia/"),
/// )..options.validateStatus = (status) => true
///  ..httpClientAdapter = KuGouRustAdapter();
/// ```
///
/// > `baseUrl` 已不再被访问，保留只是为了不动 `KuGou.dart` 的原有写法。
class KuGouRustAdapter implements HttpClientAdapter {
  KuGouRustAdapter({
    this.platform = 'lite',
    this.identityFileName = 'kugou_identity.json',
  });

  /// 酷狗客户端版本：`'lite'`（概念版）或 `'standard'`（标准版）。
  ///
  /// 默认与原部署一致 —— 服务器环境变量 `platform=lite`。
  final String platform;

  /// 设备身份文件名，落在应用文档目录下。
  ///
  /// ⚠️ 必须放在**绝对路径**（移动端的当前工作目录不可写）。
  /// 文件内含 `dfid`/`token`，已在 `.gitignore` 中排除。
  final String identityFileName;

  KuGouClient? _client;

  /// 懒加载 Rust 客户端。
  ///
  /// 不能放在构造函数里 —— `createClient` 是异步的，而 `KuGou.dio` 是
  /// `static final`，初始化是同步的。
  Future<KuGouClient> _ensureClient() async {
    if (_client != null) return _client!;

    final dir = await getApplicationDocumentsDirectory();
    _client = await createClient(
      platform: platform,
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
    //    所以这里直接取它的 path 与 queryParameters 即可，不用自己解析字符串。
    final uri = options.uri;
    final path = uri.path;
    final query = Map<String, String>.from(uri.queryParameters);

    final KuGouClient client;
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
      body = await client.rawRequest(path: path, query: query);
    } catch (e) {
      // 与原实现一致：网络层失败时 dio 抛异常，由调用方的 try/catch 接住。
      throw DioException(requestOptions: options, error: e, message: '$e');
    }

    // 业务失败（`status: 0` / `error_code != 0`）**不**算异常 —— 原服务器也是
    // 用 HTTP 200 返回这类响应体，由 `KuGou.dart` 自己判断 `status`。
    return ResponseBody.fromString(
      body,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {
    // 客户端由 Rust 侧持有，无需在此释放。
  }
}
