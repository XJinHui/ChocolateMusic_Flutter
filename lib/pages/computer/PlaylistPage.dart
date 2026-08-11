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
  late String displayListType = widget.management.displayListType;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      // child: Container(
      padding: EdgeInsets.only(top: 10, left: 20, right: 20),
      child: Scaffold(
        backgroundColor: AppColors.background, // 覆盖主题默认值
        body: CustomScrollView(
          // child: Column(
          // mainAxisAlignment: MainAxisAlignment.center, // 垂直居中
          // crossAxisAlignment: CrossAxisAlignment.start, // 左对齐
          slivers: [
            // SizedBox(height: 10),
            SliverAppBar(
              pinned: true,
              // 折叠后固定在顶部
              // floating: false,            // 下拉时立即展开
              // snap: true,                // 松手后自动吸附到展开/折叠状态
              expandedHeight: 170.0,
              // 展开时的高度
              collapsedHeight: 60.0,
              // 折叠时的高度
              backgroundColor: AppColors.background,
              // flexibleSpace: FlexibleSpaceBar(
              //   // 把 PlaylistDate 放在这里
              //   background: PlaylistDate(),
              // ),
              surfaceTintColor:
                  Colors.transparent, // <--- 添加这一行，禁用 Material 3 表面染色
              flexibleSpace: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  // 当前 AppBar 的实际高度
                  double currentHeight = constraints.maxHeight;

                  // 计算展开比例 (80.0 到 170.0 之间转化为 0.0 到 1.0)
                  // double expandRatio = ((currentHeight - 80.0) / (170.0 - 80.0)).clamp(0.0, 1.0);

                  // 将比例传给组件
                  return PlaylistDate(currentHeight: currentHeight);
                  // return Container(
                  //   color: AppColors.background,
                  //   child: PlaylistDate(currentHeight: currentHeight),
                  // );
                },
              ),
            ),

            // PlaylistDate(),
            SliverToBoxAdapter(child: SizedBox(height: 10)),

            // SizedBox(height: 10),
            SliverPersistentHeader(
              pinned: true,
              delegate: _MusicListTagDelegate(),
            ),

            // MusicListTag(),
            SliverToBoxAdapter(child: SizedBox(height: 10)),
            // SizedBox(height: 10),

            // SliverList(),
            SliverToBoxAdapter(
              child:
                  MusicList(), // 或者用 SliverList 构建，但 MusicList 返回的是 Column，需要用 SliverToBoxAdapter
            ),
            // MusicList(),
          ],
        ),
      ),
    );
  }
}

class PlaylistDate extends StatefulWidget {
  final Management management = Management();
  final double currentHeight;

  PlaylistDate({Key? key, required this.currentHeight}) : super(key: key);

  @override
  State<PlaylistDate> createState() => _PlaylistDateState();
}

class _PlaylistDateState extends State<PlaylistDate> {
  late String displayListType = widget.management.displayListType;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(widget.currentHeight / 5),
          // 根据需要设置圆角大小
          child: Image.network(
            // widget.cover,
            (widget.management.displayList as Playlist).cover,
            width: widget.currentHeight,
            height: widget.currentHeight,
            fit: BoxFit.cover,
            // 加载失败时，errorBuilder 会被调用
            errorBuilder: (context, error, stackTrace) {
              // 返回你的本地图片
              return Image.asset(
                'assets/images/app_photo.png',
                width: widget.currentHeight,
                height: widget.currentHeight,
                fit: BoxFit.cover,
              );
            },
          ),
        ),

        SizedBox(
          width:
              15 +
              15 *
                  ((widget.currentHeight - 60.0) / (170.0 - 60.0)).clamp(
                    0.0,
                    1.0,
                  ),
        ),

        if (widget.currentHeight == 170)
          SizedBox(
            height: 170, // 跟左边图片同高
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
                      widget.management.displayMusics.length.toString(),
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

                    // 可选：调整圆角
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                ),

                // SizedBox(height: 20),
              ],
            ),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start, // 左对齐
            mainAxisAlignment: MainAxisAlignment.start, // 垂直顶部对齐
            children: [
              SizedBox(
                height:
                    10 -
                    10 *
                        ((widget.currentHeight - 60.0) / (170.0 - 60.0)).clamp(
                          0.0,
                          1.0,
                        ),
              ),
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
                  fontSize:
                      20 +
                      10 *
                          ((widget.currentHeight - 60.0) / (170.0 - 60.0))
                              .clamp(0.0, 1.0),
                ),
              ),
            ],
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

        Text(
          '#',
          textAlign: TextAlign.left,
          style: TextStyle(
            fontSize: 16,
            color: AppColors.musicIndexColor,
            fontWeight: FontWeight.bold,
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

class _MusicListTagDelegate extends SliverPersistentHeaderDelegate {
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(
      color: AppColors.background,
      child: SizedBox(height: maxExtent, child: MusicListTag()),
    );
  }

  @override
  double get maxExtent => 48; // 头部完全展开时的高度（根据需要调整）

  @override
  double get minExtent => 48; // 头部收缩到最小时的高度（和 maxExtent 一样就是固定高度）

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return false; // 如果 delegate 不会变化，返回 false
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
          for (int i = 0; i < widget.management.displayMusics.length; i++)
            Column(
              children: [
                ComputerMusicWidget(
                  music: widget.management.displayMusics[i],
                  displayList: widget.management.displayList,
                  displayListType: widget.management.displayListType,
                  num: i + 1,
                ),
                if (i < widget.management.displayMusics.length - 1)
                  SizedBox(height: 10),
              ],
            ),
        ],
      ),
    );
  }
}
