import 'package:chocolate_music/Management.dart';
import 'package:chocolate_music/Type.dart';
import 'package:chocolate_music/pages/computer/LyricsPage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 取单例并摆好与用例无关的状态。
///
/// 必须在用例内部取：首次访问 Management 会触发 [Management.init]，
/// 它在测试环境下必然抛异常，落在用例之外就会被记到整个测试文件头上。
Management _seed(List<LyricsMap> lyrics) {
  final Management management = Management();
  management.displayLyricList = lyrics;
  management.lyricLineNotifier.value = 0;
  management.notifyListeners();
  return management;
}

List<LyricsMap> _lyrics(int count) => [
  for (int i = 0; i < count; i++)
    LyricsMap(time: i * 1000, lyric: ['第 $i 行歌词']),
];

Future<void> _mount(WidgetTester tester, List<LyricsMap> lyrics) async {
  tester.view.physicalSize = const Size(900, 700);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  _seed(lyrics);
  await tester.pumpWidget(
    const MaterialApp(
      home: Scaffold(body: SizedBox(width: 400, height: 600, child: DisplayLyric())),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('歌词列表用 dstIn 遮罩做上下渐隐', (tester) async {
    await _mount(tester, _lyrics(40));

    final Finder mask = find.byType(ShaderMask);
    expect(mask, findsOneWidget);
    expect(tester.widget<ShaderMask>(mask).blendMode, BlendMode.dstIn);
    expect(tester.takeException(), isNull);
  });

  testWidgets('遮罩铺在视口上，而不是跟着歌词一起滚', (tester) async {
    await _mount(tester, _lyrics(40));

    final Finder mask = find.byType(ShaderMask);
    final Finder scrollView = find.byType(SingleChildScrollView);

    // 遮罩尺寸就是滚动视口尺寸：渐隐固定在屏幕上。
    // 若哪天把 ShaderMask 挪进滚动内容里，尺寸会变成整段歌词的高度，
    // 渐隐就会跟着歌词滚走 —— 这条断言会拦住它。
    expect(tester.getSize(mask), tester.getSize(scrollView));

    // 反过来也确认一次层级：遮罩在滚动视图外面。
    expect(
      find.descendant(of: scrollView, matching: mask),
      findsNothing,
    );
    expect(
      find.ancestor(of: scrollView, matching: mask),
      findsOneWidget,
    );
  });

  testWidgets('渐隐不影响歌词渲染', (tester) async {
    await _mount(tester, _lyrics(40));

    // 视口内应当能看到若干行歌词，且当前行照常高亮。
    expect(find.text('第 0 行歌词'), findsOneWidget);
    expect(find.text('第 1 行歌词'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('歌词行数变化时遮罩与列表一起更新', (tester) async {
    await _mount(tester, _lyrics(40));
    expect(find.byType(ShaderMask), findsOneWidget);

    // 换歌：整段列表被替换。
    _seed(_lyrics(3));
    await tester.pumpAndSettle();

    expect(find.text('第 0 行歌词'), findsOneWidget);
    expect(find.byType(ShaderMask), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
