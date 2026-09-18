import 'package:flutter/material.dart';

import 'package:chocolate_music/theme/app_colors.dart';
import 'package:chocolate_music/Type.dart';
import 'package:chocolate_music/Management.dart';
import 'package:chocolate_music/components/RemoteImage.dart';
import 'package:chocolate_music/components/MusicComponents.dart';

class AddToPlaylistPage extends StatefulWidget {
  const AddToPlaylistPage({super.key});

  @override
  State<AddToPlaylistPage> createState() => _AddToPlaylistPageState();
}

class _AddToPlaylistPageState extends State<AddToPlaylistPage> {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            '添加到歌单',
            style: TextStyle(
              color: AppColors.normalText,
              fontWeight: FontWeight.bold,
              fontSize: 30,
            ),
          ),

          const SizedBox(height: 10),

          Expanded(child: _content()),

          const SizedBox(height: 10),
        ],
      ),
    );
  }

  /// 核心内容占位区域，后续替换为实际的添加音乐界面。
  Widget _content() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: Management().playlists.length,
        separatorBuilder: (context, index) {
          // 返回一个表示间隙的 Widget
          // 例如，一个固定高度的 SizedBox 或者带有颜色的 Container
          return SizedBox(height: 5); // 这里设置你想要的间隙高度
          // 或者使用 Container 添加带颜色的分割线
          // return Container(height: 1, color: Colors.grey.shade300);
        },
        itemBuilder: (context, index) {
          final Playlist playlist = Management().playlists[index];
          return playlistItem(
            playlist: playlist,
            onTap: () {
              print('点击了歌单：${playlist.name}');
              final NavigatorState navigator = Navigator.of(context);

              Management().addMusicToPlaylist(playlist.listId, Management().selectedMusic.id).then((bool success) {
                // 更新收藏状态
                if (!mounted) return;

                // 先弹提示再关窗：pop 之后本页的 context 就失效了
                showMusicToast(
                  context,
                  message: success
                      ? '已将《${Management().selectedMusic.name}》添加到《${playlist.name}》成功'
                      : '歌曲《${Management().selectedMusic.name}》添加到歌单失败',
                  success: success,
                );

                if (success) {
                  navigator.pop();
                }
              });
            },
          );
        },
      ),
    );
  }
}

class playlistItem extends StatefulWidget {
  // final String name;
  // final String cover;
  // final bool isSelected;
  final Playlist playlist;
  final Function() onTap;

  const playlistItem({
    Key? key,
    // required this.name,
    // required this.cover,
    // required this.isSelected,
    required this.playlist,
    required this.onTap,
  }) : super(key: key);

  @override
  State<playlistItem> createState() => _playlistItemState();
}

class _playlistItemState extends State<playlistItem> {
  bool isHovering = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap, // 点击时调用回调函数
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
          padding: EdgeInsets.only(bottom: 10, top: 10, left: 15, right: 15),
          // 和边框的间距
          // width: 190,
          height: 80,
          decoration: BoxDecoration(
            // 根据 isSelected 的值决定背景颜色
            color: isHovering
                ? AppColors.floating
                : AppColors.transparent,
            borderRadius: BorderRadius.circular(14), // 圆角
          ),
          child: Row(
            children: [
              RemoteImage(
                widget.playlist.cover,
                headers: const {
                  'User-Agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/131.0.0.0 Safari/537.36',
                },
                width: 50,
                height: 50,
                fit: BoxFit.cover,
                borderRadius: 10,
                boxShadow: kImageBoxShadow,
                // 加载失败时，errorBuilder 会被调用
                errorBuilder: (context, error, stackTrace) {
                  // 返回你的本地图片
                  return Image.asset(
                    'assets/images/app_photo.png',
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                  );
                },
              ),

              SizedBox(width: 10),

              Text(
                widget.playlist.name,
                style: TextStyle(
                  color: AppColors.normalText,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
