import 'dart:async';
import 'dart:convert';

import 'package:bootstrap_icons/bootstrap_icons.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:chocolate_music/Type.dart';
import 'package:chocolate_music/theme/app_colors.dart';
import 'package:chocolate_music/components/RemoteImage.dart';
import 'package:chocolate_music/Management.dart';
import 'package:chocolate_music/components/AddMusicDialog.dart';
import 'package:chocolate_music/components/DownloadDialog.dart';
// import 'package:chocolate_music/components/ComputerNavBar.dart';

/// 轻提示的文本样式 SnackBar
const TextStyle _kToastTextStyle = TextStyle(
  color: AppColors.accountInk,
  fontSize: 13,
  fontWeight: FontWeight.w700,
  // Text 会把这份样式跟 SnackBar 的 contentTextStyle（M3 的 bodyMedium，
  // letterSpacing 0.25）合并，而 _toastWidth 里的 TextPainter 不会合并。
  // 不显式写 0 的话，实际渲染比量出来的每字宽 0.25px，长文案必定溢出。
  letterSpacing: 0,
);

/// 弹出轻提示：
void showMusicToast(
  BuildContext context, {
  required String message,
  bool success = true,
}) {
  final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) {
    return;
  }
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: success
                    ? const Color(0xFF6FD19C)
                    : AppColors.likeIconColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                success ? Icons.check_rounded : Icons.close_rounded,
                color: AppColors.accountInk,
                size: 15,
              ),
            ),
            const SizedBox(width: 9),
            // 宽度按 _toastWidth 量出来的值算，属于「刚好填满」的临界状态；
            // 这里兜一层，万一以后样式再漂移，退化成省略号而不是溢出报错。
            Flexible(
              child: Text(
                message,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _kToastTextStyle,
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        // 提示文案长度不定，按文本实际宽度算胶囊宽度（最短 156，与账号页一致）
        width: _toastWidth(message),
        backgroundColor: Colors.white,
        elevation: 10,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.accountGlassOutline),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
}

/// 依据文本实际宽度计算胶囊宽度，保证长文案不被截断、短文案保持居中。
double _toastWidth(String message) {
  final TextPainter painter = TextPainter(
    text: TextSpan(text: message, style: _kToastTextStyle),
    maxLines: 1,
    textDirection: TextDirection.ltr,
  )..layout();
  // 22(图标) + 9(间距) + 文本宽度 + 32(SnackBar 内容默认左右内边距)
  final double rawWidth = painter.width + 63;
  return rawWidth.clamp(156.0, 520.0).toDouble();
}

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
          GestureDetector(
            onTap: () {
              Management().selectedPage = 'PlaylistPage';
              Management().displayList = widget.playlist;
              Management().displayListType = 'Playlist';

              Management().displayMusics = [];
              Management().displayAlbums = [];
              Management().getDisplayPlaylist(widget.playlist);

              Management().refresh();
            },
            child: RemoteImage(
              widget.playlist.cover,
              headers: const {
                'User-Agent':
                    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/131.0.0.0 Safari/537.36',
              },
              width: widget.size,
              height: widget.size,
              fit: BoxFit.cover,
              borderRadius: widget.size / 5,
              boxShadow: kImageBoxShadow,
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

          SizedBox(
            width: widget.size,
            child: Text(
              widget.playlist.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, color: AppColors.normalText),
            ),
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
          GestureDetector(
            onTap: () {
              Management().selectedPage = 'PlaylistPage';
              Management().displayList = widget.album;
              Management().displayListType = 'Album';

              Management().displayMusics = [];
              Management().displayAlbums = [];
              Management().getDisplayAlbum(widget.album);

              Management().refresh();
            },
            child: RemoteImage(
              widget.album.cover,
              headers: const {
                'User-Agent':
                    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/131.0.0.0 Safari/537.36',
              },
              width: widget.size,
              height: widget.size,
              fit: BoxFit.cover,
              borderRadius: widget.size / 5,
              boxShadow: kImageBoxShadow,
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

          SizedBox(
            width: widget.size,
            child: Text(
              widget.album.album,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, color: AppColors.normalText),
            ),
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
          GestureDetector(
            onTap: () {
              Management().selectedPage = 'PlaylistPage';
              Management().displayList = widget.singer;
              Management().displayListType = 'Singer';

              Management().displayMusics = [];
              Management().displayAlbums = [];
              Management().getDisplaySinger(widget.singer);

              Management().refresh();
            },
            child: RemoteImage(
              widget.singer.cover,
              headers: const {
                'User-Agent':
                    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/131.0.0.0 Safari/537.36',
              },
              width: widget.size,
              height: widget.size,
              fit: BoxFit.cover,
              borderRadius: widget.size / 5,
              boxShadow: kImageBoxShadow,
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

          SizedBox(
            width: widget.size,
            child: Text(
              widget.singer.singer,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, color: AppColors.normalText),
            ),
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
  late Management management = Management();
  bool isHovering = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onSecondaryTapDown: (details) async {
        // TODO: 菜单目前仅显示，动作逻辑后续根据 show 返回的 action 接入
        Management().selectedMusic = widget.music;
        var action = await MusicSelected.show(
          context,
          details.globalPosition,
          widget.music,
          type: 'Recommend',
        );

        if (action != null) {
          switch (action) {
            case 'play':
              // 处理播放逻辑
              Management().displayList = Playlist(
                name: '',
                listId: '',
                cover: '',
                audioCount: 0,
              );
              Management().displayMusics = List.of(
                Management().recommendList.music,
              );
              Management().playMusic(widget.music);
              print('播放音乐: ${widget.music.name}');
              break;
            case 'playNext':
              // 处理添加到下一首播放逻辑
              Management().addNextMusic(widget.music);
              print('添加到下一首播放: ${widget.music.name}');
              break;
            case 'like':
              // 处理喜欢逻辑
              Management().like(widget.music.id).then((bool success) {
                // 更新收藏状态
                final isCollected =
                    management.cloud.collectionList.contains(widget.music.id) ??
                    false;
                if (success) {
                  showMusicToast(
                    context,
                    message:
                        '歌曲 《${widget.music.name}》 ${isCollected ? '收藏' : '取消收藏'}成功',
                  );
                } else {
                  showMusicToast(
                    context,
                    message:
                        '歌曲 《${widget.music.name}》 ${isCollected ? '取消收藏' : '收藏'}失败',
                    success: false,
                  );
                }
              });
              break;
            case 'viewSinger':
              // 处理查看歌手逻辑
              Management().selectedPage = 'PlaylistPage';
              Singer singer = Singer(
                singer: widget.music.singer,
                singerId: widget.music.singerId,
                cover: widget.music.cover,
                audioCount: 0,
                albumCount: 0,
              );
              Management().displayList = singer;
              Management().displayListType = 'Singer';

              Management().displayMusics = [];
              Management().displayAlbums = [];
              Management().getDisplaySinger(singer);

              Management().refresh();
              print('查看歌手: ${singer.singer}');
              break;
            case 'viewAlbum':
              // 处理查看专辑逻辑
              Management().selectedPage = 'PlaylistPage';
              Album album = Album(
                album: widget.music.album,
                albumId: widget.music.albumId,
                cover: widget.music.cover,
                singer: widget.music.singer,
                audioCount: 0,
              );
              Management().displayList = album;
              Management().displayListType = 'Album';

              Management().displayMusics = [];
              Management().displayAlbums = [];
              Management().getDisplayAlbum(album);

              Management().refresh();
              print('查看专辑: ${album.album}');
              break;
            case 'addToList':
              // 处理添加到列表逻辑
              await showAddMusicDialog(context);
              break;
            case 'download':
              // 处理下载逻辑
              await showDownloadDialog(context);
              break;
          }
        }
      },
      onTap: () {
        this.management.displayList = Playlist(
          name: '',
          listId: '',
          cover: '',
          audioCount: 0,
        );
        this.management.displayMusics = List.of(
          this.management.recommendList.music,
        );
        this.management.playMusic(widget.music);
        print('播放音乐: ${widget.music.name}');
      },
      child: MouseRegion(
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
              RemoteImage(
                widget.music.cover,
                headers: const {
                  'User-Agent':
                      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/131.0.0.0 Safari/537.36',
                },
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                borderRadius: 12,
                boxShadow: kImageBoxShadow,
                // 列表里的封面只有 60×60，按 2 倍设备像素比解码即可，
                // 避免把 500×500 以上的原图整张解码进内存
                cacheWidth: 120,
                cacheHeight: 120,
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

              SizedBox(width: 10),

              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center, // 垂直居中
                  crossAxisAlignment: CrossAxisAlignment.start, // 水平居中
                  children: [
                    Text(
                      widget.music.name,
                      textAlign: TextAlign.left,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 18,
                        color: AppColors.musicNameColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    Text(
                      widget.music.singer,
                      textAlign: TextAlign.left,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
                    Management().like(widget.music.id).then((bool success) {
                      // 更新收藏状态
                      final isCollected =
                          management.cloud.collectionList.contains(
                            widget.music.id,
                          ) ??
                          false;
                      if (success) {
                        showMusicToast(
                          context,
                          message:
                              '歌曲 《${widget.music.name}》 ${isCollected ? '收藏' : '取消收藏'}成功',
                        );
                      } else {
                        showMusicToast(
                          context,
                          message:
                              '歌曲 《${widget.music.name}》 ${isCollected ? '取消收藏' : '收藏'}失败',
                          success: false,
                        );
                      }
                    });
                  },
                  child:
                      management.cloud.collectionList.contains(widget.music.id)
                      ? Icon(
                          BootstrapIcons.heart_fill,
                          color: AppColors.likeIconColor,
                          size: 20,
                        )
                      : Icon(
                          BootstrapIcons.heart,
                          color: AppColors.buttonIcon,
                          size: 20,
                        ),
                ),
            ],
          ),
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
  final List<Music> displayMusics;
  final int type; // type为0时为歌单内的音乐组件，1为搜索列表内的音乐组件, 2为当前播放列表内的音乐组件, 3为歌单内搜索的音乐组件

  ComputerMusicWidget({
    Key? key,
    required this.music,
    required this.displayList,
    required this.displayListType,
    required this.num,
    required this.displayMusics,
    this.type = 0,
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

  late Management management = Management();

  bool isHovering = false;

  _playMusic() {
    if (widget.type != 2) {
      if (widget.type == 1) {
        if (this.management.currentPlayMusicList.length == 0) {
          this.management.displayList = Playlist(
            name: '',
            listId: '',
            cover: '',
            audioCount: 0,
          );
          this.management.displayMusics =
              this.management.playMusicControl.playMusicList;
        } else {
          this.management.addNextMusic(widget.music);
          this.management.playMusic(widget.music);
          print('播放音乐: ${widget.music.name}');
        }
      } else {
        this.management.displayList = widget.displayList;
        this.management.displayMusics = widget.displayMusics;
      }

      this.management.playMusic(widget.music);
    } else {
      this.management.switchMusic(widget.music);
    }
    print('播放音乐: ${widget.music.name}');
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onSecondaryTapDown: (details) async {
        // TODO: 菜单目前仅显示，动作逻辑后续根据 show 返回的 action 接入
        Management().selectedMusic = widget.music;
        var action = await MusicSelected.show(
          context,
          details.globalPosition,
          widget.music,
          type: widget.displayListType,
          playlistId: widget.displayListType == 'Playlist'
              ? (widget.displayList as Playlist).listId
              : '',
        );

        if (action != null) {
          switch (action) {
            case 'play':
              // 处理播放逻辑
              // Management().displayList = widget.displayList;
              // Management().displayMusics = widget.displayMusics;
              // Management().playMusic(widget.music);
              // print('播放音乐: ${widget.music.name}');
              _playMusic();
              break;
            case 'playNext':
              // 处理添加到下一首播放逻辑
              Management().addNextMusic(widget.music);
              print('添加到下一首播放: ${widget.music.name}');
              break;
            case 'delete':
              // 处理删除逻辑
              if (widget.displayListType == 'Playlist') {
                Management().deleteMusicFromPlaylist(
                  (widget.displayList as Playlist).listId,
                  widget.music.id,
                );
              }
              break;
            case 'like':
              // 处理喜欢逻辑
              Management().like(widget.music.id).then((bool success) {
                // 更新收藏状态
                final isCollected =
                    management.cloud.collectionList.contains(widget.music.id) ??
                    false;
                if (success) {
                  showMusicToast(
                    context,
                    message:
                        '歌曲 《${widget.music.name}》 ${isCollected ? '收藏' : '取消收藏'}成功',
                  );
                } else {
                  showMusicToast(
                    context,
                    message:
                        '歌曲 《${widget.music.name}》 ${isCollected ? '取消收藏' : '收藏'}失败',
                    success: false,
                  );
                }
              });
              break;
            case 'viewSinger':
              // 处理查看歌手逻辑
              Management().selectedPage = 'PlaylistPage';
              Singer singer = Singer(
                singer: widget.music.singer,
                singerId: widget.music.singerId,
                cover: widget.music.cover,
                audioCount: 0,
                albumCount: 0,
              );
              Management().displayList = singer;
              Management().displayListType = 'Singer';

              Management().displayMusics = [];
              Management().displayAlbums = [];
              Management().getDisplaySinger(singer);

              Management().refresh();
              print('查看歌手: ${singer.singer}');
              break;
            case 'viewAlbum':
              // 处理查看专辑逻辑
              Management().selectedPage = 'PlaylistPage';
              Album album = Album(
                album: widget.music.album,
                albumId: widget.music.albumId,
                cover: widget.music.cover,
                singer: widget.music.singer,
                audioCount: 0,
              );
              Management().displayList = album;
              Management().displayListType = 'Album';

              Management().displayMusics = [];
              Management().displayAlbums = [];
              Management().getDisplayAlbum(album);

              Management().refresh();
              print('查看专辑: ${album.album}');
              break;
            case 'addToList':
              // 处理添加到列表逻辑
              await showAddMusicDialog(context);
              break;
            case 'download':
              // 处理下载逻辑
              await showDownloadDialog(context);
              break;
          }
        }
      },
      onTap: () {
        // 处理整行点击，播放当前音乐
        _playMusic();
      },
      child: MouseRegion(
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
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.musicIndexColor,
                ),
              ),

              SizedBox(width: 15),

              RemoteImage(
                widget.music.cover,
                headers: const {
                  'User-Agent':
                      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/131.0.0.0 Safari/537.36',
                },
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                borderRadius: 12,
                boxShadow: kImageBoxShadow,
                // 列表里的封面只有 60×60，按 2 倍设备像素比解码即可，
                // 避免把 500×500 以上的原图整张解码进内存
                cacheWidth: 120,
                cacheHeight: 120,
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.left,
                        style: TextStyle(
                          fontSize: 18,
                          color: AppColors.musicNameColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      Text(
                        widget.music.singer,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
                  Management().like(widget.music.id).then((bool success) {
                    // 更新收藏状态
                    final isCollected =
                        management.cloud.collectionList.contains(
                          widget.music.id,
                        ) ??
                        false;
                    if (success) {
                      showMusicToast(
                        context,
                        message:
                            '歌曲 《${widget.music.name}》 ${isCollected ? '收藏' : '取消收藏'}成功',
                      );
                    } else {
                      showMusicToast(
                        context,
                        message:
                            '歌曲 《${widget.music.name}》 ${isCollected ? '取消收藏' : '收藏'}失败',
                        success: false,
                      );
                    }
                  });
                },
                child:
                    management.cloud?.collectionList.contains(
                          widget.music.id,
                        ) ??
                        false
                    ? Icon(
                        BootstrapIcons.heart_fill,
                        color: AppColors.likeIconColor,
                        size: 20,
                      )
                    : Icon(
                        BootstrapIcons.heart,
                        color: AppColors.buttonIcon,
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
      ),
    );
  }
}

/// 音乐卡片右键菜单栏
class MusicSelected {
  MusicSelected._(); // 仅提供静态方法，禁止实例化

  static OverlayEntry? _activeEntry;
  static Completer<String?>? _activeCompleter;

  static Future<String?> show(
    BuildContext context,
    Offset position,
    Music music, {
    String type = '',
    String playlistId = '',
  }) {
    // 同一时间只保留一个菜单：菜单打开期间再次右键其他歌曲时，先收起旧菜单
    _dismissActive(null);

    final Completer<String?> completer = Completer<String?>();
    late final OverlayEntry entry;

    entry = OverlayEntry(
      builder: (_) => _MusicSelectedMenu(
        position: position,
        music: music,
        type: type,
        playlistId: playlistId,
        onClose: (String? result) {
          if (identical(_activeEntry, entry)) {
            _activeEntry = null;
            _activeCompleter = null;
          }
          if (!completer.isCompleted) {
            completer.complete(result);
          }
          // 菜单可能已被下一次 show() 收起，避免重复 remove
          if (entry.mounted) {
            entry.remove();
          }
        },
      ),
    );

    _activeEntry = entry;
    _activeCompleter = completer;
    Overlay.of(context, rootOverlay: true).insert(entry);
    return completer.future;
  }

  /// 收起当前打开的菜单（如有），并把 [result] 传回给它的调用方
  static void _dismissActive(String? result) {
    final OverlayEntry? entry = _activeEntry;
    final Completer<String?>? completer = _activeCompleter;
    _activeEntry = null;
    _activeCompleter = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete(result);
    }
    if (entry != null && entry.mounted) {
      entry.remove();
    }
  }
}

/// 右键菜单浮层：全屏透明屏障 + 定位在鼠标位置的菜单面板。
class _MusicSelectedMenu extends StatefulWidget {
  final Offset position;
  final Music music;

  /// 外部传入的场景标识（如列表类型），State 里通过 widget.type 使用，
  /// 可用于按所在页面显示/隐藏部分菜单项
  final String type;

  /// 外部传入的歌单 id（当前所在歌单场景下才有意义），
  /// State 里通过 widget.playlistId 使用
  final String playlistId;
  final ValueChanged<String?> onClose;

  const _MusicSelectedMenu({
    required this.position,
    required this.music,
    required this.type,
    required this.playlistId,
    required this.onClose,
  });

  @override
  State<_MusicSelectedMenu> createState() => _MusicSelectedMenuState();
}

class _MusicSelectedMenuState extends State<_MusicSelectedMenu> {
  // 宽度为固定值；高度按菜单项数量自动计算（见 build 里的 menuHeight），
  // 增删菜单项时无需再手动同步尺寸常量，否则屏幕边缘的收回计算会失准
  static const double _menuWidth = 160;
  static const double _itemHeight = 40;
  static const double _panelPadding = 6;

  String? _hoveredValue; // 当前悬停的菜单项

  /// 菜单项清单（value / 图标 / 文案）
  List<_MenuItemSpec> _buildMenuItems() {
    final bool isCollected = _isCollected();
    return [
      _MenuItemSpec('play', BootstrapIcons.play, '播放'),
      _MenuItemSpec('playNext', BootstrapIcons.skip_end, '下一首播放'),
      // if (widget.type == 'Playlist')
      if (widget.type == 'Playlist' &&
          Management().cloud.playlist.any((p) => p.listId == widget.playlistId))
        _MenuItemSpec('delete', BootstrapIcons.trash, '从歌单中删除'),
      _MenuItemSpec(
        'like',
        isCollected ? BootstrapIcons.heart_fill : BootstrapIcons.heart,
        isCollected ? '取消收藏' : '收藏',
      ),
      if (widget.type != 'Singer')
        _MenuItemSpec('viewSinger', BootstrapIcons.person, '查看艺人'),
      if (widget.type != 'Album')
        _MenuItemSpec('viewAlbum', BootstrapIcons.disc, '查看专辑'),
      _MenuItemSpec('addToList', BootstrapIcons.plus_square, '添加到歌单'),
      _MenuItemSpec('download', BootstrapIcons.download, '下载'),
    ];
  }

  /// 收藏状态是纯读取；cloud 是 late 字段，未登录时未初始化，
  /// 直接访问会抛异常导致整个菜单构建失败，这里兜底为未收藏
  bool _isCollected() {
    try {
      return Management().cloud.collectionList.contains(widget.music.id);
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final List<_MenuItemSpec> menuItems = _buildMenuItems();
    // 面板高度 = 上下内边距 + 菜单项数 × 单项高度
    final double menuHeight =
        menuItems.length * _itemHeight + _panelPadding * 2;

    double left = widget.position.dx;
    double top = widget.position.dy + 8; // 往下偏移一点，不盖住光标
    // 菜单即将越出屏幕时整体向内收（四周留 8px 边距）
    if (left + _menuWidth > screenSize.width - 8) {
      left = screenSize.width - _menuWidth - 8;
    }
    if (top + menuHeight > screenSize.height - 8) {
      top = screenSize.height - menuHeight - 8;
    }
    if (left < 8) {
      left = 8;
    }
    if (top < 8) {
      top = 8;
    }

    return Focus(
      autofocus: true,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () =>
              widget.onClose(null),
        },
        child: Stack(
          children: [
            Positioned.fill(
              child: Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: (PointerDownEvent event) {
                  if (event.buttons == kSecondaryMouseButton) {
                    widget.onClose(null);
                  }
                },
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () => widget.onClose(null),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
            Positioned(left: left, top: top, child: _buildMenuPanel(menuItems)),
          ],
        ),
      ),
    );
  }

  /// 菜单容器：外圆弧 + 外阴影
  Widget _buildMenuPanel(List<_MenuItemSpec> menuItems) {
    // Overlay 里没有 Material 祖先时，Text 会退化成带黄色下划线的兜底样式，
    // 这里用透明 Material 提供正常的文字环境，自身不绘制任何背景
    return Material(
      type: MaterialType.transparency,
      // opaque：整个面板矩形（含内边距、分隔线空隙）都吞掉指针事件，
      // 防止点穿面板落到下层的歌曲卡片上
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {},
        onSecondaryTap: () {},
        child: Container(
          width: _menuWidth,
          padding: const EdgeInsets.all(_panelPadding),
          decoration: BoxDecoration(
            color: AppColors.background,
            // 外圆弧
            borderRadius: BorderRadius.circular(14),
            // 外阴影：一层大而软的投影 + 一层近距投影勾出轮廓
            boxShadow: const [
              BoxShadow(
                color: Color(0x1F000000),
                blurRadius: 24,
                offset: Offset(0, 8),
              ),
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 4,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: menuItems
                .map(
                  (item) => _buildMenuItem(item.value, item.icon, item.label),
                )
                .toList(),
          ),
        ),
      ),
    );
  }

  /// 菜单项：悬停高亮是内缩的圆角矩形（内圆弧），不顶到菜单边缘
  Widget _buildMenuItem(String value, IconData icon, String label) {
    final bool hovered = _hoveredValue == value;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hoveredValue = value),
      onExit: (_) => setState(() => _hoveredValue = null),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onClose(value),
        child: Container(
          height: _itemHeight,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: hovered ? AppColors.floating : Colors.transparent,
            // 内圆弧
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(icon, size: 16, color: AppColors.buttonIcon),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.normalText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 菜单项描述：动作标识 / 图标 / 文案
class _MenuItemSpec {
  final String value;
  final IconData icon;
  final String label;

  const _MenuItemSpec(this.value, this.icon, this.label);
}
