import 'package:flutter/material.dart';
import 'package:bootstrap_icons/bootstrap_icons.dart';
import 'package:chocolate_music/theme/app_colors.dart';
import 'package:chocolate_music/Type.dart';
import 'package:chocolate_music/Management.dart';
import 'package:chocolate_music/components/EdgeFadeMask.dart';
import 'package:chocolate_music/components/MusicComponents.dart';
import 'package:chocolate_music/components/RemoteImage.dart';

class SearchPage extends StatefulWidget {
  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  @override
  Widget build(BuildContext context) {
    return Container(
      // padding: EdgeInsets.only(left: 20, right: 20),
      child: EdgeFadeMask(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: SizedBox(height: 20)),

            SliverToBoxAdapter(child: SearchAlbumList()),

            SliverToBoxAdapter(child: SizedBox(height: 10)),

            SliverToBoxAdapter(child: SearchSingerList()),

            SliverToBoxAdapter(child: SizedBox(height: 10)),

            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: SearchTitle(
                  title: '歌曲',
                  icon: BootstrapIcons.music_note_beamed,
                ),
              ),
            ),
            SliverToBoxAdapter(child: SizedBox(height: 10)),

            // 歌曲列表：sliver 直接放在 slivers 里，左右留白交给 SliverPadding
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              sliver: SearchMusicListSliver(),
            ),
          ],
        ),
      ),
    );
  }
}

class SearchAlbumList extends StatefulWidget {
  @override
  State<SearchAlbumList> createState() => _SearchAlbumListState();
}

class _SearchAlbumListState extends State<SearchAlbumList> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(left: 20, right: 20),
      child: Column(
        children: [
          SearchTitle(title: '专辑', icon: BootstrapIcons.disc),

          SizedBox(height: 10),

          Container(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: Management().searchList.album.length,
              itemBuilder: (BuildContext context, int index) {
                return Padding(
                  padding: EdgeInsets.only(right: 10), // 水平方向用 right
                  child: AlbumWidget(
                    album: Management().searchList.album[index],
                    size: 150,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class SearchSingerList extends StatefulWidget {
  @override
  State<SearchSingerList> createState() => _SearchSingerListState();
}

class _SearchSingerListState extends State<SearchSingerList> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(left: 20, right: 20),
      child: Column(
        children: [
          SearchTitle(title: '歌手', icon: BootstrapIcons.person),

          SizedBox(height: 10),

          Container(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: Management().searchList.singer.length,
              itemBuilder: (BuildContext context, int index) {
                return Padding(
                  padding: EdgeInsets.only(right: 10), // 水平方向用 right
                  child: SingerWidget(
                    singer: Management().searchList.singer[index],
                    size: 150,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// class SearchMusicList extends StatefulWidget {
//   @override
//   State<SearchMusicList> createState() => _SearchMusicListState();
// }
//
// class _SearchMusicListState extends State<SearchMusicList> {
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: EdgeInsets.only(left: 20, right: 20),
//       child: Column(
//         children: [
//           SearchTitle(title: '歌曲', icon: BootstrapIcons.music_note_beamed),
//
//           SizedBox(height: 10),
//
//           MusicListSliver(),
//         ],
//       ),
//     );
//   }
// }

class SearchMusicListSliver extends StatelessWidget {
  static const double rowExtent = 90;

  @override
  Widget build(BuildContext context) {
    final List<Music> musics = Management().searchList.music;

    return SliverFixedExtentList(
      itemExtent: rowExtent,
      delegate: SliverChildBuilderDelegate(
            (BuildContext context, int index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: ComputerMusicWidget(
              music: musics[index],
              displayList: Playlist(
                name: '',
                listId: '',
                cover: '',
                audioCount: 0,
              ),
              displayListType: '',
              num: index + 1,
              displayMusics: [],
              type: 1,
            ),
          );
        },
        childCount: musics.length,
        addAutomaticKeepAlives: false,
        addSemanticIndexes: false,
      ),
    );
  }
}

class SearchTitle extends StatelessWidget {
  final String title;
  final IconData icon;

  const SearchTitle({super.key, required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: AppColors.panel,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(this.icon, size: 20, color: AppColors.buttonIcon),
        ),

        SizedBox(width: 10),

        Text(
          this.title,
          style: TextStyle(
            fontSize: 20,
            color: AppColors.normalText,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
