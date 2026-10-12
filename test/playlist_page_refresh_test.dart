import 'package:chocolate_music/Management.dart';
import 'package:chocolate_music/Type.dart';
import 'package:chocolate_music/pages/computer/PlaylistPage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('refreshes PlaylistPage when displayMusics changes', (
    WidgetTester tester,
  ) async {
    final Management management = Management();
    management.cloud = management.KuGouCloud;
    management.displayList = Playlist(
      name: 'Test playlist',
      listId: 'playlist-1',
      cover: '',
      audioCount: 1,
    );
    management.displayListType = 'Unknown';
    management.displayMusics = <Music>[];
    management.displayAlbums = <Album>[];

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: PlaylistPage())));
    await tester.pump();

    management.displayMusics = <Music>[
      Music(
        id: 'music-1',
        name: 'New song',
        singer: 'Singer',
        singerId: 'singer-1',
        album: 'Album',
        albumId: 'album-1',
        time: 180000,
        cover: '',
      ),
    ];
    await tester.pump();

    expect(find.text('New song'), findsOneWidget);
  });
}
