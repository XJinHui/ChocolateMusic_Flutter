import 'package:chocolate_music/components/LyricsTransition.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _pageKey = ValueKey('page');
const _flightKey = ValueKey('lyrics-flying-cover');

Widget _fixture(
  ValueNotifier<bool> visible, {
  bool anchors = true,
  bool reduced = false,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduced),
      child: ValueListenableBuilder<bool>(
        valueListenable: visible,
        builder: (context, show, _) => LyricsTransitionHost(
          visible: show,
          coverUrl: '',
          page: Stack(
            key: _pageKey,
            children: [
              const Positioned.fill(
                child: LyricsTransitionPart(
                  background: true,
                  child: ColoredBox(color: Colors.black),
                ),
              ),
              if (anchors)
                const Positioned(
                  left: 100,
                  top: 80,
                  width: 260,
                  height: 260,
                  child: LyricsCoverAnchor(
                    destination: true,
                    child: ColoredBox(color: Colors.blue),
                  ),
                ),
              const LyricsTransitionPart(child: Text('lyrics')),
            ],
          ),
          child: Stack(
            children: [
              if (anchors)
                const Positioned(
                  left: 20,
                  top: 500,
                  width: 70,
                  height: 70,
                  child: LyricsCoverAnchor(
                    child: ColoredBox(color: Colors.blue),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'disposing without ever opening lyrics does not create a late ticker',
    (tester) async {
      final visible = ValueNotifier(false);
      addTearDown(visible.dispose);
      await tester.pumpWidget(_fixture(visible));
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'disposing during flight cancels tickers and queued layout work',
    (tester) async {
      final visible = ValueNotifier(false);
      addTearDown(visible.dispose);
      await tester.pumpWidget(_fixture(visible));
      visible.value = true;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'resizing mid-flight keeps a single overlay and permits closing',
    (tester) async {
      final visible = ValueNotifier(false);
      addTearDown(visible.dispose);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_fixture(visible));
      visible.value = true;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      await tester.pumpAndSettle();
      expect(find.byKey(_pageKey), findsOneWidget);
      visible.value = false;
      await tester.pumpAndSettle();
      expect(find.byKey(_pageKey), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'cover travels between anchors and page survives until exit finishes',
    (tester) async {
      final visible = ValueNotifier(false);
      addTearDown(visible.dispose);
      await tester.pumpWidget(_fixture(visible));
      visible.value = true;
      await tester.pump();
      await tester.pump();
      expect(
        tester.getRect(find.byKey(_flightKey)),
        const Rect.fromLTWH(20, 500, 70, 70),
      );
      await tester.pump(const Duration(milliseconds: 180));
      final middle = tester.getRect(find.byKey(_flightKey));
      expect(middle.width, inExclusiveRange(70, 260));
      expect(middle.top, inExclusiveRange(80, 500));
      await tester.pumpAndSettle();
      expect(find.byKey(_flightKey), findsNothing);
      expect(find.byKey(_pageKey), findsOneWidget);
      visible.value = false;
      await tester.pump();
      expect(
        tester.getRect(find.byKey(_flightKey)),
        const Rect.fromLTWH(100, 80, 260, 260),
      );
      await tester.pump(const Duration(milliseconds: 160));
      expect(find.byKey(_pageKey), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.byKey(_pageKey), findsNothing);
      expect(find.byKey(_flightKey), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'reversing an in-flight opening retains position and a single page',
    (tester) async {
      final visible = ValueNotifier(false);
      addTearDown(visible.dispose);
      await tester.pumpWidget(_fixture(visible));
      visible.value = true;
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 180));
      final before = tester.getRect(find.byKey(_flightKey));
      visible.value = false;
      await tester.pump();
      expect(tester.getRect(find.byKey(_flightKey)), before);
      expect(find.byKey(_pageKey), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 40));
      visible.value = true;
      await tester.pumpAndSettle();
      expect(find.byKey(_pageKey), findsOneWidget);
      expect(find.byKey(_flightKey), findsNothing);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('missing anchors still fade and close', (tester) async {
    final visible = ValueNotifier(false);
    addTearDown(visible.dispose);
    await tester.pumpWidget(_fixture(visible, anchors: false));
    visible.value = true;
    await tester.pumpAndSettle();
    expect(find.byKey(_pageKey), findsOneWidget);
    visible.value = false;
    await tester.pumpAndSettle();
    expect(find.byKey(_pageKey), findsNothing);
  });

  testWidgets('reduced motion skips flight and removes the page immediately', (
    tester,
  ) async {
    final visible = ValueNotifier(false);
    addTearDown(visible.dispose);
    await tester.pumpWidget(_fixture(visible, reduced: true));
    visible.value = true;
    await tester.pumpAndSettle();
    expect(find.byKey(_flightKey), findsNothing);
    visible.value = false;
    await tester.pump();
    expect(find.byKey(_pageKey), findsNothing);
  });
}
