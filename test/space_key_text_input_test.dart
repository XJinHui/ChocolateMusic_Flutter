// 回归测试：焦点在输入框内时，空格应该输入空格，而不是切换播放/暂停。
import 'dart:io';

import 'package:chocolate_music/Management.dart';
import 'package:chocolate_music/PlayMusicControl.dart';
import 'package:chocolate_music/Type.dart';
import 'package:chocolate_music/components/PlaybackControlBar.dart' as bar;
import 'package:chocolate_music/components/TopToolBar.dart';
import 'package:chocolate_music/pages/computer/PlaylistPage.dart' as playlist;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

int _toggleCount = 0;

/// 读取输入框当前文本。SearchBar 的 controller 是 State 私有的，
/// 所以从 EditableText 上把它取回来。
String _fieldText(WidgetTester tester) =>
    tester.widget<EditableText>(find.byType(EditableText)).controller.text;

/// 播放器在测试环境无法初始化，用子类替换掉会碰真实 player 的方法。
class _FakePlayMusicControl extends PlayMusicControl {
  _FakePlayMusicControl(super.management);

  @override
  void pausePlayMusic() => _toggleCount++;

  @override
  void updateVolume(int volume) {}
}

void _stubPausePlayMusic() {
  Management().playMusicControl = _FakePlayMusicControl(Management());
}

Future<void> _mount(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final management = Management();
  management.setting = Setting(
    playType: 0,
    volume: 50,
    volumeType: true,
    qualityTier: 0,
    downloadQualityTier: 0,
    downloadPath: '',
  );
  management.playbackState = PlaybackState(
    name: 'Space song',
    singer: 'Singer',
    singerId: '',
    album: '',
    albumId: '',
    time: '03:00',
    cover: '',
    like: false,
    id: 'test',
    play: true,
    playlistId: '',
    playlistType: 0,
  );
  management.lyricShow = false;

  // 先只挂输入框并让它拿到焦点，再挂播放栏。
  // PlaybackControlBar 的 initState 里只登记 early key handler，
  // 不需要测试环境里拿不到的 Player，因此延迟挂载最省事。
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: Column(children: [child])),
    ),
  );
  await tester.pumpAndSettle();
  if (find.byType(TextField).evaluate().isNotEmpty) {
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
  }

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: Column(children: [child, bar.PlaybackControlBar()])),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    // 只有 FakePlayer 是纯 Dart，其余平台实现在测试里会抛
    // "MediaKit.ensureInitialized must be called before using any API"。
    // 直接指定构建产物里的 libmpv，避免依赖 PATH。
    MediaKit.ensureInitialized(
      libmpv: [
        Directory.current.path,
        'build',
        'windows',
        'x64',
        'libmpv',
        'libmpv-2.dll',
      ].join(Platform.pathSeparator),
    );
    // 和 main.dart 一样切到 FFI 实现，否则 Management.init() 里的
    // openDatabase 会抛 Bad state: databaseFactory not initialized。
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    _toggleCount = 0;
  });

  testWidgets('焦点在 PlaylistPage 搜索框时空格输入空格', (tester) async {
    // 第一次访问 Management 单例会触发 init()，测试环境下它必然抛异常。
    // 必须放在 testWidgets 内部触发，否则这个异步异常会落到测试结束之后，
    // 被记到下一个用例头上。
    _stubPausePlayMusic();

    await _mount(tester, const playlist.SearchBar(listVersion: 0));

    final field = find.byType(TextField);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();

    expect(_toggleCount, 0, reason: '输入框聚焦时按下空格不应该触发播放/暂停');

    // 输入框自身也会注册空格快捷键，但只返回 ignored，把插入空格交给 IME；
    // 因此这里不能断言"事件被消费"，否则等于要求平台层别送字符。
    await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();

    // 真实平台会在这时下发 text input 的 " " 字符，补上以走完整链路。
    await tester.enterText(field, ' ');
    await tester.pumpAndSettle();

    expect(_fieldText(tester), ' ');
    expect(_toggleCount, 0, reason: '输入框聚焦时不应该触发播放/暂停');
  });

  testWidgets('焦点在 TopToolBar 搜索框时空格输入空格', (tester) async {
    _stubPausePlayMusic();

    await _mount(tester, const ToolbarSearchBar());

    final field = find.byType(TextField);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();

    expect(_toggleCount, 0, reason: '输入框聚焦时按下空格不应该触发播放/暂停');

    await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();

    await tester.enterText(field, ' ');
    await tester.pumpAndSettle();

    expect(_fieldText(tester), ' ');
    expect(_toggleCount, 0, reason: '输入框聚焦时不应该触发播放/暂停');
  });

  testWidgets('焦点不在输入框时空格仍然切换播放/暂停', (tester) async {
    _stubPausePlayMusic();

    await _mount(tester, const SizedBox.shrink());

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();

    expect(_toggleCount, 1, reason: '没有输入框聚焦时空格应保留快捷键行为');
  });
}
