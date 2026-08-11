import 'package:flutter/material.dart';

import 'package:chocolate_music/components/MusicComponents.dart';
import 'package:chocolate_music/Type.dart';
import 'package:chocolate_music/theme/app_colors.dart';

class RecommendPage extends StatefulWidget {
  @override
  State<RecommendPage> createState() => _RecommendPageState();
}

class _RecommendPageState extends State<RecommendPage> {
  @override
  Widget build(BuildContext context) {
    return Container(
      child: ListView(
        children: [
          Center(child: RecommendPlaylist()),
          // Center(child: RecommendAlbums()),
          Center(child: RecommendSingers()),
          Center(child: RecommendMusics()),
        ],
      ),
    );
  }
}

class RecommendPlaylist extends StatefulWidget {
  @override
  State<RecommendPlaylist> createState() => _RecommendPlaylistState();
}

class _RecommendPlaylistState extends State<RecommendPlaylist> {
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
              Text(
                '推荐歌单',
                style: TextStyle(
                  fontSize: 24,
                  color: AppColors.normalText,
                  fontWeight: FontWeight.bold,
                ),
              ),

              SizedBox(height: 15),

              Wrap(
                spacing: 15,
                runSpacing: 15,
                children: [
                  for (int i = 0; i < num * 2; i++)
                    PlaylistWidget(
                      playlist: Playlist(
                        name: '周杰伦',
                        listId: '1',
                        cover:
                            'https://img2.kuwo.cn/star/albumcover/120/s4s11/89/774616642.jpg',
                        audioCount: 5,
                      ),
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
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '推荐专辑',
                style: TextStyle(
                  fontSize: 24,
                  color: AppColors.normalText,
                  fontWeight: FontWeight.bold,
                ),
              ),

              SizedBox(height: 15),

              Wrap(
                spacing: 15,
                runSpacing: 15,
                children: [
                  for (int i = 0; i < num * 2; i++)
                    AlbumWidget(
                      album: Album(
                        album: '十一月的萧邦',
                        albumId: '1',
                        singer: '周杰伦',
                        cover:
                            'https://img2.kuwo.cn/star/albumcover/120/s4s11/89/774616642.jpg',
                        audioCount: 5,
                      ),
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
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '推荐歌手',
                style: TextStyle(
                  fontSize: 24,
                  color: AppColors.normalText,
                  fontWeight: FontWeight.bold,
                ),
              ),

              SizedBox(height: 15),

              Wrap(
                spacing: 15,
                runSpacing: 15,
                children: [
                  for (int i = 0; i < num * 2; i++)
                    SingerWidget(
                      singer: Singer(
                        singer: '周杰伦',
                        singerId: '1',
                        cover:
                            'https://img2.kuwo.cn/star/albumcover/120/s4s11/89/774616642.jpg',
                        audioCount: 5,
                        albumCount: 5,
                      ),
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
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        double availableWidth = constraints.maxWidth; // 获取可用的最大宽度

        double width = (availableWidth - 80) / 3;
        if (availableWidth > 1275) {
          width = 1235 / 3;
        }
        return Container(
          padding: EdgeInsets.all(20),
          child: Wrap(
            spacing: 20,
            runSpacing: 15,
            children: [
              for (int i = 0; i < 12; i++)
                RecommendMusicWidget(
                  music: Music(
                    id: '1',
                    name: '黑色毛衣',
                    singer: '周杰伦',
                    singerId: '1',
                    album: '十一月的萧邦',
                    albumId: '1',
                    cover:
                        'https://img2.kuwo.cn/star/albumcover/120/s4s11/89/774616642.jpg',
                    time: 253000,
                  ),
                  width: width,
                ),
            ],
          ),
        );
      },
    );
  }
}
