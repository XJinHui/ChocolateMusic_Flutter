import 'package:bootstrap_icons/bootstrap_icons.dart';
import 'package:flutter/material.dart';
import 'package:chocolate_music/Type.dart';
import 'package:chocolate_music/theme/app_colors.dart';
import 'package:chocolate_music/components/ComputerNavBar.dart';

class PlaylistWidget extends StatefulWidget {
  final Playlist playlist;
  final double size;

  PlaylistWidget({Key? key, required this.playlist, required this.size})
    : super(key: key);

  @override
  State<PlaylistWidget> createState() => _PlaylistWidgetState();
}

class _PlaylistWidgetState extends State<PlaylistWidget> {
  @override
  Widget build(BuildContext context) {
    return Container(
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(widget.size / 5), // 根据需要设置圆角大小
            child: Image.network(
              // widget.cover,
              widget.playlist.cover,
              width: widget.size,
              height: widget.size,
              fit: BoxFit.cover,
              // 加载失败时，errorBuilder 会被调用
              errorBuilder: (context, error, stackTrace) {
                // 返回你的本地图片
                return Image.asset(
                  'assets/images/app_photo.png',
                  width: widget.size,
                  height: widget.size,
                  fit: BoxFit.cover,
                );
              },
            ),
          ),

          SizedBox(height: 5), // 图片和文本之间的间距

          Text(
            widget.playlist.name,
            style: TextStyle(fontSize: 18, color: AppColors.normalText),
          ),
        ],
      ),
    );
  }
}

class AlbumWidget extends StatefulWidget {
  final Album album;
  final double size;

  AlbumWidget({Key? key, required this.album, required this.size})
    : super(key: key);

  @override
  State<AlbumWidget> createState() => _AlbumWidgetState();
}

class _AlbumWidgetState extends State<AlbumWidget> {
  @override
  Widget build(BuildContext context) {
    return Container(
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(widget.size / 5), // 根据需要设置圆角大小
            child: Image.network(
              // widget.cover,
              widget.album.cover,
              width: widget.size,
              height: widget.size,
              fit: BoxFit.cover,
              // 加载失败时，errorBuilder 会被调用
              errorBuilder: (context, error, stackTrace) {
                // 返回你的本地图片
                return Image.asset(
                  'assets/images/app_photo.png',
                  width: widget.size,
                  height: widget.size,
                  fit: BoxFit.cover,
                );
              },
            ),
          ),

          SizedBox(height: 5), // 图片和文本之间的间距

          Text(
            widget.album.album,
            style: TextStyle(fontSize: 18, color: AppColors.normalText),
          ),
        ],
      ),
    );
  }
}

class SingerWidget extends StatefulWidget {
  final Singer singer;
  final double size;

  SingerWidget({Key? key, required this.singer, required this.size})
    : super(key: key);

  @override
  State<SingerWidget> createState() => _SingerWidgetState();
}

class _SingerWidgetState extends State<SingerWidget> {
  @override
  Widget build(BuildContext context) {
    return Container(
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(widget.size / 5), // 根据需要设置圆角大小
            child: Image.network(
              // widget.cover,
              widget.singer.cover,
              width: widget.size,
              height: widget.size,
              fit: BoxFit.cover,
              // 加载失败时，errorBuilder 会被调用
              errorBuilder: (context, error, stackTrace) {
                // 返回你的本地图片
                return Image.asset(
                  'assets/images/app_photo.png',
                  width: widget.size,
                  height: widget.size,
                  fit: BoxFit.cover,
                );
              },
            ),
          ),

          SizedBox(height: 5), // 图片和文本之间的间距

          Text(
            widget.singer.singer,
            style: TextStyle(fontSize: 18, color: AppColors.normalText),
          ),
        ],
      ),
    );
  }
}

class RecommendMusicWidget extends StatefulWidget {
  final Music music;
  final double width;

  RecommendMusicWidget({Key? key, required this.music, required this.width})
    : super(key: key);

  @override
  State<RecommendMusicWidget> createState() => _RecommendMusicWidgetState();
}

class _RecommendMusicWidgetState extends State<RecommendMusicWidget> {
  @override
  bool isHovering = false;

  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        setState(() {
          isHovering = true; // 鼠标进入，更新状态
        });
      },
      onExit: (_) {
        setState(() {
          isHovering = false; // 鼠标离开，恢复状态
        });
      },
      child: Container(
        padding: EdgeInsets.only(bottom: 10, top: 10, left: 15, right: 20),
        width: widget.width,
        height: 80,
        decoration: BoxDecoration(
          color: isHovering ? AppColors.panel : AppColors.transparent,
          // color: AppColors.panel,
          borderRadius: BorderRadius.circular(16), // 圆角
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12), // 根据需要设置圆角大小
              child: Image.network(
                // widget.cover,
                widget.music.cover,
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                // 加载失败时，errorBuilder 会被调用
                errorBuilder: (context, error, stackTrace) {
                  // 返回你的本地图片
                  return Image.asset(
                    'assets/images/app_photo.png',
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                  );
                },
              ),
            ),

            SizedBox(width: 10),

            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center, // 垂直居中
                crossAxisAlignment: CrossAxisAlignment.start, // 水平居中
                children: [
                  Text(
                    widget.music.name,
                    textAlign: TextAlign.left,
                    style: TextStyle(
                      fontSize: 18,
                      color: AppColors.musicNameColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  Text(
                    widget.music.singer,
                    textAlign: TextAlign.left,
                    style: TextStyle(
                      fontSize: 17,
                      color: AppColors.musicSingerColor,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(width: 10),

            if (isHovering)
              GestureDetector(
                onTap: () {
                  // 处理喜欢按钮点击事件
                },
                child: Icon(
                  BootstrapIcons.heart,
                  color: AppColors.buttonIcon,
                  size: 20,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class ComputerMusicWidget extends StatefulWidget {
  final Object displayList;
  final String displayListType;
  final Music music;
  final int num;

  ComputerMusicWidget({
    Key? key,
    required this.music,
    required this.displayList,
    required this.displayListType,
    required this.num,
  }) : super(key: key);

  @override
  State<ComputerMusicWidget> createState() => _ComputerMusicWidgetState();
}

class _ComputerMusicWidgetState extends State<ComputerMusicWidget> {
  String formatTime(double seconds) {
    final int totalSeconds = seconds.round();
    final int minutes = totalSeconds ~/ 60;
    final int secs = totalSeconds % 60;
    final String m = minutes.toString().padLeft(2, '0');
    final String s = secs.toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  bool isHovering = false;

  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        setState(() {
          isHovering = true; // 鼠标进入，更新状态
        });
      },
      onExit: (_) {
        setState(() {
          isHovering = false; // 鼠标离开，恢复状态
        });
      },

      child: Container(
        height: 80,
        padding: EdgeInsets.only(bottom: 10, top: 10, left: 15, right: 15),
        decoration: BoxDecoration(
          color: isHovering ? AppColors.panel : AppColors.transparent,
          // color: AppColors.panel,
          borderRadius: BorderRadius.circular(16), // 圆角
        ),

        child: Row(
          children: [
            Text(
              widget.num.toString(),
              textAlign: TextAlign.left,
              style: TextStyle(fontSize: 16, color: AppColors.musicIndexColor),
            ),

            SizedBox(width: 15),

            ClipRRect(
              borderRadius: BorderRadius.circular(12), // 根据需要设置圆角大小
              child: Image.network(
                // widget.cover,
                widget.music.cover,
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                // 加载失败时，errorBuilder 会被调用
                errorBuilder: (context, error, stackTrace) {
                  // 返回你的本地图片
                  return Image.asset(
                    'assets/images/app_photo.png',
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                  );
                },
              ),
            ),

            SizedBox(width: 10),

            Expanded(
              child: Container(
                width: 80,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center, // 垂直居中
                  crossAxisAlignment: CrossAxisAlignment.start, // 左对齐
                  children: [
                    Text(
                      widget.music.name,
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        fontSize: 18,
                        color: AppColors.musicNameColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    Text(
                      widget.music.singer,
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.musicSingerColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(width: 10),

            GestureDetector(
              onTap: () {
                // 处理喜欢按钮点击事件
              },
              child: Icon(
                BootstrapIcons.heart_fill,
                color: AppColors.likeIconColor,
                size: 20,
              ),
            ),

            SizedBox(width: 50),

            Container(
              width: 200,
              child: Text(
                widget.music.album,
                textAlign: TextAlign.left,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.albumNameColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            SizedBox(width: 15),

            Container(
              width: 50,
              child: Text(
                formatTime(widget.music.time / 1000),
                textAlign: TextAlign.left,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.musicTimeColor,
                  // fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
