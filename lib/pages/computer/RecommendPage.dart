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
    final List<Playlist> playlists = management.recommendList.playlist;
    // 没有数据时整块（标题、内边距）都不出现，免得留下一片空白占位。
    if (playlists.isEmpty) {
      return const SizedBox.shrink();
    }

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
                  for (int i = 0; i < num * 2 && i < playlists.length; i++)
                    PlaylistWidget(
                      playlist: playlists[i],
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
    final List<Album> albums = management.recommendList.album;
    // 没有数据时整块（标题、内边距）都不出现，免得留下一片空白占位。
    if (albums.isEmpty) {
      return const SizedBox.shrink();
    }

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
                  for (int i = 0; i < num * 2 && i < albums.length; i++)
                    AlbumWidget(
                      album: albums[i],
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
    final List<Singer> singers = management.recommendList.singer;
    // 没有数据时整块（标题、内边距）都不出现，免得留下一片空白占位。
    if (singers.isEmpty) {
      return const SizedBox.shrink();
    }

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
                  for (int i = 0; i < num * 2 && i < singers.length; i++)
                    SingerWidget(
                      singer: singers[i],
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
    final List<Music> musics = management.recommendList.music;
    // 没有数据时整块（标题、内边距）都不出现，免得留下一片空白占位。
    if (musics.isEmpty) {
      return const SizedBox.shrink();
    }

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
              RecommendTitle(
                title: '歌曲',
                icon: BootstrapIcons.music_note_beamed,
              ),

              SizedBox(height: 15),

              Wrap(
                spacing: 20,
                runSpacing: 15,
                children: [
                  for (var item in musics)
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

class RecommendTitle extends StatefulWidget {
  final String title;
  final IconData icon;

  const RecommendTitle({super.key, required this.title, required this.icon});

  @override
  State<RecommendTitle> createState() => _RecommendTitleState();
}

class _RecommendTitleState extends State<RecommendTitle>
    with SingleTickerProviderStateMixin {
  bool isHovering = false;

  /// 刷新请求进行中：图标匀速旋转，同时用来拦住重复点击。
  bool isRefreshing = false;

  /// 旋转一圈的时长，也是单次刷新动画的最短时长。
  static const Duration _spinCycle = Duration(milliseconds: 900);

  late final AnimationController _rotation;

  @override
  void initState() {
    super.initState();
    _rotation = AnimationController(vsync: this, duration: _spinCycle);
  }

  @override
  void dispose() {
    _rotation.dispose();
    super.dispose();
  }

  /// 执行一次刷新请求，期间让按钮图标转起来。
  Future<void> _refresh(Future<void> Function() request) async {
    if (isRefreshing) {
      return; // 连点只发一次请求
    }
    setState(() {
      isRefreshing = true;
    });
    _rotation.repeat();

    try {
      await request();
    } catch (error) {
      print('刷新推荐失败: ${error}');
    }

    // 接口很快时动画也不能一闪而过，否则看起来像没反应。补足当前这一圈剩下
    // 的部分，正好停在整圈的位置上，不会中途硬切回起始角度。
    final remain = (1 - _rotation.value) * _spinCycle.inMilliseconds;
    await Future.delayed(Duration(milliseconds: remain.round()));

    if (mounted) {
      _rotation.reset();
      setState(() {
        isRefreshing = false;
      });
    }
  }

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
          child: Icon(widget.icon, size: 20, color: AppColors.buttonIcon),
        ),

        SizedBox(width: 10),

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
          widget.title,
          style: TextStyle(fontSize: 20, color: AppColors.normalText),
        ),

        Expanded(child: SizedBox()), // 占位，推到最右边

        GestureDetector(
          onTap: () {
            // 处理点击设置按钮事件
            // Management().selectedPage = 'SettingsPage';
            if (widget.title == '歌曲') {
              Management().displayList = Playlist(
                name: '',
                listId: '',
                cover: '',
                audioCount: 0,
              );
              Management().displayMusics = List.of(
                Management().recommendList.music,
              );
              Management().playMusic(Management().recommendList.music[0]);
              print('播放音乐: ${Management().recommendList.music[0].name}');
            } else if (widget.title == '专辑') {
              _refresh(() => Management().createrRecommendAlbums(type: 1));
              print('刷新专辑推荐');
            } else if (widget.title == '歌单') {
              _refresh(() => Management().createrRecommendPlaylists(type: 1));
              print('刷新歌单推荐');
            } else if (widget.title == '歌手') {
              _refresh(() => Management().createrRecommendSingers(type: 1));
              print('刷新歌手推荐');
            }
          },
          child: MouseRegion(
            onEnter: (_) {
              setState(() {
                isHovering = true;
              });
            },
            onExit: (_) {
              setState(() {
                isHovering = false;
              });
            },
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: isHovering ? AppColors.floating : AppColors.panel,
                borderRadius: BorderRadius.circular(15),
              ),
              child: widget.title != '歌曲'
                  // 刷新按钮：初始保持原来的倾斜角度，请求期间从该角度转圈。
                  ? RotatedBox(
                      quarterTurns: 45,
                      child: RotationTransition(
                        turns: _rotation,
                        child: Icon(
                          BootstrapIcons.arrow_clockwise,
                          size: 20,
                          color: AppColors.buttonIcon,
                        ),
                      ),
                    )
                  : Icon(
                      BootstrapIcons.play,
                      size: 20,
                      color: AppColors.buttonIcon,
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
