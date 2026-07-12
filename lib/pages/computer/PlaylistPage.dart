import 'package:flutter/material.dart';
import 'package:bootstrap_icons/bootstrap_icons.dart';
import 'package:chocolate_music/theme/app_colors.dart';
import 'package:chocolate_music/Management.dart';
import 'package:chocolate_music/components/MusicComponents.dart';

import 'package:chocolate_music/Type.dart';

class PlaylistPage extends StatefulWidget {
  final Management management = Management();

  @override
  State<PlaylistPage> createState() => _PlaylistPageState();
}

class _PlaylistPageState extends State<PlaylistPage> {
  @override
  late String displayListType = widget.management.displayListType;

  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      // child: Container(
      padding: EdgeInsets.only(left: 20, right: 20),
      child: ListView(
        // child: Column(
        // mainAxisAlignment: MainAxisAlignment.center, // 垂直居中
        // crossAxisAlignment: CrossAxisAlignment.start, // 左对齐
        children: [
          SizedBox(height: 10),

          PlaylistDate(),

          SizedBox(height: 10),

          MusicListTag(),

          SizedBox(height: 10),

          MusicList(),
        ],
      ),
      // ),
    );
  }
}

class PlaylistDate extends StatefulWidget {
  final Management management = Management();

  @override
  State<PlaylistDate> createState() => _PlaylistDateState();
}

class _PlaylistDateState extends State<PlaylistDate> {
  @override
  late String displayListType = widget.management.displayListType;

  Widget build(BuildContext context) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(34), // 根据需要设置圆角大小
          child: Image.network(
            // widget.cover,
            (widget.management.displayList as Playlist).cover,
            width: 170,
            height: 170,
            fit: BoxFit.cover,
            // 加载失败时，errorBuilder 会被调用
            errorBuilder: (context, error, stackTrace) {
              // 返回你的本地图片
              return Image.asset(
                'assets/images/app_photo.png',
                width: 170,
                height: 170,
                fit: BoxFit.cover,
              );
            },
          ),
        ),

        SizedBox(width: 30),

        SizedBox(
          height: 170, // 跟左边图片同高，或者写成你需要的高度
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, // 左对齐
            children: [
              // SizedBox(height: 20),
              Text(
                displayListType == 'Playlist'
                    ? (widget.management.displayList as Playlist).name
                    : displayListType == 'Singer'
                    ? (widget.management.displayList as Singer).singer
                    : displayListType == 'Album'
                    ? (widget.management.displayList as Album).album
                    : '',
                style: TextStyle(
                  color: AppColors.playlistNameColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 30,
                ),
              ),

              SizedBox(height: 5),

              Row(
                children: [
                  Icon(
                    BootstrapIcons.music_note,
                    color: AppColors.musicQuantityColor,
                    size: 18,
                  ),
                  Text(
                    '100',
                    style: TextStyle(
                      color: AppColors.musicQuantityColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),

              Expanded(child: SizedBox()),

              ElevatedButton.icon(
                onPressed: () {
                  /* 点击逻辑 */
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

                  // 方式B：如果你想固定死宽高（不被内容撑大），用 fixedSize
                  // fixedSize: const Size(200, 48),

                  // 方式C：通过内边距控制大小（适合只想增加点击区域的情况）
                  // padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),

                  // 可选：调整圆角
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
              ),

              // SizedBox(height: 20),
            ],
          ),
        ),
      ],
    );
  }
}

class MusicListTag extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 15),

        Text('#',
          textAlign: TextAlign.left,
          style: TextStyle(
            fontSize: 16,
            color: AppColors.musicIndexColor,
            fontWeight: FontWeight.bold,
          ),),

        SizedBox(width: 85),

        Expanded(
          child: Text('歌曲',
            textAlign: TextAlign.left,
            style: TextStyle(
              fontSize: 16,
              color: AppColors.musicIndexColor,
              fontWeight: FontWeight.bold,
            ),),
        ),

        // SizedBox(width: 80),

        Container(
          width: 200,
          child: Text('专辑',
            textAlign: TextAlign.left,
            style: TextStyle(
              fontSize: 16,
              color: AppColors.musicIndexColor,
              fontWeight: FontWeight.bold,
            ),),
        ),

        SizedBox(width: 15),

        Container(
          width: 50,
          child:Text('时长',
            textAlign: TextAlign.left,
            style: TextStyle(
              fontSize: 16,
              color: AppColors.musicIndexColor,
              fontWeight: FontWeight.bold,
            ),),
        ),

        SizedBox(width: 15),
      ],
    );
  }
}

class MusicList extends StatefulWidget {
  final Management management = Management();

  @override
  State<MusicList> createState() => _MusicListState();
}

class _MusicListState extends State<MusicList> {
  @override
  Widget build(BuildContext context) {
    return Container(
      child: Column(
        children: [
          // 添加你的音乐列表项
          for (int i = 0; i < 10; i++)
            Column(
              children: [
                ComputerMusicWidget(
                  music: Music(
                    id: i.toString(),
                    name: '枫',
                    singer: '周杰伦',
                    singerId: '周杰伦',
                    album: '十一月的肖邦',
                    albumId: '周杰伦',
                    time: 275000,
                    cover:
                        'https://img2.kuwo.cn/star/albumcover/120/s4s11/89/774616642.jpg',
                  ),
                  displayList: widget.management.displayList,
                  displayListType: widget.management.displayListType,
                  num: i,
                ),
                if (i < 9) SizedBox(height: 10),
              ],
            ),
        ],
      ),
    );
  }
}
