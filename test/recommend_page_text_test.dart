import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chocolate_music/Type.dart';
import 'package:chocolate_music/components/MusicComponents.dart';

void main() {
  testWidgets('recommend cards ellipsize long text', (
    WidgetTester tester,
  ) async {
    const String longText = '这是一个非常长的推荐内容标题用于验证省略显示';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              PlaylistWidget(
                size: 120,
                playlist: Playlist(
                  name: longText,
                  listId: 'playlist-id',
                  cover: '',
                  audioCount: 1,
                ),
              ),
              AlbumWidget(
                size: 120,
                album: Album(
                  album: longText,
                  albumId: 'album-id',
                  singer: 'singer',
                  cover: '',
                  audioCount: 1,
                ),
              ),
              SingerWidget(
                size: 120,
                singer: Singer(
                  singer: longText,
                  singerId: 'singer-id',
                  cover: '',
                  audioCount: 1,
                  albumCount: 1,
                ),
              ),
              RecommendMusicWidget(
                width: 220,
                music: Music(
                  id: 'music-id',
                  name: longText,
                  singer: longText,
                  singerId: 'singer-id',
                  album: 'album',
                  albumId: 'album-id',
                  time: 180000,
                  cover: '',
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final List<Text> longTextWidgets = tester
        .widgetList<Text>(find.text(longText))
        .toList();

    expect(longTextWidgets, hasLength(5));
    for (final Text text in longTextWidgets) {
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.ellipsis);
    }
  });
}
