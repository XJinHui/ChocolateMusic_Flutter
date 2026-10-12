import 'package:flutter/material.dart';
import 'package:bootstrap_icons/bootstrap_icons.dart';
import 'package:chocolate_music/theme/app_colors.dart';
import 'package:chocolate_music/Type.dart';
import 'package:chocolate_music/Management.dart';
import 'package:chocolate_music/components/EdgeFadeMask.dart';
import 'package:chocolate_music/components/MusicComponents.dart';
import 'package:chocolate_music/components/RemoteImage.dart';

class PlaylistPage extends StatefulWidget {
  final Management management = Management();

  // late List<Music> displayMusics = [];
  // late List<Album> displayAlbums = [];

  void getDisplay() {
    final management = this.management;

    management.displayMusics = [];
    management.displayAlbums = [];

    if (management.displayListType == 'Playlist') {
      management.getDisplayPlaylist(management.displayList as Playlist);
    } else if (management.displayListType == 'Album') {
      management.getDisplayAlbum(management.displayList as Album);
    } else if (management.displayListType == 'Singer') {
      management.getDisplaySinger(management.displayList as Singer);
      // displayMusics = display['musics'];
      // displayAlbums = display['albums'];
    }

    // 如果 Management 中的字段没有自动通知，这里保证页面刷新
    management.refresh();
  }

  @override
  State<PlaylistPage> createState() => _PlaylistPageState();
}

class _PlaylistPageState extends State<PlaylistPage> {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.management,
      builder: (BuildContext context, Widget? child) {
        return Container(
          color: AppColors.background,
          // child: Container(
          padding: EdgeInsets.only(top: 10, left: 20, right: 20),
          child: Scaffold(
            backgroundColor: AppColors.background, // 覆盖主题默认值
            body: EdgeFadeMask(
              // 顶部是固定不动的 SliverAppBar 和列表标签栏，
              // 开顶部渐隐会把它们一起盖住，这里只保留底部渐隐
              topFade: false,
              child: CustomScrollView(
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
                    surfaceTintColor: Colors.transparent,
                    // <--- 添加这一行，禁用 Material 3 表面染色
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

                  // 歌曲列表：懒加载，只构建视口内的行，滚出视口即被回收
                  MusicListSliver(management: widget.management),
                ],
              ),
            ),
          ),
        );
      },
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
  // 当前展示的对象可能是 Playlist / Album / Singer。
  // 统一在这里按实际类型取封面和标题，避免像原来那样无条件
  // `as Playlist` 而抛出 "type 'Singer' is not a subtype of type 'Playlist' in type cast"。
  Object? get _displayList {
    // displayList 是 late 字段，首次进入程序时可能还没赋值，这里做一次兜底
    try {
      return widget.management.displayList;
    } catch (_) {
      return null;
    }
  }

  String get _cover {
    final Object? list = _displayList;
    if (list is Playlist) return list.cover;
    if (list is Album) return list.cover;
    if (list is Singer) return list.cover;
    return '';
  }

  String get _title {
    final Object? list = _displayList;
    if (list is Playlist) return list.name;
    if (list is Album) return list.album;
    if (list is Singer) return list.singer;
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        RemoteImage(
          _cover,
          headers: const {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/131.0.0.0 Safari/537.36',
          },
          width: widget.currentHeight,
          height: widget.currentHeight,
          fit: BoxFit.cover,
          borderRadius: widget.currentHeight / 5,
          // boxShadow: kImageBoxShadow,
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

        SizedBox(
          width:
              15 +
              15 *
                  ((widget.currentHeight - 60.0) / (170.0 - 60.0)).clamp(
                    0.0,
                    1.0,
                  ),
        ),

        if (widget.currentHeight > 120)
          SizedBox(
            height: widget.currentHeight, // 跟左边图片同高
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, // 左对齐
              children: [
                // SizedBox(height: 20),
                Text(
                  _title,
                  style: TextStyle(
                    color: AppColors.playlistNameColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 20 +
                        10 *
                            ((widget.currentHeight - 60.0) / (170.0 - 60.0))
                                .clamp(0.0, 1.0),
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
                    if (widget.management.displayMusics.length != 0) {
                      widget.management.playMusic(
                        widget.management.displayMusics[0],
                      );
                      print('播放音乐: ${widget.management.displayMusics[0].name}');
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
                _title,
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


        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            SearchBar(listVersion: widget.management.displayListVersion),

            SizedBox(
              height:
              15 -
                  10 *
                      ((widget.currentHeight - 60.0) / (170.0 - 60.0)).clamp(
                        0.0,
                        1.0,
                      ),
            ),
          ],
        )
        )

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

/// 歌曲列表（懒加载）。
///
/// 原实现是 `SliverToBoxAdapter` + `Column`：进入歌单时会一次性构建
/// 全部歌曲（歌单可能上千首），每行又各自发起一次封面请求，
/// 首帧耗时、内存占用都随歌单长度线性增长，滚动时还要重建整屏。
///
/// 换成 `SliverFixedExtentList` 之后：
/// - 只构建视口 + cacheExtent 内的行，滚出视口立刻回收对应的 Element
///   与已解码的封面，长歌单的内存占用与歌单长度解耦；
/// - 行高固定（80 + 10 间距），滚动时无需逐行测量，
///   滚动位置、`jumpTo` 的计算都是 O(1)，快速滚动不会掉帧。
class MusicListSliver extends StatelessWidget {
  /// 单行总高度：ComputerMusicWidget 自身 80 + 行间距 10。
  static const double rowExtent = 90;

  final Management management;

  const MusicListSliver({Key? key, required this.management}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final List<Music> musics = management.displayMusics;
    // 搜索态由 Management 上的关键词决定，不能用结果列表是否为空来判断：
    // 搜了但没命中时结果列表就是空的，那样会被当成「没在搜索」而显示整个歌单。
    final List<Music> displayMusics = management.isListSearching
        ? management.displayListSearchMusic
        : management.displayMusics;

    return SliverFixedExtentList(
      itemExtent: rowExtent,
      delegate: SliverChildBuilderDelegate(
        (BuildContext context, int index) {
          return Padding(
            // 行间距放在 item 内部，保证每行高度都恰好等于 rowExtent
            padding: const EdgeInsets.only(bottom: 10),
            child: ComputerMusicWidget(
              music: displayMusics[index],
              displayList: management.displayList,
              displayListType: management.displayListType,
              num: index + 1,
              displayMusics: musics,
            ),
          );
        },
        childCount: displayMusics.length,
        // 不保活：滚出视口的行连 State 一起释放，避免内存常驻
        addAutomaticKeepAlives: false,
        // 长列表不需要语义索引，去掉可减少每行的语义节点
        addSemanticIndexes: false,
      ),
    );
  }
}

class SearchBar extends StatefulWidget {
  /// 当前显示列表（歌单/专辑/歌手）的切换计数，取自 [Management.displayListVersion]。
  ///
  /// 它一变就说明换了列表，输入框里上一个列表的关键词已经没有意义，需要清掉。
  final int listVersion;

  const SearchBar({super.key, required this.listVersion});

  @override
  State<SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<SearchBar> {
  final TextEditingController _controller = TextEditingController();

  @override
  void didUpdateWidget(SearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.listVersion != widget.listVersion) {
      _controller.clear();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      width: 200,
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(15),
      ),
      child: TextField(
        controller: _controller,
        cursorHeight: 18,        // 关键：光标高度，比字号略大即可
        cursorWidth: 1.5,        // 可选：细一点更精致
        decoration: InputDecoration(
          hintText: '搜索',
          border: InputBorder.none,
          // 前置图标
          prefixIcon:const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(BootstrapIcons.search),
            ),
          // prefixIcon 默认最小 48x48，会顶开高 30 的标题栏，这里显式收窄
          prefixIconConstraints: const BoxConstraints(
            minWidth: 34,
            minHeight: 30,
          ),
          // border: OutlineInputBorder(), // 边框样式
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 5),
        ),
        onChanged: (value) {
          // 处理搜索输入变化
          // print('搜索输入: $value');
          Management().listSearch(value.trim());
        }
      ),
    );
  }
}