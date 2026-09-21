import 'package:flutter/material.dart';
import 'package:bootstrap_icons/bootstrap_icons.dart';

import 'package:chocolate_music/theme/app_colors.dart';
import 'package:chocolate_music/Management.dart';
import 'package:chocolate_music/Type.dart';
import 'package:chocolate_music/components/EdgeFadeMask.dart';
import 'package:chocolate_music/components/RemoteImage.dart';

/// 播放列表侧边栏的显隐状态。
///
/// 打开/关闭都要等动画跑完才能确定下一帧是否还需要挂载：
/// - [opening]/[closing] 期间侧边栏和遮罩都得留在树上；
/// - 只有 [closed] 才真正把两者从树上摘掉，不在动画期间点击穿透。
enum _PanelStatus { closed, opening, open, closing }

/// 播放列表侧边栏宿主。
///
/// 与 [LyricsTransitionHost] 同样的分工：宿主只把 [visible] 翻成动画和遮罩，
/// 不持有状态，也不知道状态存在哪儿——关闭请求通过 [onDismiss] 交回调用方。
///
/// 侧边栏不参与主界面布局：它盖在 [child] 上层，从窗口右边缘滑入，
/// 宽度固定 300，高度固定为窗口高度的 60%（上下各留 20%）并垂直居中。
class PlaybackListPanelHost extends StatefulWidget {
  const PlaybackListPanelHost({
    super.key,
    required this.visible,
    required this.onDismiss,
    required this.child,
  });

  /// 侧边栏宽度（逻辑像素）。
  static const double panelWidth = 350;

  /// 侧边栏高度占窗口高度的比例。
  static const double panelHeightFactor = 0.8;

  final bool visible;

  /// 点击侧边栏以外的区域时回调，由调用方把 [visible] 置回 false。
  final VoidCallback onDismiss;

  final Widget child;

  @override
  State<PlaybackListPanelHost> createState() => _PlaybackListPanelHostState();
}

class _PlaybackListPanelHostState extends State<PlaybackListPanelHost>
    with SingleTickerProviderStateMixin {
  static const Duration _openDuration = Duration(milliseconds: 220);
  static const Duration _closeDuration = Duration(milliseconds: 180);

  late final AnimationController _controller;
  late final CurvedAnimation _slide;
  _PanelStatus _status = _PanelStatus.closed;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _openDuration,
      reverseDuration: _closeDuration,
    );
    _slide = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    // 初始值要在挂监听之前写好，否则 status 回调会在 initState 里 setState。
    if (widget.visible) {
      _controller.value = 1;
      _status = _PanelStatus.open;
    }
    _controller.addStatusListener(_onStatus);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
  }

  @override
  void didUpdateWidget(covariant PlaybackListPanelHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visible == widget.visible) return;
    _applyVisibility();
  }

  @override
  void dispose() {
    _slide.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _applyVisibility() {
    final bool open = widget.visible;
    if (_reduceMotion) {
      _controller.value = open ? 1 : 0;
      setState(() => _status = open ? _PanelStatus.open : _PanelStatus.closed);
      return;
    }
    setState(
      () => _status = open ? _PanelStatus.opening : _PanelStatus.closing,
    );
    if (open) {
      _controller.forward();
    } else {
      _controller.reverse();
      // 值本来就停在 0 时 reverse() 不会产生状态变化，这里直接收尾。
      if (_controller.isDismissed) {
        setState(() => _status = _PanelStatus.closed);
      }
    }
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      setState(() => _status = _PanelStatus.open);
    } else if (status == AnimationStatus.dismissed) {
      setState(() => _status = _PanelStatus.closed);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final Size size = constraints.biggest;
        final double panelHeight =
            size.height * PlaybackListPanelHost.panelHeightFactor;
        // 关闭动画期间侧边栏还在往外滑，遮罩也要跟着留到动画结束，
        // 否则滑出的这一段时间里点击会穿透到底下的页面。
        final bool mounted = _status != _PanelStatus.closed;
        final Widget? panel = mounted
            ? Positioned(
                top: (size.height - panelHeight) / 2,
                right: 0,
                width: PlaybackListPanelHost.panelWidth,
                height: panelHeight,
                child: AnimatedBuilder(
                  animation: _slide,
                  // 面板本身是常量子树，不跟着动画逐帧重建。
                  child: const PlaybackListPanel(),
                  builder: (context, child) => Transform.translate(
                    // t=0 时整块面板停在窗口右边缘之外，被 Stack 裁掉，
                    // 因此滑入效果等同于“从窗口右侧推出来”。
                    offset: Offset(
                      PlaybackListPanelHost.panelWidth * (1 - _slide.value),
                      0,
                    ),
                    child: child,
                  ),
                ),
              )
            : null;

        return Stack(
          fit: StackFit.expand,
          // 侧边栏的入场位移落在窗口之外，超出部分必须裁掉。
          clipBehavior: Clip.hardEdge,
          children: [
            widget.child,

            // 侧边栏以外整片区域都用来关闭它：这层遮罩同时负责两件事——
            // - 压暗浮层以外的页面。面板是纯白的，页面底色也是纯白，
            //   不压暗的话两者糊成一片，看不出面板边界；
            // - 接管点击，顺带保证打开期间主界面上的按钮和列表不会被误触。
            if (mounted)
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _slide,
                  builder: (context, _) => ModalBarrier(
                    // 透明度跟着滑动走：面板滑出时遮罩若瞬间消失，
                    // 底色会从"被压暗"直接跳回白色，看起来像闪了一下。
                    color: AppColors.scrim.withValues(
                      alpha: AppColors.scrim.a * _slide.value,
                    ),
                    dismissible: true,
                    onDismiss: widget.onDismiss,
                  ),
                ),
              ),

            // 遮罩在下、侧边栏在上，所以点击侧边栏内部不会触发关闭。
            if (panel != null) panel,
          ],
        );
      },
    );
  }
}

/// 播放列表侧边栏面板本体。
class PlaybackListPanel extends StatelessWidget {
  const PlaybackListPanel({super.key});

  /// 标题栏高度，和主界面其他面板的留白保持一致。
  static const double _headerHeight = 52;

  /// 面板圆角半径。
  static const double _cornerRadius = 15;

  /// 让面板从窗口右边缘浮起来的投影。
  ///
  /// 面板和页面底色都是纯白，两者之间没有底色差可用，层次全靠两样东西：
  /// 宿主铺的那层 [AppColors.scrim] 暗化遮罩，以及这道投影 ——
  /// 它负责在面板边缘压出一圈暗部，把纯白面板从被压暗的页面里切出来。
  ///
  /// 面板贴着窗口右边缘，右半边没有可落影的空间，所以主投影朝左打。
  /// 第二条是四周的柔和扩散，负责上下边缘的"边缘阴影"，
  /// 不设偏移，只把面板轮廓从背景里托起来。
  static const List<BoxShadow> _panelShadow = [
    // 左边缘主投影
    BoxShadow(
      color: Color(0x47000000),
      blurRadius: 28,
      offset: Offset(-8, 0),
      spreadRadius: -2,
    ),
    // 四周柔和扩散，给上下边缘一点厚度
    BoxShadow(
      color: Color(0x1F000000),
      blurRadius: 12,
      offset: Offset(0, 4),
      spreadRadius: -4,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.overlaySurface,
        borderRadius: BorderRadius.circular(_cornerRadius),
        boxShadow: _panelShadow,
      ),
      // 必须显式裁剪到圆角：Container 默认 clipBehavior 是 Clip.none，
      // 圆角只是画出来的、不参与裁剪，子内容会直接盖到圆角外面，
      // 底部的圆弧就没了。
      //
      // 裁剪层要落在圆角矩形的边界上，所以不能用 Container 自带的
      // clipBehavior —— 那样会把投影一起裁掉，边缘阴影就跟着消失。
      // 这里改成手写 ClipRRect 包住内容，投影留在它上层的 DecoratedBox 上。
      child: ClipRRect(
        // 传不透明白色而不是 Colors.transparent：给窗口设了不透明度时，
        // 透明裁剪层会变成单独的合成层，白色面板会透出底下的暗化遮罩。
        // 内容（标题栏、列表）本来就是不透明的，视觉上没有区别。
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(_cornerRadius),
          bottom: Radius.circular(_cornerRadius),
        ),
        clipBehavior: Clip.antiAlias,
        child: ColoredBox(
          color: AppColors.overlaySurface,
          child: Column(
            children: [
              SizedBox(
                height: _headerHeight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  child: Row(
                    children: [
                      Icon(
                        BootstrapIcons.music_note_list,
                        size: 18,
                        color: AppColors.musicIndexColor,
                      ),

                      SizedBox(width: 10),

                      Text(
                        '当前播放',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.musicNameColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 列表占满标题栏以下的剩余高度。面板高度由宿主给定（窗口高度的固定比例），
              // 所以这里必须有约束地撑开，不能让它按内容自然高度走。
              Expanded(child: PlaylistWidget()),
            ],
          ),
        ),
      ),
    );
  }
}

class PlaylistWidget extends StatefulWidget {
  @override
  State<PlaylistWidget> createState() => _PlaylistWidgetState();
}

class _PlaylistWidgetState extends State<PlaylistWidget> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(left: 10, right: 10),
      child: EdgeFadeMask(
        child: CustomScrollView(slivers: [PlayMusicListSliver()]),
      ),
    );
  }
}

class PlayMusicListSliver extends StatelessWidget {
  static const double rowExtent = 90;

  @override
  Widget build(BuildContext context) {
    final List<Music> musics = Management().currentPlayMusicList;

    return SliverFixedExtentList(
      itemExtent: rowExtent,
      delegate: SliverChildBuilderDelegate(
        (BuildContext context, int index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: PlayMusicWidget(music: musics[index], num: index + 1),
          );
        },
        childCount: musics.length,
        addAutomaticKeepAlives: false,
        addSemanticIndexes: false,
      ),
    );
  }
}

class PlayMusicWidget extends StatefulWidget {
  final Music music;
  final int num;

  PlayMusicWidget({Key? key, required this.music, required this.num})
    : super(key: key);

  @override
  State<PlayMusicWidget> createState() => _PlayMusicWidgetState();
}

class _PlayMusicWidgetState extends State<PlayMusicWidget> {
  late Management management = Management();

  bool isHovering = false;

  _playMusic() {
    this.management.switchMusic(widget.music);
    print('播放音乐: ${widget.music.name}');
  }

  void _setHovering(bool value) {
    // MouseRegion 在支持鼠标的平台上重建时会补发一次 onEnter，
    // 不拦掉就会多出一轮无意义的 setState + 重建。
    if (isHovering == value) {
      return;
    }
    setState(() {
      isHovering = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // 处理整行点击，播放当前音乐
        _playMusic();
      },
      child: MouseRegion(
        onEnter: (_) => _setHovering(true),
        onExit: (_) => _setHovering(false),

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
              // 只有序号/播放图标和歌名歌手颜色依赖"当前在放哪首歌"。
              // 单独订阅 Management 而不是让整行重建：切歌时命中行和失去焦点的
              // 旧行都要换色，靠行内 setState（鼠标悬停）是刷不出来的。
              //
              // 订阅范围必须收在这几个子组件上——封面 RemoteImage 留在这层之外，
              // 避免每次 refresh（歌单增删、设置写入都会调）都重建一次，
              // 重置掉它内部的网络图片加载状态。
              ListenableBuilder(
                listenable: management,
                builder: (BuildContext context, Widget? child) => Row(
                  children: [
                    Container(
                      width: 20,
                      child: Align(
                        alignment: Alignment.center,
                        child: management.setting.id == widget.music.id
                            ? Icon(
                                BootstrapIcons.play_fill,
                                size: 25,
                                color: AppColors.selectedText,
                              )
                            : Text(
                                widget.num.toString(),
                                textAlign: TextAlign.left,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: AppColors.musicIndexColor,
                                ),
                              ),
                      ),
                    ),

                    SizedBox(width: 15),
                  ],
                ),
              ),

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
                  child: ListenableBuilder(
                    listenable: management,
                    builder: (BuildContext context, Widget? child) => Column(
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
                            color: management.setting.id == widget.music.id
                                ? AppColors.selectedText
                                : AppColors.musicNameColor,
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
                            color: management.setting.id == widget.music.id
                                ? AppColors.selectedText
                                : AppColors.musicSingerColor,
                          ),
                        ),
                      ],
                    ),
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
