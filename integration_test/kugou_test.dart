// KuGou Rust 绑定的集成测试
//
// 运行（需要桌面设备）：
//   flutter test integration_test/kugou_test.dart -d windows
//
// 只测**纯函数**与**免登录接口**，不会修改任何账号数据。

import 'package:chocolate_music/Cloud/KuGou.dart';
import 'package:chocolate_music/src/rust/frb_api.dart';
import 'package:chocolate_music/src/rust/frb_generated.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async => RustLib.init());

  group('纯函数（无需网络）', () {
    test('version 返回非空', () async {
      final v = await version();
      expect(v, isNotEmpty);
    });

    test('processLyric 剔除元数据行', () async {
      final out = await processLyric(
        lrc: '[ti:标题]\n[ar:歌手]\n[00:01.23]第一句\n[00:05.678]第二句\n',
      );
      expect(out, '[00:01.23]第一句\n[00:05.678]第二句');
    });

    test('krcToLrc 转换逐字时间轴', () async {
      final out = await krcToLrc(krc: '[1000,500]<0,100,0>你<100,100,0>好');
      expect(out.trim(), '[00:01.00]<00:01.00>你<00:01.10>好');
    });

    // 注：msToLrcTime 的参数是 PlatformInt64（native 为 BigInt / web 为 int），
    // 跨平台写法繁琐，其正确性已由 Rust 侧单元测试覆盖，这里不重复测。

    test('getCover 替换尺寸占位符', () async {
      expect(
        await getCover(url: 'http://x.com/{size}/a.jpg', size: '500'),
        'http://x.com/500/a.jpg',
      );
      expect(
        await getCover(url: 'http://x.com/240/a.jpg', size: '500'),
        'http://x.com/500/a.jpg',
      );
    });

    test('calculateMid 与已知值一致', () async {
      // 实测抓到的真实对应关系
      final mid = await calculateMid(guid: '9ff61aff817a622bbd823f5335d1c13e');
      expect(mid, '160675323861738230175415575945740081866');
    });

    test('uuidV4 生成合法 UUID', () async {
      final u = await uuidV4();
      expect(u.length, 36);
      expect(await isUuidV4(s: u), isTrue);
    });
  });

  group('客户端（免登录接口）', () {
    test('创建客户端并读到设备身份', () async {
      final dir = await getApplicationDocumentsDirectory();
      final client = await createClient(
        platform: 'lite',
        identityPath: '${dir.path}/kugou_test_identity.json',
      );

      // MID 是 39 位十进制
      final mid = await client.deviceMid();
      expect(mid.length, 39);
      // ⚠️ 不能用 int.tryParse —— 39 位十进制超出 Dart int 的 64 位范围会返回 null
      expect(RegExp(r'^\d+$').hasMatch(mid), isTrue, reason: 'MID 应全为数字: $mid');
      expect(BigInt.tryParse(mid), isNotNull);

      // GUID 是 32 位 hex
      expect((await client.deviceGuid()).length, 32);

      expect(await client.isLoggedIn(), isFalse);
    });

    test('取每日推荐（真实网络）', () async {
      final dir = await getApplicationDocumentsDirectory();
      final client = await createClient(
        platform: 'lite',
        identityPath: '${dir.path}/kugou_test_identity.json',
      );

      // 首次需要注册设备
      if (!await client.hasDfid()) {
        await client.registerDevice();
      }

      final songs = await client.getRecommendMusics(num: 3);
      expect(songs, isNotEmpty);
      for (final s in songs) {
        expect(s.id, isNotEmpty);
        expect(s.name, isNotEmpty);
      }
    }, timeout: const Timeout(Duration(minutes: 2)));
  });

  // ------------------------------------------------------------------
  //  KuGou.dart 的真实调用路径：dio → KuGouRustAdapter → FFI → Rust
  //
  //  这组用例验证「响应体形状」与原自建服务器完全一致 —— 只要它们过了，
  //  KuGou.dart 里那些 response.data[...] 的解析代码就一定能照常工作。
  // ------------------------------------------------------------------
  group('dio adapter（KuGou.dart 的真实路径）', () {
    test('免登录接口返回与原服务器同款的响应体', () async {
      // ① 存活探测：本地没有服务器，恒为成功
      final ping = await KuGou.dio.get('');
      expect(ping.statusCode, 200);
      expect(ping.data['status'], 1);

      // ② /register/dev —— 响应体已 AES 解密
      final dev = await KuGou.dio.get('/register/dev');
      expect(dev.statusCode, 200);
      expect(dev.data['status'], 1, reason: '${dev.data}');

      // ③ /everyday/recommend —— 原始形状是 data.song_list
      final rec = await KuGou.dio.get('/everyday/recommend');
      expect(rec.statusCode, 200);
      expect(rec.data['status'], 1, reason: '${rec.data}');
      final songs = rec.data['data']['song_list'] as List;
      expect(songs, isNotEmpty);

      // ④ /song/url —— 地址在**顶层** url 数组，不在 data 下
      final hash = songs.first['hash'] as String;
      final url = await KuGou.dio.get('/song/url?hash=$hash&quality=128');
      expect(url.statusCode, 200);
      expect(url.data['status'], isA<int>());
      if (url.data['status'] == 1) {
        expect(url.data['url'], isA<List>());
        expect(url.data['url'][0], isNotEmpty);
      }
      // status == 2 表示无版权，上游**完全不返回** url 字段，这也是原样透传

      // ⑤ 未实现的路径要抛异常，而不是静默返回空
      await expectLater(
        KuGou.dio.get('/not/a/route'),
        throwsA(isA<DioException>()),
      );
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}
