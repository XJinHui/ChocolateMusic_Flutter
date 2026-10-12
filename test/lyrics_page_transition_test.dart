import 'package:bootstrap_icons/bootstrap_icons.dart';
import 'package:chocolate_music/Management.dart';
import 'package:chocolate_music/Type.dart';
import 'package:chocolate_music/components/LyricsTransition.dart';
import 'package:chocolate_music/components/PlaybackControlBar.dart' as bar;
import 'package:chocolate_music/components/RemoteImage.dart';
import 'package:chocolate_music/pages/computer/LyricsPage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _mountPlayer(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1100, 740);
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
    name: 'Transition song',
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
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ListenableBuilder(
          listenable: management,
          builder: (context, _) => LyricsTransitionHost(
            visible: management.lyricShow,
            coverUrl: management.playbackState.cover,
            page: LyricsPage(),
            child: Stack(
              children: [
                Positioned(
                  left: 180,
                  right: 10,
                  bottom: 10,
                  child: bar.PlaybackControlBar(),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'real small cover opens and down arrow animates before removing lyrics',
    (tester) async {
      await _mountPlayer(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(bar.MusicData),
          matching: find.byType(RemoteImage),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(LyricsPage), findsOneWidget);
      await tester.tap(find.byIcon(BootstrapIcons.chevron_down));
      await tester.pump();
      expect(find.byType(LyricsPage), findsOneWidget);
      expect(find.byKey(const ValueKey('lyrics-flying-cover')), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.byType(LyricsPage), findsNothing);
      expect(Management().playbackState.play, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('pressed large cover closes immediately from its scaled bounds', (
    tester,
  ) async {
    await _mountPlayer(tester);
    Management().lyricShow = true;
    await tester.pumpAndSettle();
    final cover = find.descendant(
      of: find.byType(MusicDisplayWidget),
      matching: find.byType(RemoteImage),
    );
    final fullWidth = tester.getSize(cover).width;
    final gesture = await tester.startGesture(tester.getCenter(cover));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 120));
    await gesture.up();
    await tester.pump();
    expect(Management().lyricShow, isFalse);
    final flying = tester.getRect(
      find.byKey(const ValueKey('lyrics-flying-cover')),
    );
    expect(flying.width, closeTo(fullWidth * .95, .1));
    await tester.pumpAndSettle();
    expect(find.byType(LyricsPage), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
