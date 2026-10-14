import 'package:chocolate_music/Management.dart';
import 'package:chocolate_music/Type.dart';
import 'package:chocolate_music/pages/computer/RecommendPage.dart';
import 'package:chocolate_music/pages/computer/SearchPage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Playlist _playlist(String id) =>
    Playlist(name: '歌单$id', listId: id, cover: '', audioCount: 1);

Album _album(String id) =>
    Album(album: '专辑$id', albumId: id, singer: '演唱者', cover: '', audioCount: 1);

Singer _singer(String id) => Singer(
  singer: '歌手$id',
  singerId: id,
  cover: '',
  audioCount: 1,
  albumCount: 1,
);

Music _music(String id) => Music(
  id: id,
  name: '曲目$id',
  singer: '演唱者',
  singerId: 'singer-$id',
  album: '唱片',
  albumId: 'album-$id',
  time: 180000,
  cover: '',
);

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: SizedBox(width: 1200, height: 800, child: child)),
);

/// 取单例并摆好与用例无关的状态。
///
/// 必须在用例内部取：首次访问 Management 会触发 [Management.init]，它在
/// 测试环境下必然抛异常，落在用例之外就会被记到整个测试文件头上。
Management _seed() {
  final Management management = Management();
  management.cloud = management.KuGouCloud;
  management.account = Account(cover: '', nickname: '', type: '酷狗音乐');
  management.recommendList = RecommendList();
  management.searchList = RecommendList();
  management.searchKeyword = '';
  return management;
}

void main() {
  testWidgets('推荐页在没有数据时一个模块都不渲染', (WidgetTester tester) async {
    _seed();

    await tester.pumpWidget(_host(RecommendPage()));
    await tester.pump();

    expect(find.text('为你推荐'), findsNothing, reason: '空模块连标题都不该出现');
    expect(find.text('歌单'), findsNothing);
    expect(find.text('专辑'), findsNothing);
    expect(find.text('歌手'), findsNothing);
    expect(find.text('歌曲'), findsNothing);
  });

  testWidgets('推荐页只渲染有数据的模块', (WidgetTester tester) async {
    final Management management = _seed();
    management.recommendList = RecommendList(music: <Music>[_music('1')]);

    await tester.pumpWidget(_host(RecommendPage()));
    await tester.pump();

    expect(find.text('歌曲'), findsOneWidget);
    expect(find.text('曲目1'), findsOneWidget);
    expect(find.text('歌单'), findsNothing);
    expect(find.text('歌手'), findsNothing);
  });

  testWidgets('推荐页的歌单、歌手模块各自独立判断有无数据', (WidgetTester tester) async {
    final Management management = _seed();
    management.recommendList = RecommendList(
      playlist: <Playlist>[_playlist('1')],
      singer: <Singer>[_singer('1')],
    );

    await tester.pumpWidget(_host(RecommendPage()));
    await tester.pump();

    expect(find.text('歌单'), findsOneWidget);
    expect(find.text('歌手'), findsOneWidget);
    expect(find.text('歌曲'), findsNothing);
    expect(find.text('专辑'), findsNothing);
  });

  testWidgets('搜索页在没有结果时一个模块都不渲染', (WidgetTester tester) async {
    _seed();

    await tester.pumpWidget(_host(SearchPage()));
    await tester.pump();

    expect(find.text('专辑'), findsNothing);
    expect(find.text('歌手'), findsNothing);
    expect(find.text('歌曲'), findsNothing);
  });

  testWidgets('搜索页只渲染有结果的模块', (WidgetTester tester) async {
    final Management management = _seed();
    management.searchList = RecommendList(album: <Album>[_album('1')]);

    await tester.pumpWidget(_host(SearchPage()));
    await tester.pump();

    expect(find.text('专辑'), findsOneWidget);
    expect(find.text('歌手'), findsNothing);
    expect(find.text('歌曲'), findsNothing);
  });

  testWidgets('搜索页有歌曲结果时歌曲标题与列表一起出现', (WidgetTester tester) async {
    final Management management = _seed();
    management.searchList = RecommendList(music: <Music>[_music('1')]);

    await tester.pumpWidget(_host(SearchPage()));
    await tester.pump();

    expect(find.text('歌曲'), findsOneWidget);
    expect(find.text('曲目1'), findsOneWidget);
    expect(find.text('专辑'), findsNothing);
    expect(find.text('歌手'), findsNothing);
  });

  testWidgets('搜索页搜过却没有结果时，在页面正中提示无搜索结果', (WidgetTester tester) async {
    final Management management = _seed();
    management.searchKeyword = '不存在的歌';
    management.searchList = RecommendList();

    await tester.pumpWidget(_host(SearchPage()));
    await tester.pump();

    expect(find.text('无搜索结果'), findsOneWidget);
    expect(
      tester.getCenter(find.text('无搜索结果')),
      tester.getCenter(find.byType(SearchPage)),
      reason: '提示应当落在页面正中，而不是被顶到某一角',
    );
  });

  testWidgets('搜索页还没搜过时，不把空页面说成无搜索结果', (WidgetTester tester) async {
    _seed();

    await tester.pumpWidget(_host(SearchPage()));
    await tester.pump();

    expect(find.text('无搜索结果'), findsNothing);
  });

  testWidgets('搜索页有结果时不出现无搜索结果提示', (WidgetTester tester) async {
    final Management management = _seed();
    management.searchKeyword = '曲目';
    management.searchList = RecommendList(music: <Music>[_music('1')]);

    await tester.pumpWidget(_host(SearchPage()));
    await tester.pump();

    expect(find.text('无搜索结果'), findsNothing);
    expect(find.text('歌曲'), findsOneWidget);
  });
}
