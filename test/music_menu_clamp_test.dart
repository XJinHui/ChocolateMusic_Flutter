import 'package:chocolate_music/Type.dart';
import 'package:chocolate_music/components/MusicComponents.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Music _music() => Music(
  id: '1',
  name: '测试歌曲',
  singer: '歌手',
  singerId: 's1',
  album: '专辑',
  albumId: 'a1',
  time: 180000,
  cover: '',
);

/// 菜单面板：透明 Material 包着「播放」菜单项
Finder _panelFinder() {
  return find.ancestor(
    of: find.text('播放'),
    matching: find.byWidgetPredicate(
      (w) => w is Material && w.type == MaterialType.transparency,
    ),
  );
}

void main() {
  testWidgets('右键菜单弹在窗口边缘时自动收回、完整可见', (tester) async {
    tester.view.physicalSize = const Size(900, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox())),
    );

    final BuildContext ctx = tester.element(find.byType(Scaffold));

    final Map<String, Offset> cases = <String, Offset>{
      '中心': const Offset(450, 300),
      '左上角': const Offset(2, 2),
      '右上角': const Offset(897, 3),
      '左下角': const Offset(3, 597),
      '右下角': const Offset(896, 598),
    };

    for (final MapEntry<String, Offset> entry in cases.entries) {
      MusicSelected.show(ctx, entry.value, _music());
      await tester.pump();

      final Rect rect = tester.getRect(_panelFinder());
      expect(
        rect.left,
        greaterThanOrEqualTo(8),
        reason: '${entry.key}: left=${rect.left}',
      );
      expect(
        rect.top,
        greaterThanOrEqualTo(8),
        reason: '${entry.key}: top=${rect.top}',
      );
      expect(
        rect.right,
        lessThanOrEqualTo(892),
        reason: '${entry.key}: right=${rect.right}',
      );
      expect(
        rect.bottom,
        lessThanOrEqualTo(592),
        reason: '${entry.key}: bottom=${rect.bottom}',
      );
    }
  });
}
