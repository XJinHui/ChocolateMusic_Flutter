import 'package:flutter/material.dart';
import 'package:bootstrap_icons/bootstrap_icons.dart';
import 'package:chocolate_music/components/EdgeFadeMask.dart';
import 'package:chocolate_music/components/MusicComponents.dart';
import 'package:chocolate_music/Type.dart';
import 'package:chocolate_music/theme/app_colors.dart';
import 'package:chocolate_music/Management.dart';

class RecommendPage extends StatefulWidget {
  @override
  State<RecommendPage> createState() => _RecommendPageState();
}

class _RecommendPageState extends State<RecommendPage> {
  late Management management = Management();

  @override
  Widget build(BuildContext context) {
    return Container(
      child: EdgeFadeMask(
        child: ListView(
          children: [
            management.account.type != 'Navidrome'
                ? Center(child: RecommendPlaylist())
                : Center(child: RecommendAlbums()),
            Center(child: RecommendSingers()),
            Center(child: RecommendMusics()),
          ],
        ),
      ),
    );
  }
}

class RecommendPlaylist extends StatefulWidget {
  @override
  State<RecommendPlaylist> createState() => _RecommendPlaylistState();
}

class _RecommendPlaylistState extends State<RecommendPlaylist> {
  late Management management = Management();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        double availableWidth = constraints.maxWidth; // 获取可用的最大宽度
        int num = 5;
        double size = (availableWidth - 100) / 5;
        double edge = 20;
        if (size >= 200) {
          num = 6;
          size = (availableWidth - 115) / 6;
          edge = size >= 200
              ? (availableWidth - 1275) / 2
              : (availableWidth - size * 6 - 75) / 2;
        }

        return Container(
          padding: EdgeInsets.only(
            left: edge,
            right: edge,
            top: 20,
            bottom: 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Text(
              //   '推荐歌单',
              //   style: TextStyle(
              //     fontSize: 24,
              //     color: AppColors.normalText,
              //     fontWeight: FontWeight.bold,
              //   ),
              // ),

              RecommendTitle(title: '歌单', icon: BootstrapIcons.music_note_list),

              SizedBox(height: 15),

              Wrap(
                spacing: 15,
                runSpacing: 15,
                children: [
                  for (int i = 0; i < num * 2; i++)
                    if (management.recommendList.playlist.length > i)
                      // for (var item in management.recommendList.playlist)
                      PlaylistWidget(
                        playlist: management.recommendList.playlist[i],
                        size: size >= 200 ? 200 : size, // 每行显示5个，减去间距
                      ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class RecommendAlbums extends StatefulWidget {
  @override
  State<RecommendAlbums> createState() => _RecommendAlbumsState();
}

class _RecommendAlbumsState extends State<RecommendAlbums> {
  late Management management = Management();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        double availableWidth = constraints.maxWidth; // 获取可用的最大宽度
        int num = 5;
        double size = (availableWidth - 100) / 5;
        double edge = 20;
        if (size >= 200) {
          num = 6;
          size = (availableWidth - 115) / 6;
          edge = size >= 200
              ? (availableWidth - 1275) / 2
              : (availableWidth - size * 6 - 75) / 2;
        }

        return Container(
          padding: EdgeInsets.only(
            left: edge,
            right: edge,
            top: 20,
            bottom: 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Text(
              //   '推荐专辑',
              //   style: TextStyle(
              //     fontSize: 24,
              //     color: AppColors.normalText,
              //     fontWeight: FontWeight.bold,
              //   ),
              // ),

              RecommendTitle(title: '专辑', icon: BootstrapIcons.disc),

              SizedBox(height: 15),

              Wrap(
                spacing: 15,
                runSpacing: 15,
                children: [
                  for (int i = 0; i < num * 2; i++)
                    if (management.recommendList.album.length > i)
                      // for (var item in management.recommendList.album)
                      AlbumWidget(
                        album: management.recommendList.album[i],
                        size: size >= 200 ? 200 : size, // 每行显示5个，减去间距
                      ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class RecommendSingers extends StatefulWidget {
  @override
  State<RecommendSingers> createState() => _RecommendSingersState();
}

class _RecommendSingersState extends State<RecommendSingers> {
  late Management management = Management();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        double availableWidth = constraints.maxWidth; // 获取可用的最大宽度
        int num = 5;
        double size = (availableWidth - 100) / 5;
        double edge = 20;
        if (size >= 200) {
          num = 6;
          size = (availableWidth - 115) / 6;
          edge = size >= 200
              ? (availableWidth - 1275) / 2
              : (availableWidth - size * 6 - 75) / 2;
        }

        return Container(
          padding: EdgeInsets.only(
            left: edge,
            right: edge,
            top: 20,
            bottom: 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Text(
              //   '推荐歌手',
              //   style: TextStyle(
              //     fontSize: 24,
              //     color: AppColors.normalText,
              //     fontWeight: FontWeight.bold,
              //   ),
              // ),

              RecommendTitle(title: '歌手', icon: BootstrapIcons.person),

              SizedBox(height: 15),

              Wrap(
                spacing: 15,
                runSpacing: 15,
                children: [
                  // for (int i = 0; i < num * 2; i++)
                  //   PlaylistWidget(
                  //     playlist: Playlist(
                  //       name: '周杰伦',
                  //       listId: '1',
                  //       cover:
                  //       'https://img2.kuwo.cn/star/albumcover/120/s4s11/89/774616642.jpg',
                  //       audioCount: 5,
                  //     ),
                  //     size: size >= 200 ? 200 : size, // 每行显示5个，减去间距
                  //   ),
                  for (int i = 0; i < num * 2; i++)
                    if (management.recommendList.singer.length > i)
                      // for (var item in management.recommendList.singer)
                      SingerWidget(
                        singer: management.recommendList.singer[i],
                        size: size >= 200 ? 200 : size, // 每行显示5个，减去间距
                      ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class RecommendMusics extends StatefulWidget {
  @override
  State<RecommendMusics> createState() => _RecommendMusicsState();
}

class _RecommendMusicsState extends State<RecommendMusics> {
  late Management management = Management();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        double availableWidth = constraints.maxWidth; // 获取可用的最大宽度

        double width = (availableWidth - 80) / 3;
        if (availableWidth > 1275) {
          width = 1235 / 3;
        }

        double size = (availableWidth - 100) / 5;
        double edge = 20;
        if (size >= 200) {
          edge = size >= 200
              ? (availableWidth - 1275) / 2
              : (availableWidth - size * 6 - 75) / 2;
        }

        return Container(
          padding: EdgeInsets.only(
            left: edge,
            right: edge,
            top: 20,
            bottom: 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Text(
              //   '推荐歌曲',
              //   style: TextStyle(
              //     fontSize: 24,
              //     color: AppColors.normalText,
              //     fontWeight: FontWeight.bold,
              //   ),
              // ),

              RecommendTitle(title: '歌曲', icon: BootstrapIcons.music_note_beamed),

              SizedBox(height: 15),

              Wrap(
                spacing: 20,
                runSpacing: 15,
                children: [
                  for (var item in management.recommendList.music)
                    RecommendMusicWidget(music: item, width: width),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class RecommendTitle extends StatelessWidget {
  final String title;
  final IconData icon;

  const RecommendTitle({
    super.key,
    required this.title,
    required this.icon,
  });

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
        child: Icon(
          this.icon,
          size: 20,
          color: AppColors.buttonIcon,
        ),
      ),

        SizedBox(width: 10,),

        Text(
          '为你推荐',
          style: TextStyle(
            fontSize: 24,
            color: AppColors.normalText,
            fontWeight: FontWeight.bold,
          ),
        ),

        Container(
          width: 1, // 竖线粗细
          height: 25, // 竖线高度，根据字号视觉调整
          color: AppColors.normalText, // 竖线颜色
          margin: const EdgeInsets.symmetric(horizontal: 8), // 左右间距
        ),

        Text(
          this.title,
          style: TextStyle(
            fontSize: 20,
            color: AppColors.normalText,
          ),
        ),
      ],
    );
  }
}
