# Lyrics Cover Transition Implementation Plan

> Execute inline with executing-plans. User authorized implementation on 2026-09-13.

**Goal:** Implement the approved cover expansion and collapse in the desktop player.

**Architecture:** A LyricsTransitionHost owns the animation and delayed page removal. LyricsCoverAnchor measures real source/destination bounds; LyricsTransitionPart animates stable background/content subtrees. ComputerHomePage supplies visibility and artwork, while existing click handlers continue setting lyricShow.

**Tech Stack:** Flutter, AnimationController, RenderBox, flutter_test. No new dependencies.

## Constraints

- Enter 420ms, exit 320ms; preserve current click targets and playback behavior.
- Keep existing workspace edits; modify only transition integration points.
- Fixed background blur; animate composited layers rather than rebuilding lyrics every frame.
- Handle reversal, disposal, reduced motion, unavailable anchors, failed artwork and resizing.

## Tasks

- [x] Add test/lyrics_transition_test.dart: mount the real host with local artwork and anchored fixture layout. Toggle visible; assert intermediate flying bounds, retained page during exit, removed page after exit, reversal without duplicate pages, missing-anchor fallback, resize and disposal safety.
- [x] Run `D:/Flutter/bin/flutter.bat test test/lyrics_transition_test.dart --no-pub` and confirm the missing host is the initial failure.
- [x] Add lib/components/LyricsTransition.dart with `LyricsTransitionHost(visible, coverUrl, child, page)`, `LyricsCoverAnchor(destination, child)` and `LyricsTransitionPart(background, child)`. Measure anchors after mount, hide originals only while flying, finish reverse before unmounting. Preserve one controller and stable child subtrees.
- [x] Modify lib/Computer.dart to wrap its existing base layout and LyricsPage in the host. Modify lib/components/PlaybackControlBar.dart to anchor the small cover. Modify lib/pages/computer/LyricsPage.dart to anchor its cover inside the press transform, animate background/content separately and remove delayed close.
- [x] Run focused tests and targeted static analysis. Add real LyricsPage click tests using initialized Management state if plugin dependencies permit. Review the diff and document desktop visual verification limits.

## Verification results

- Nine animation tests plus the existing app-shell test pass. A regression test first reproduced lazy controller initialization during disposal; initializing the controller in initState fixes it.
- Targeted Dart analysis reports no errors; existing warnings and style diagnostics remain. The new transition filename follows this repository's existing PascalCase component naming.
- The full suite exposed account-page failures involving MediaKit initialization, account state assertions, and empty JSON data. These paths are outside the animation implementation.
- OperationButton accepts an optional lyricMode override so closing the overlay does not switch its icons to the main page colors before fading out.
- Desktop animation smoothness has not been visually verified on a running application.

## Assertions

```dart
expect(find.byKey(const ValueKey('page')), findsOneWidget); // midway through exit
await tester.pumpAndSettle();
expect(find.byKey(const ValueKey('page')), findsNothing); // only after completion
```

Use independently fixed source (20, 500, 70, 70) and destination (100, 80, 260, 260) rectangles. The halfway flight must lie between them; endpoint bounds must match the anchors. Reverse midway and assert the next frame starts at the same rectangle.
