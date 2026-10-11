// 网易云 Rust 绑定的集成测试
//
// 运行（需要桌面设备）：
//   flutter test integration_test/netease_test.dart -d windows
//
// 只测**免登录接口**与**纯函数**，不会改动任何账号数据。
// 需要登录的接口（歌单、推荐等）请手动在 App 里验证。

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

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

  group('启动流程（MUSIC_A / NMTID）', () {
    // ------------------------------------------------------------------
    //  回归：登录类接口恒返回 -462「请完成验证操作」
    //
    //  网易云用两个**服务端下发**的身份令牌做风控，精简版最初一个都没接：
    //
    //    令牌      从哪来                        缺了的症状
    //    MUSIC_A   /register/anonimous (xeapi)   二维码登录 -462
    //    NMTID     eapi 响应的 Set-Cookie        手机号登录 -462
    //
    //  NMTID 尤其隐蔽 —— 原实现是「前几次 eapi 请求**故意不带** NMTID，
    //  从 Set-Cookie 捡回服务端下发的值再全局复用」，而精简版跳过了探测、
    //  直接伪造 `00O`+38位hex。伪造值过不了风控。
    //
    //  实测（本机同一时刻）：
    //    伪造的 NMTID  → {"code":-462,...}  请完成验证操作
    //    服务端的 NMTID → {"msg":"账号或密码错误","code":502}  ← 与 Node 服务逐字一致
    // ------------------------------------------------------------------

    test('createClient 会补齐服务端下发的 NMTID 并落盘', () async {
      final dir = await getApplicationDocumentsDirectory();
      final path = '${dir.path}/netease_bootstrap_identity.json';
      final f = File(path);

      // 从**干净状态**开始，确保真的走了一遍探测（而不是读到旧文件）
      if (await f.exists()) await f.delete();

      final client = await ne.createClient(identityPath: path);

      expect(
        await client.hasNmtid(),
        isTrue,
        reason: '拿不到 NMTID 时登录类接口会返回 -462',
      );

      // 必须落盘 —— 否则每次启动都要重新探测
      final saved = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      expect(saved['nmtid'], isA<String>());
      expect(saved['nmtid'], isNotEmpty);

      if (await f.exists()) await f.delete();
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('手机号登录不再被风控拦成 -462', () async {
      // 用假手机号 + 假密码：只关心**有没有过风控**，不关心凭据对不对。
      // 过不了风控时恒为 -462；过了则是 502「账号或密码错误」之类。
      final r = await Neteasecloud.dio.get(
        '/login/cellphone?phone=13800138000&password=definitely_wrong',
      );
      expect(
        r.data['code'],
        isNot(-462),
        reason: 'NMTID 缺失时这里恒为 -462（请完成验证操作）: ${r.data}',
      );
    }, timeout: const Timeout(Duration(minutes: 2)));
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

    // ------------------------------------------------------------------
    //  回归：概率性「连接被重置」
    //
    //  修复前的症状（用户报的就是这个）：
    //
    //    DioException [unknown]:
    //      AnyhowException(网络错误: error sending request for url
    //        (https://interface3.music.163.com/xeapi/ad/get))
    //
    //  两个叠加的坑：
    //
    //  ① Rust 侧把真实错误吃掉了 —— `send_raw` 里 `recover_body` 返回 None 时
    //     统一换成 `Error::Http("请求失败")`，reqwest 的 source 链整个丢失。
    //     二维码登录 / 验证码看到的就是这句毫无信息量的「请求失败」。
    //
    //  ② 根因是 **IPv6**。`*.music.163.com` 都发 AAAA 记录且排在 A 前面，
    //     而本机（手机热点）的 IPv6 出口到该 CDN 是坏的：TCP 看着连上，
    //     紧接着被 RST（`os error 10054`）。
    //
    //     交错对照实测，各 25 次全新连接：
    //       默认（IPv6 优先） 18/25   ← 失败全在这边
    //       强制 IPv4         25/25
    //
    //     修复：`Transport` 的 reqwest 客户端固定 `local_address = 0.0.0.0`，
    //     hyper-util 会把 IPv6 地址整个过滤掉。
    //
    //  这里只断言「不抛异常」—— 广告有没有、`code` 是多少随账号和时段变，
    //  不是这条用例要管的事。
    // ------------------------------------------------------------------
    test('连续请求不再出现概率性连接重置', () async {
      for (var i = 0; i < 6; i++) {
        final r = await Neteasecloud.dio.get('/ad/get');
        expect(r.statusCode, 200, reason: '第 ${i + 1} 次');
      }
    }, timeout: const Timeout(Duration(minutes: 3)));
  });
}
