import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:bootstrap_icons/bootstrap_icons.dart';

import 'package:chocolate_music/theme/app_colors.dart';
import 'package:chocolate_music/Management.dart';
import 'package:chocolate_music/Type.dart';
import 'package:chocolate_music/components/EdgeFadeMask.dart';
import 'package:chocolate_music/components/MusicComponents.dart';

class LocalDownloadPage extends StatefulWidget {
  @override
  State<LocalDownloadPage> createState() => _LocalDownloadPageState();
}

class _LocalDownloadPageState extends State<LocalDownloadPage> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(top: 10, left: 20, right: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                "本地下载",
                style: TextStyle(
                  color: AppColors.playlistNameColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 25,
                ),
              ),

              SizedBox(width: 5,),

              Row(
                children: [
                  Icon(
                    BootstrapIcons.music_note,
                    color: AppColors.musicQuantityColor,
                    size: 18,
                  ),

                  Text(
                    Management().musicManagement.localMusics.length.toString(),
                    style: TextStyle(
                      color: AppColors.musicQuantityColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),

            ],
          ),

          SizedBox(height: 10,),

          ElevatedButton.icon(
            onPressed: () {
              /* 点击逻辑 */
              if (Management().musicManagement.localMusics.length != 0) {
                Management().displayList = Playlist(name: 'Download', listId: 'Download', cover: '', audioCount: 0);
                Management().displayMusics = Management().musicManagement.localMusics;
                Management().playMusic(Management().musicManagement.localMusics[0]);
              }
            },
            icon: const Icon(size: 20, BootstrapIcons.play_fill),
            label: const Text(
              '播放',
              style: TextStyle(
                fontSize: 18, // 自定义字体大小
                fontWeight: FontWeight.w500, // 顺便可以调字重
              ),
            ),
            style: ElevatedButton.styleFrom(
              // 🎨 1. 设置背景颜色
              backgroundColor: AppColors.playAllButtonColor,
              // 如果背景色较深，建议同时设置文字/图标颜色（前景色）
              foregroundColor: Colors.white,

              // 📐 2. 设置按钮大小（三种常用方式）
              // 方式A：设置最小尺寸（宽 >= 160，高 >= 50）
              minimumSize: const Size(55, 45),

              // 可选：调整圆角
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
          ),

          SizedBox(height: 10),

          MusicListTag(),

          SizedBox(height: 10),

          Expanded(child: LocalMusicListWidget()),
        ],
      ),
    );
  }
}

class MusicListTag extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 15),

        SizedBox(
          width: 20,
          child: Align(
            alignment: Alignment.center,
            child: Text(
              '#',
              textAlign: TextAlign.left,
              style: TextStyle(
                fontSize: 16,
                color: AppColors.musicIndexColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),

        SizedBox(width: 85),

        Expanded(
          child: Text(
            '歌曲',
            textAlign: TextAlign.left,
            style: TextStyle(
              fontSize: 16,
              color: AppColors.musicIndexColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        // SizedBox(width: 80),
        Container(
          width: 200,
          child: Text(
            '专辑',
            textAlign: TextAlign.left,
            style: TextStyle(
              fontSize: 16,
              color: AppColors.musicIndexColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        SizedBox(width: 15),

        Container(
          width: 50,
          child: Text(
            '时长',
            textAlign: TextAlign.left,
            style: TextStyle(
              fontSize: 16,
              color: AppColors.musicIndexColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        SizedBox(width: 15),
      ],
    );
  }
}

class LocalMusicListWidget extends StatefulWidget {
  @override
  State<LocalMusicListWidget> createState() => _LocalMusicListWidgetState();
}

class _LocalMusicListWidgetState extends State<LocalMusicListWidget> {
  @override
  Widget build(BuildContext context) {
    return Container(
      // padding: EdgeInsets.only(left: 20, right: 10),
      child: EdgeFadeMask(
        child: CustomScrollView(slivers: [LocalMusicListSliver()]),
      ),
    );
  }
}

class LocalMusicListSliver extends StatelessWidget {
  static const double rowExtent = 90;

  @override
  Widget build(BuildContext context) {
    final List<Music> musics = Management().musicManagement.localMusics;

    return SliverFixedExtentList(
      itemExtent: rowExtent,
      delegate: SliverChildBuilderDelegate(
            (BuildContext context, int index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            // child: PlayMusicWidget(music: musics[index], num: index + 1),
            child: ComputerMusicWidget(
              music: musics[index],
              displayList: Playlist(name: 'Download', listId: 'Download', cover: '', audioCount: 0),
              displayListType: 'Playlist',
              num: index + 1,
              displayMusics: musics,
              type: 2,
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