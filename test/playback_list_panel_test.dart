import 'dart:typed_data' show ByteData;
import 'dart:ui' as ui;

import 'package:chocolate_music/components/PlaybackListPanel.dart';
import 'package:chocolate_music/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_test/flutter_test.dart';

/// 宿主自己插进去的遮罩。MaterialApp 会在 Overlay 里自带一个 ModalBarrier
/// （dismissible=false），所以不能直接 find.byType(ModalBarrier)，否则数不准。
Finder _hostBarrier() => find.descendant(
  of: find.byType(PlaybackListPanelHost),
  matching: find.byWidgetPredicate(
    (Widget w) => w is ModalBarrier && w.dismissible,
  ),
);

/// 给整棵测试树套一层可独立栅格化的边界，供像素级断言使用。
final GlobalKey _captureKey = GlobalKey();

/// 只测宿主本身：用 ValueNotifier 顶替 Management().playlistShow，
/// 避免把整个 Management 单例拖进测试。
Widget _fixture(ValueNotifier<bool> visible, {bool reduced = false}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduced),
      child: RepaintBoundary(
        key: _captureKey,
        child: ValueListenableBuilder<bool>(
          valueListenable: visible,
          builder: (context, show, _) => PlaybackListPanelHost(
            visible: show,
            onDismiss: () => visible.value = false,
            child: const ColoredBox(
              color: Colors.white,
              child: SizedBox.expand(),
            ),
          ),
        ),
      ),
    ),
  );
}

Size _windowSize(WidgetTester tester) =>
    tester.view.physicalSize / tester.view.devicePixelRatio;

/// 把当前测试树按 1:1 像素栅格化，用来检查真实画出来的像素。
///
/// `toImage` 走的是真正的异步管线，在 fake async 的测试时钟下永远等不到，
/// 所以必须放进 [WidgetTester.runAsync] 里执行。
Future<(ui.Image, Offset)> _paintPanel(WidgetTester tester) async {
  final RenderRepaintBoundary boundary = tester
      .renderObject<RenderRepaintBoundary>(find.byKey(_captureKey));
  final Offset origin = boundary.localToGlobal(Offset.zero);
  ui.Image? image;
  await tester.runAsync(() async {
    image = await boundary.toImage(pixelRatio: 1);
  });
  return (image!, origin);
}

void main() {
  testWidgets('关闭时不挂载侧边栏，也不拦截点击', (WidgetTester tester) async {
    final visible = ValueNotifier<bool>(false);
    addTearDown(visible.dispose);

    await tester.pumpWidget(_fixture(visible, reduced: true));

    expect(find.byType(PlaybackListPanel), findsNothing);
    expect(_hostBarrier(), findsNothing);
  });

  testWidgets('打开后侧边栏紧贴右边缘、垂直居中、高为窗口 70%', (WidgetTester tester) async {
    final visible = ValueNotifier<bool>(false);
    addTearDown(visible.dispose);

    await tester.pumpWidget(_fixture(visible, reduced: true));
    visible.value = true;
    await tester.pump();

    final Size window = _windowSize(tester);
    final Rect panel = tester.getRect(find.byType(PlaybackListPanel));

    expect(panel.width, PlaybackListPanelHost.panelWidth);
    expect(
      panel.height,
      closeTo(window.height * PlaybackListPanelHost.panelHeightFactor, 0.01),
    );
    // 紧贴窗口最右边缘，不留缝
    expect(panel.right, closeTo(window.width, 0.01));
    // 垂直居中：上下留白相等
    expect(panel.top, closeTo((window.height - panel.height) / 2, 0.01));
    expect(window.height - panel.bottom, closeTo(panel.top, 0.01));
  });

  testWidgets('点击侧边栏以外区域会关闭侧边栏', (WidgetTester tester) async {
    final visible = ValueNotifier<bool>(false);
    addTearDown(visible.dispose);

    await tester.pumpWidget(_fixture(visible, reduced: true));
    visible.value = true;
    await tester.pump();
    expect(find.byType(PlaybackListPanel), findsOneWidget);

    // 点在窗口左上角，一定落在侧边栏之外
    await tester.tapAt(const Offset(10, 10));
    await tester.pump();

    expect(visible.value, isFalse, reason: '遮罩应把关闭请求交回调用方');
    expect(find.byType(PlaybackListPanel), findsNothing);
  });

  testWidgets('点击侧边栏内部不会关闭', (WidgetTester tester) async {
    final visible = ValueNotifier<bool>(false);
    addTearDown(visible.dispose);

    await tester.pumpWidget(_fixture(visible, reduced: true));
    visible.value = true;
    await tester.pump();

    await tester.tap(find.byType(PlaybackListPanel));
    await tester.pump();

    expect(visible.value, isTrue);
    expect(find.byType(PlaybackListPanel), findsOneWidget);
  });

  testWidgets('关闭动画跑完之前面板和遮罩都还在，不会点击穿透', (WidgetTester tester) async {
    final visible = ValueNotifier<bool>(false);
    addTearDown(visible.dispose);

    await tester.pumpWidget(_fixture(visible));
    visible.value = true;
    await tester.pumpAndSettle();
    expect(find.byType(PlaybackListPanel), findsOneWidget);

    visible.value = false;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));

    // 动画进行中：两者都保留
    expect(find.byType(PlaybackListPanel), findsOneWidget);
    expect(_hostBarrier(), findsOneWidget);

    await tester.pumpAndSettle();

    // 动画结束：一起摘掉
    expect(find.byType(PlaybackListPanel), findsNothing);
    expect(_hostBarrier(), findsNothing);
  });

  testWidgets('面板是纯白，且面板以外被暗化遮罩压暗', (WidgetTester tester) async {
    final visible = ValueNotifier<bool>(false);
    addTearDown(visible.dispose);

    await tester.pumpWidget(_fixture(visible, reduced: true));
    visible.value = true;
    await tester.pump();

    // 面板本体：纯白
    final Container surface = tester.widget<Container>(
      find.descendant(
        of: find.byType(PlaybackListPanel),
        matching: find.byWidgetPredicate(
          (Widget w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration! as BoxDecoration).boxShadow != null,
        ),
      ),
    );
    expect(
      (surface.decoration! as BoxDecoration).color,
      AppColors.overlaySurface,
    );

    // 面板以外：不是全透明，必须压暗页面，否则白面板在白页面上分不出来
    final ModalBarrier barrier = tester.widget<ModalBarrier>(_hostBarrier());
    expect(barrier.color, isNotNull);
    expect(barrier.color!.a, greaterThan(0));
  });

  testWidgets('面板带边缘阴影，方向朝左', (WidgetTester tester) async {
    final visible = ValueNotifier<bool>(false);
    addTearDown(visible.dispose);

    await tester.pumpWidget(_fixture(visible, reduced: true));
    visible.value = true;
    await tester.pump();

    // 面板里还有分隔线等其他 Container，这里只取真正带投影的那一个
    final Container panel = tester.widget<Container>(
      find.descendant(
        of: find.byType(PlaybackListPanel),
        matching: find.byWidgetPredicate(
          (Widget w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration! as BoxDecoration).boxShadow != null,
        ),
      ),
    );
    final BoxDecoration decoration = panel.decoration! as BoxDecoration;
    final List<BoxShadow> shadows = decoration.boxShadow!;

    expect(shadows, isNotEmpty, reason: '面板需要投影才能从背景里浮起来');
    // 面板贴着窗口右边缘，右半边没有落影空间，主投影必须朝左打。
    expect(
      shadows.any((BoxShadow s) => s.offset.dx < 0 && s.blurRadius > 0),
      isTrue,
      reason: '朝左的主投影负责面板与底下内容之间的分界',
    );
  });

  testWidgets('内容被裁到圆角内，底部圆弧不会被列表盖掉', (WidgetTester tester) async {
    final visible = ValueNotifier<bool>(false);
    addTearDown(visible.dispose);

    await tester.pumpWidget(_fixture(visible, reduced: true));
    visible.value = true;
    await tester.pump();

    // 子内容必须被显式裁到圆角：Container 默认 clipBehavior 是 Clip.none，
    // 圆角只是画出来的、不裁剪，列表会直接盖到圆角外面去。
    expect(
      find.descendant(
        of: find.byType(PlaybackListPanel),
        matching: find.byType(ClipRRect),
      ),
      findsWidgets,
      reason: '面板内容需要 ClipRRect 才能保住底部圆弧',
    );

    // 光有 widget 不够，实际画出来才能确认圆角真的生效：
    // 贴着面板左下角取像素，落在圆角外的位置应该看不到内容。
    final Rect panel = tester.getRect(find.byType(PlaybackListPanel));
    final (ui.Image image, Offset origin) = await _paintPanel(tester);
    ByteData? bytes;
    await tester.runAsync(() async {
      bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    });
    final int side = image.width;

    Color pixelAt(double x, double y) {
      final int px = (x - origin.dx).round();
      final int py = (y - origin.dy).round();
      final int offset = ((py * side) + px) * 4;
      final ByteData data = bytes!;
      return Color.fromARGB(
        data.getUint8(offset + 3),
        data.getUint8(offset),
        data.getUint8(offset + 1),
        data.getUint8(offset + 2),
      );
    }

    // 面板底色和底下页面都是纯白，所以这里断言的不是颜色而是"有没有被裁掉"：
    // 圆弧外的像素若和面板内部的白色完全一致，说明内容盖到了圆角外。
    final Color outsideArc = pixelAt(panel.left + 1, panel.bottom - 1);
    final Color insideBody = pixelAt(panel.left + 40, panel.bottom - 60);
    debugPrint('CORNER outside=$outsideArc inside=$insideBody');

    expect(insideBody.a, 1.0, reason: '面板主体应当是不透明的白色');
    expect(
      outsideArc,
      isNot(insideBody),
      reason: '左下角圆弧外的像素不该被面板填满，否则圆弧被列表盖掉了',
    );
    image.dispose();
  });

  testWidgets('打开过程中面板从右边缘外侧滑入', (WidgetTester tester) async {
    final visible = ValueNotifier<bool>(false);
    addTearDown(visible.dispose);

    await tester.pumpWidget(_fixture(visible));
    visible.value = true;
    await tester.pump();

    final Size window = _windowSize(tester);

    // 第一帧：面板完全停在右边缘之外
    expect(tester.getRect(find.byType(PlaybackListPanel)).left, window.width);

    await tester.pumpAndSettle();

    // 结束后靠右边缘对齐
    expect(
      tester.getRect(find.byType(PlaybackListPanel)).right,
      closeTo(window.width, 0.01),
    );
  });
}
