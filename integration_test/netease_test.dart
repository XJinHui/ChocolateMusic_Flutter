// 网易云 Rust 绑定的集成测试
//
// 运行（需要桌面设备）：
//   flutter test integration_test/netease_test.dart -d windows
//
// 只测**免登录接口**与**纯函数**，不会改动任何账号数据。
// 需要登录的接口（歌单、推荐等）请手动在 App 里验证。

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:chocolate_music/Cloud/NetEaseCloud.dart';
import 'package:chocolate_music/src/rust/frb_generated.dart';
import 'package:chocolate_music/src/rust/third_party/netease/frb_api.dart' as ne;

/// 一个稳定的公开歌曲 ID（Beyond《海阔天空》）
const kSongId = '347230';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async => RustLib.init());

  group('纯函数（无需网络）', () {
    test('version 返回非空', () async {
      expect(await ne.version(), isNotEmpty);
    });

    test('路由清单覆盖 29 条客户端路由 + 1 条启动流程', () async {
      final supported = await ne.supportedRoutes();
      final unsupported = await ne.unsupportedRoutes();

      expect(supported.length + unsupported.length, 30);
      expect(unsupported, isEmpty, reason: '应全部已实现');

      // 抽查几条关键路由
      expect(supported, contains('/song/url'));
      expect(supported, contains('/ad/get'));
      expect(supported, contains('/register/anonimous'));
    });
  });

  group('dio adapter（NetEaseCloud.dart 的真实路径）', () {
    test('/login/qr/key 返回 {data: {unikey}}', () async {
      final r = await Neteasecloud.dio.get('/login/qr/key');
      expect(r.statusCode, 200);
      expect(r.data['code'], 200, reason: '${r.data}');

      // ⚠️ 上游 body 被整体塞进 data —— 客户端读的正是 response.data['data']['unikey']
      final unikey = r.data['data']?['unikey'];
      expect(unikey, isA<String>());
      expect(unikey, isNotEmpty);
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('/login/qr/create 本地生成二维码（不发网络请求）', () async {
      final key = (await Neteasecloud.dio.get('/login/qr/key')).data['data']['unikey'];

      final r = await Neteasecloud.dio.get(
        '/login/qr/create?key=$key&qrimg=true',
      );
      expect(r.statusCode, 200);
      expect(r.data['code'], 200);
      expect(r.data['data']['qrurl'], contains('codekey='));
      expect(
        r.data['data']['qrimg'],
        startsWith('data:image/png;base64,'),
        reason: '客户端需要 data URL',
      );
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('/song/detail 返回 songs[].ar/al/dt', () async {
      final r = await Neteasecloud.dio.get('/song/detail?ids=$kSongId');
      expect(r.statusCode, 200);
      expect(r.data['code'], 200, reason: '${r.data}');

      final songs = r.data['songs'] as List;
      expect(songs, isNotEmpty);

      // 客户端 getMusicsDetails 读的字段路径
      final s = songs.first as Map;
      expect(s['id'], isNotNull);
      expect(s['name'], isNotNull);
      expect(s['ar'][0]['id'], isNotNull);
      expect(s['ar'][0]['name'], isNotNull);
      expect(s['al']['id'], isNotNull);
      expect(s['al']['name'], isNotNull);
      expect(s['al']['picUrl'], isNotNull);
      expect(s['dt'], isNotNull);
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('/lyric 返回 lrc.lyric', () async {
      final r = await Neteasecloud.dio.get('/lyric?id=$kSongId');
      expect(r.statusCode, 200);
      expect(r.data['code'], 200, reason: '${r.data}');

      final lyric = r.data['lrc']?['lyric'];
      expect(lyric, isA<String>());
      expect(lyric, isNotEmpty);
      // tlyric 可能为 null，客户端会判空
      expect(r.data.containsKey('tlyric'), isTrue);
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('/search 返回 result.songs（keywords → s 别名）', () async {
      final r = await Neteasecloud.dio.get(
        '/search?type=1&limit=3',
        queryParameters: {'keywords': '海阔天空'},
      );
      expect(r.statusCode, 200);
      expect(r.data['code'], 200, reason: '${r.data}');

      final songs = r.data['result']?['songs'] as List?;
      expect(songs, isNotNull);
      expect(songs, isNotEmpty);
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('/album 返回 songs 与 album', () async {
      // 先拿一个真实存在的专辑 ID（从歌曲详情里取）
      final detail = await Neteasecloud.dio.get('/song/detail?ids=$kSongId');
      final albumId = detail.data['songs'][0]['al']['id'];

      final r = await Neteasecloud.dio.get('/album?id=$albumId');
      expect(r.statusCode, 200);
      expect(r.data['code'], 200, reason: '${r.data}');
      expect(r.data['songs'], isA<List>());
      expect(r.data['album']?['name'], isA<String>());
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('未实现的路径要抛异常，而不是静默返回空', () async {
      await expectLater(
        Neteasecloud.dio.get('/not/a/route'),
        throwsA(isA<Exception>()),
      );
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}
