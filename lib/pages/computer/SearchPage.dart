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
    final RecommendList searchList = Management().searchList;
    final bool hasAlbum = searchList.album.isNotEmpty;
    final bool hasSinger = searchList.singer.isNotEmpty;
    final bool hasMusic = searchList.music.isNotEmpty;

    // 搜过了却三个模块都没结果时，给一句明确的提示。只判断「列表为空」是不够的：
    // 搜索页只由搜索提交进入，但登出会清掉关键词和结果，此时页面上的空
    // 不该说成「没有搜到」。
    if (Management().searchKeyword.isNotEmpty &&
        !hasAlbum &&
        !hasSinger &&
        !hasMusic) {
      return Center(
        child: Text(
          '无搜索结果',
          style: TextStyle(fontSize: 16, color: AppColors.emptyHintText),
        ),
      );
    }

    // 各模块按「有没有数据」决定是否出现：空模块连同标题、间距一起收起，
    // 免得搜索页在没有结果时留出一片空白。
    return Container(
      // padding: EdgeInsets.only(left: 20, right: 20),
      child: EdgeFadeMask(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: SizedBox(height: 20)),

            if (hasAlbum) ...[
              SliverToBoxAdapter(child: SearchAlbumList()),

              SliverToBoxAdapter(child: SizedBox(height: 10)),
            ],

            if (hasSinger) ...[
              SliverToBoxAdapter(child: SearchSingerList()),

              SliverToBoxAdapter(child: SizedBox(height: 10)),
            ],

            if (hasMusic) ...[
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
    final List<Album> albums = Management().searchList.album;
    if (albums.isEmpty) {
      return const SizedBox.shrink();
    }

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
              itemCount: albums.length,
              itemBuilder: (BuildContext context, int index) {
                return Padding(
                  padding: EdgeInsets.only(right: 10), // 水平方向用 right
                  child: AlbumWidget(album: albums[index], size: 150),
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
    final List<Singer> singers = Management().searchList.singer;
    if (singers.isEmpty) {
      return const SizedBox.shrink();
    }

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
              itemCount: singers.length,
              itemBuilder: (BuildContext context, int index) {
                return Padding(
                  padding: EdgeInsets.only(right: 10), // 水平方向用 right
                  child: SingerWidget(singer: singers[index], size: 150),
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
