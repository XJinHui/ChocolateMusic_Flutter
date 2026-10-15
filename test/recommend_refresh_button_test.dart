import 'dart:async';

import 'package:bootstrap_icons/bootstrap_icons.dart';
import 'package:chocolate_music/Cloud/CloudService.dart';
import 'package:chocolate_music/FileManage.dart';
import 'package:chocolate_music/Management.dart';
import 'package:chocolate_music/Type.dart';
import 'package:chocolate_music/pages/computer/RecommendPage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 歌单请求挂在 [gate] 上，好让「刷新中」这个中间态停住慢慢观察。
class _GatedCloud extends CloudService {
  final Completer<void> gate = Completer<void>();
  int playlistCalls = 0;

  @override
  dynamic getRecommendPlaylists(int num) async {
    playlistCalls++;
    await gate.future;
    return [Playlist(name: '测试歌单', listId: 'p1', cover: '', audioCount: 1)];
  }
}

/// 推荐列表落盘会写到 flutter_tester 可执行文件旁边，测试里换成空实现。
class _NoopFileManage extends FileManage {
  @override
  Future<void> writeRecommendListDate(
    List<RecommendList> recommendListDate,
  ) async {}
}

/// 取单例并换上不打网络、不落盘的桩。
///
/// 必须在用例内部取：首次访问 Management 会触发 [Management.init]，它在
/// 测试环境下必然抛异常，落在用例之外就会被记到整个测试文件头上。
Management _seed(CloudService cloud) {
  final Management management = Management();
  management.accountData = AccountData(login: [0, 0], data: [[], [], []]);
  management.fileManage = _NoopFileManage();
  management.cloud = cloud;
  return management;
}

/// 按钮图标当前的旋转圈数（0~1，一圈为一个周期）。
double _turns(WidgetTester tester) => tester
    .widget<RotationTransition>(
      find.descendant(
        of: find.byType(RecommendTitle),
        matching: find.byType(RotationTransition),
      ),
    )
    .turns
    .value;

Future<void> _pumpButton(WidgetTester tester, String title) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: RecommendTitle(
          title: title,
          icon: BootstrapIcons.music_note_list,
        ),
      ),
    ),
  );
}

/// 按钮图标的基础倾角，没有就是没套 RotatedBox。
int? _baseTilt(WidgetTester tester) {
  final Finder finder = find.descendant(
    of: find.byType(RecommendTitle),
    matching: find.byType(RotatedBox),
  );
  if (finder.evaluate().isEmpty) {
    return null;
  }
  return tester.widget<RotatedBox>(finder).quarterTurns;
}

void main() {
  testWidgets('刷新按钮保持原来的基础倾角，播放按钮不倾斜', (WidgetTester tester) async {
    await _pumpButton(tester, '歌单');
    expect(_baseTilt(tester), 45, reason: '刷新图标静止时的角度要和加动画之前一致');

    await _pumpButton(tester, '歌曲');
    expect(_baseTilt(tester), isNull);
  });

  testWidgets('刷新期间图标持续旋转，请求结束后归位停下', (WidgetTester tester) async {
    final _GatedCloud cloud = _GatedCloud();
    _seed(cloud);

    await _pumpButton(tester, '歌单');
    expect(_turns(tester), 0, reason: '空闲时图标应当静止在起始角度');

    await tester.tap(find.byType(GestureDetector));
    await tester.pump();

    expect(cloud.playlistCalls, 1);
    expect(_turns(tester), 0, reason: '刚点下还没走时间，动画尚在起点');

    await tester.pump(const Duration(milliseconds: 300));
    final double spinning = _turns(tester);
    expect(spinning, greaterThan(0), reason: '请求没回来时图标要一直转');

    cloud.gate.complete();
    // 放行后还要转满当前这一圈才停，900ms 一圈，给足两圈的时间。
    await tester.pump(const Duration(milliseconds: 1800));

    expect(_turns(tester), 0, reason: '结束后停在整圈位置，不残留角度');

    // 停下之后不应该再有 ticker 在跑。
    await tester.pump(const Duration(milliseconds: 300));
    expect(_turns(tester), 0);
  });

  testWidgets('刷新中连点只发一次请求', (WidgetTester tester) async {
    final _GatedCloud cloud = _GatedCloud();
    _seed(cloud);

    await _pumpButton(tester, '歌单');
    await tester.tap(find.byType(GestureDetector));
    await tester.pump();

    await tester.tap(find.byType(GestureDetector));
    await tester.tap(find.byType(GestureDetector));
    await tester.pump();

    expect(cloud.playlistCalls, 1);

    cloud.gate.complete();
    await tester.pump(const Duration(milliseconds: 1800));
  });

  testWidgets('接口很快时动画也至少转满一圈', (WidgetTester tester) async {
    final _GatedCloud cloud = _GatedCloud();
    _seed(cloud);
    cloud.gate.complete(); // 请求立刻返回

    await _pumpButton(tester, '歌单');
    await tester.tap(find.byType(GestureDetector));
    await tester.pump();

    // 请求已经回来了，但动画不能一闪而过。
    await tester.pump(const Duration(milliseconds: 300));
    expect(_turns(tester), greaterThan(0));

    await tester.pump(const Duration(milliseconds: 600));
    expect(_turns(tester), 0, reason: '满一圈后收工');
  });
}
