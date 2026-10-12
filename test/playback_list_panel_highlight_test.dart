// PlaybackListPanel 里"当前播放歌曲"高亮的刷新行为。
//
// 用空 cover 让 RemoteImage 走 Image.network('') 的 errorBuilder，
// 避免测试里发真实网络请求。
import 'package:chocolate_music/Management.dart';
import 'package:chocolate_music/Type.dart';
import 'package:chocolate_music/components/PlaybackListPanel.dart';
import 'package:bootstrap_icons/bootstrap_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Music _music(String id) => Music(
  id: id,
  name: 'song-$id',
  singer: 'singer',
  singerId: 'singer-1',
  album: 'album',
  albumId: 'album-1',
  time: 180000,
  cover: '',
);

int _playIconCount() => find.byIcon(BootstrapIcons.play_fill).evaluate().length;

void main() {
  testWidgets('切歌后高亮立刻跟随 playbackState.id，不需要鼠标悬停', (WidgetTester tester) async {
    final Management m = Management();
    m.playbackState.id = '';
    m.currentPlayMusicList = [_music('a'), _music('b'), _music('c')];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SizedBox(width: 350, child: PlaybackListPanel())),
      ),
    );
    await tester.pump();

    expect(_playIconCount(), 0, reason: '还没有在播的歌，列表应显示序号');

    m.playbackState.id = 'b';
    m.refresh();
    await tester.pump();

    // 修复前这里还是 0：侧边栏挂在 AnimatedBuilder 的 child 上，
    // 没有任何组件订阅 Management，整棵面板只在鼠标悬停时才重建。
    expect(_playIconCount(), 1, reason: '切歌后应立刻只高亮新歌曲这一行');
  });

  testWidgets('切歌后旧行恢复序号、新行高亮', (WidgetTester tester) async {
    final Management m = Management();
    m.playbackState.id = 'a';
    m.currentPlayMusicList = [_music('a'), _music('b')];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SizedBox(width: 350, child: PlaybackListPanel())),
      ),
    );
    await tester.pump();
    expect(_playIconCount(), 1);

    m.playbackState.id = 'b';
    m.refresh();
    await tester.pump();

    // 图标仍然只有一个（b），a 那行要回到普通序号状态
    expect(_playIconCount(), 1);
    expect(find.text('1'), findsOneWidget, reason: '失去焦点的行应恢复显示序号');
  });
}
