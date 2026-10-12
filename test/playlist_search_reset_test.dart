// 回归测试：歌单内搜索的状态管理。
//
// 搜索结果 displayListSearchMusic 挂在 Management 单例上，不会随页面切换
// 自动失效；而「是否处于搜索态」又必须用独立的关键词来判断，否则搜不到结果
// 时会被当成没在搜索、回退显示整个歌单。
import 'package:chocolate_music/Cloud/CloudService.dart';
import 'package:chocolate_music/Management.dart';
import 'package:chocolate_music/Type.dart';
import 'package:chocolate_music/components/MusicComponents.dart';
import 'package:chocolate_music/pages/computer/PlaylistPage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 删除歌曲要走云端接口，测试里不能真的发请求。
class _FakeCloud extends CloudService {
  @override
  Future<bool> deleteMusicFromPlaylist(String listId, String musicId) async =>
      true;
}

Music _music(String id, String name) => Music(
  id: id,
  name: name,
  singer: 'Singer',
  singerId: 'singer-1',
  album: 'Album',
  albumId: 'album-1',
  time: 180000,
  cover: '',
);

Playlist _playlist(String listId, String name) =>
    Playlist(name: name, listId: listId, cover: '', audioCount: 2);

/// 只在歌曲行里找文字。搜索框里的关键词也是 Text，直接用 find.text 会一起命中。
Finder _songRow(String name) => find.descendant(
  of: find.byType(ComputerMusicWidget),
  matching: find.text(name),
);

final Playlist _playlistA = _playlist('playlist-a', 'Playlist A');
final Playlist _playlistB = _playlist('playlist-b', 'Playlist B');
final Music _alpha = _music('a-1', 'Alpha');
final Music _beta = _music('a-2', 'Beta');
final Music _gamma = _music('b-1', 'Gamma');

/// 复位单例到「刚进入歌单 A」，并渲染出 PlaylistPage。
Future<Management> _mountPlaylistA(WidgetTester tester) async {
  final Management management = Management();
  management.cloud = _FakeCloud();
  management.displayListType = 'Playlist';
  management.displayAlbums = <Album>[];
  management.clearListSearch();

  management.displayList = _playlistA;
  management.playlistMusics[_playlistA.listId] = <Music>[_alpha, _beta];
  management.displayMusics = <Music>[_alpha, _beta];

  await tester.pumpWidget(MaterialApp(home: Scaffold(body: PlaylistPage())));
  await tester.pump();
  return management;
}

/// 走侧边栏同一条入口切到歌单 B。
void _switchToPlaylistB(Management management) {
  management.playlistMusics[_playlistB.listId] = <Music>[_gamma];
  management.getDisplayPlaylist(_playlistB);
}

void main() {
  testWidgets('搜索后切换歌单，不再显示上一个歌单的搜索结果', (tester) async {
    final Management management = await _mountPlaylistA(tester);

    expect(_songRow('Alpha'), findsOneWidget);
    expect(_songRow('Beta'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Alpha');
    await tester.pump();

    expect(_songRow('Alpha'), findsOneWidget);
    expect(_songRow('Beta'), findsNothing, reason: '搜索后应该只剩命中的歌曲');

    _switchToPlaylistB(management);
    await tester.pump();

    expect(_songRow('Gamma'), findsOneWidget);
    expect(
      _songRow('Alpha'),
      findsNothing,
      reason: '歌单 B 不应该残留歌单 A 的搜索结果',
    );

    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      isEmpty,
      reason: '换歌单后旧关键词已经没有意义，输入框应该清空',
    );
  });

  testWidgets('搜索无结果时列表为空，不回退显示整个歌单', (tester) async {
    await _mountPlaylistA(tester);

    await tester.enterText(find.byType(TextField), 'zzz-不存在');
    await tester.pump();

    expect(
      _songRow('Alpha'),
      findsNothing,
      reason: '没有命中时不应该把整个歌单当成搜索结果',
    );
    expect(_songRow('Beta'), findsNothing);
  });

  testWidgets('清空关键词后恢复完整歌单', (tester) async {
    await _mountPlaylistA(tester);

    await tester.enterText(find.byType(TextField), 'Alpha');
    await tester.pump();
    expect(_songRow('Beta'), findsNothing);

    await tester.enterText(find.byType(TextField), '');
    await tester.pump();

    expect(_songRow('Alpha'), findsOneWidget);
    expect(_songRow('Beta'), findsOneWidget, reason: '退出搜索应该回到完整歌单');
  });

  testWidgets('搜索状态下删除歌曲，那一行随之消失', (tester) async {
    final Management management = await _mountPlaylistA(tester);

    await tester.enterText(find.byType(TextField), 'Alpha');
    await tester.pump();
    expect(_songRow('Alpha'), findsOneWidget);

    await management.deleteMusicFromPlaylist(_playlistA.listId, _alpha.id);
    await tester.pump();

    expect(
      _songRow('Alpha'),
      findsNothing,
      reason: '搜索结果列表和 displayMusics 是两个实例，删歌时要一起移除',
    );
  });
}
