import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:bootstrap_icons/bootstrap_icons.dart';

import 'package:chocolate_music/theme/app_colors.dart';
import 'package:chocolate_music/Management.dart';
import 'package:chocolate_music/Type.dart';
import 'package:chocolate_music/components/RemoteImage.dart';
import 'package:chocolate_music/components/OperationButton.dart';
import 'package:chocolate_music/components/LyricsTransition.dart';

class LyricsPage extends StatefulWidget {
  const LyricsPage({super.key});

  @override
  State<LyricsPage> createState() => _LyricsPageState();
}

class _LyricsPageState extends State<LyricsPage> {
  /// 背景模糊程度，数值越大越模糊，0 为不模糊。
  static const double _bgBlurSigma = 50;

  /// 背景暗化遮罩透明度（0.0 ~ 1.0），保证歌词在亮色封面上的可读性，0 为关闭。
  static const double _bgDimOpacity = 0.50;

  /// widget 测试里没有原生窗口通道，挂上 MoveWindow 会在拖动时触发
  /// 未捕获的异步异常，所以测试环境一律退化成普通空白。
  bool get _isTestEnvironment =>
      Platform.environment.containsKey('FLUTTER_TEST');

  /// 是否使用桌面端的原生窗口拖拽。判定与 TopToolBar 保持一致。
  bool get _useDesktopWindowChrome =>
      (Platform.isWindows || Platform.isLinux || Platform.isMacOS) &&
      !_isTestEnvironment;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: LyricsTransitionPart(
            background: true,
            child: Stack(
              children: [
                // 不透明底色：封面加载中或模糊光晕处都不会透出下层页面
                Positioned.fill(
                  child: ColoredBox(color: CupertinoColors.black),
                ),
                // 向四周扩约 3 倍 sigma，让模糊在图片边缘产生的透明光晕完全移出可视区域
                Positioned(
                  left: -_bgBlurSigma * 3,
                  top: -_bgBlurSigma * 3,
                  right: -_bgBlurSigma * 3,
                  bottom: -_bgBlurSigma * 3,
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(
                      sigmaX: _bgBlurSigma,
                      sigmaY: _bgBlurSigma,
                    ),
                    child: RemoteImage(
                      Management().playbackState.cover,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Positioned.fill(
                  child: ColoredBox(
                    color: CupertinoColors.black.withValues(
                      alpha: _bgDimOpacity,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        Row(
          children: [
            Expanded(child: MusicDisplayWidget()),
            Expanded(child: LyricsTransitionPart(child: LyricsDisplayWidget())),
          ],
        ),

        LyricsTransitionPart(
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(10), // 和边框的间距
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.transparent,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        // 点击图片打开歌词页
                        Management().lyricShow = false;
                        print('关闭歌词页');
                      },
                      child: Icon(
                        BootstrapIcons.chevron_down,
                        size: 18,
                        color: CupertinoColors.white,
                        // color: isHovering ? widget.floatingIconColor : AppColors.buttonIcon,
                      ),
                    ),

                    // 顶部中间的空白接住拖动：按住可移动窗口，双击最大化/还原，
                    // 与 TopToolBar 的拖拽区行为一致。
                    // 这里不需要外面套 WindowTitleBarBox —— bitsdojo_window 0.1.6
                    // 的 MoveWindow 只是一个 onPanStart 调原生 startDragging 的
                    // GestureDetector，WindowTitleBarBox 仅用于限定标题栏高度。
                    // 左右两侧留出图标（关闭按钮、窗口按钮）不被拖拽抢走点击。
                    Expanded(
                      child: _useDesktopWindowChrome
                          ? MoveWindow()
                          : const SizedBox(),
                    ),

                    OperationButton(lyricMode: true),
                  ],
                ),
              ),

              Expanded(child: SizedBox()), // 占位
            ],
          ),
        ),
      ],
    );
  }
}

class MusicDisplayWidget extends StatefulWidget {
  @override
  State<MusicDisplayWidget> createState() => _MusicDisplayWidgetState();
}

class _MusicDisplayWidgetState extends State<MusicDisplayWidget> {
  // 封面是否被按住：按住缩小，松开弹回
  bool _coverPressed = false;

  static const Duration _pressDuration = Duration(milliseconds: 120);
  static const Duration _releaseDuration = Duration(milliseconds: 200);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double w = constraints.maxWidth; // 本区域宽度
        final double h = constraints.maxHeight; // 本区域高度

        // 用 w/h 推导内部尺寸,替代写死的 350 / 400
        final double coverSize = (w * 0.8).clamp(200.0, h * 0.5);
        final double width = coverSize + 50;

        return Column(
          children: [
            Expanded(child: SizedBox()), // 占位

            GestureDetector(
              onTapDown: (_) => setState(() => _coverPressed = true),
              onTapCancel: () => setState(() => _coverPressed = false),
              onTapUp: (_) {
                // 从实际按压尺寸衔接退出，不再等待回弹或留下延迟任务。
                setState(() => _coverPressed = false);
                Management().lyricShow = false;
              },
              child: AnimatedScale(
                scale: _coverPressed ? 0.95 : 1.0,
                duration: _coverPressed ? _pressDuration : _releaseDuration,
                curve: _coverPressed ? Curves.easeOut : Curves.easeOutBack,
                child: LyricsCoverAnchor(
                  destination: true,
                  child: RemoteImage(
                    Management().playbackState.cover,
                    headers: const {
                      'User-Agent':
                          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/131.0.0.0 Safari/537.36',
                    },
                    width: coverSize,
                    height: coverSize,
                    fit: BoxFit.cover,
                    borderRadius: coverSize / 10,
                    boxShadow: kImageBoxShadow,
                    // 加载失败时，errorBuilder 会被调用
                    errorBuilder: (context, error, stackTrace) {
                      // 返回你的本地图片
                      return Image.asset(
                        'assets/images/app_photo.png',
                        width: coverSize,
                        height: coverSize,
                        fit: BoxFit.cover,
                      );
                    },
                  ),
                ),
              ),
            ),

            SizedBox(height: coverSize / 8),

            LyricsTransitionPart(
              child: Container(
                width: width,
                child: Column(
                  children: [
                    PlaybackProgressBar(),

                    SizedBox(height: coverSize / 20),

                    PlayControlButton(),
                  ],
                ),
              ),
            ),

            Expanded(child: SizedBox()), // 占位
          ],
        );
      },
    );
  }
}

class LyricsDisplayWidget extends StatefulWidget {
  @override
  State<LyricsDisplayWidget> createState() => _LyricsDisplayWidgetState();
}

class _LyricsDisplayWidgetState extends State<LyricsDisplayWidget> {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double w = constraints.maxWidth; // 本区域宽度
        final double h = constraints.maxHeight; // 本区域高度

        final double width = w * 0.8;

        // 这一层 Align 是让 width 生效的关键：
        // 上面 Expanded 传下来的是"紧宽度"约束（min = max = 半屏宽），
        // 直接写 Container(width: w * 0.8) 会被约束夹回满宽。
        // Align 会把约束放松给子级，宽度才生效，整块也就水平居中了。
        return Align(
          alignment: Alignment.center,
          child: Container(
            width: width,
            child: Column(
              // 块的高度会被下面的 Expanded 撑满，所以这里其实没有剩余空间可分，
              // 垂直留白要用 children 里的 SizedBox 控制
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start, // 块内左对齐
              children: [
                SizedBox(height: h * 0.1),

                Text(
                  Management().playbackState.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.left,
                  style: TextStyle(
                    fontSize: 30,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                SizedBox(height: 5),

                Text(
                  Management().playbackState.singer,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.left,
                  style: TextStyle(fontSize: 20, color: Colors.white),
                ),

                SizedBox(height: 20),

                Expanded(
                  child: Management().displayLyricList.length > 0
                      ? DisplayLyric()
                      : Center(
                          child: Text(
                            '暂无歌词',
                            style: TextStyle(
                              fontSize: 30,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                ),

                SizedBox(height: h * 0.1),
              ],
            ),
          ),
        );
      },
    );
  }
}

class PlayControlButton extends StatefulWidget {
  @override
  _PlayControlButtonState createState() => _PlayControlButtonState();
}

class _PlayControlButtonState extends State<PlayControlButton> {
  final management = Management();

  static const List sequence = [
    BootstrapIcons.repeat,
    BootstrapIcons.shuffle,
    BootstrapIcons.repeat_1,
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center, // 水平居中
      children: [
        Expanded(child: SizedBox()),

        GestureDetector(
          onTap: () {
            management.updatePlayType();
            management.updatePlayType();
          },
          child: Icon(
            sequence[management.setting.playType],
            color: Colors.white,
            size: 30,
          ), // TODO: 根据当前播放模式显示不同的图标
        ),

        // SizedBox(width: 20), // 图标之间的间距
        Expanded(child: SizedBox()),

        GestureDetector(
          onTap: () {
            // TODO: 实现上一首功能
            management.playMusicControl.lastMusic();
            print('上一首');
          },
          child: Icon(
            BootstrapIcons.skip_start_fill,
            color: Colors.white,
            size: 40,
          ), // 上一首图标
        ),

        // SizedBox(width: 20), // 图标之间的间距
        Expanded(child: SizedBox()),

        GestureDetector(
          onTap: () {
            // TODO: 实现播放/暂停功能
            management.playMusicControl.pausePlayMusic();
            // print('播放/暂停');
          },
          // child: Icon(BootstrapIcons.pause_circle_fill, color: Colors.black, size: 35,), // 播放图标
          child: Icon(
            management.playbackState.play
                ? BootstrapIcons.pause_fill
                : BootstrapIcons.play_fill,
            color: Colors.white,
            size: 70,
          ), // 播放图标a
        ),

        // SizedBox(width: 20), // 图标之间的间距
        Expanded(child: SizedBox()),

        GestureDetector(
          onTap: () {
            // TODO: 实现下一首功能
            management.playMusicControl.nextMusic();
            print('下一首');
          },
          child: Icon(
            BootstrapIcons.skip_end_fill,
            color: Colors.white,
            size: 40,
          ), // 下一首图标
        ),

        // SizedBox(width: 20), // 图标之间的间距
        Expanded(child: SizedBox()),

        GestureDetector(
          onTap: () {
            // TODO: 实现查看播放列表功能
            management.playlistShow = !management.playlistShow;
          },
          child: Icon(
            BootstrapIcons.music_note_list,
            color: Colors.white,
            size: 30,
          ), // 查看播放列表图标
        ),

        Expanded(child: SizedBox()),
      ],
    );
  }
}

class PlaybackProgressBar extends StatefulWidget {
  const PlaybackProgressBar({Key? key}) : super(key: key);

  @override
  State<PlaybackProgressBar> createState() => _PlaybackProgressBarState();
}

class _PlaybackProgressBarState extends State<PlaybackProgressBar> {
  final management = Management();
  bool _dragging = false;
  double _dragValue = 0;

  // 将秒数转换为 mm:ss
  String _formatTime(double seconds) {
    final int totalSeconds = seconds.round();
    final int minutes = totalSeconds ~/ 60;
    final int secs = totalSeconds % 60;
    final String m = minutes.toString().padLeft(2, '0');
    final String s = secs.toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    // 进度条只订阅 progressNotifier。
    // 播放时进度每几百毫秒更新一次，若直接依赖 Management 的全局通知，
    // 歌单页几百行列表会跟着一起重建，播放时就会卡。
    return ValueListenableBuilder<int>(
      valueListenable: management.progressNotifier,
      builder: (BuildContext context, int progressMs, Widget? child) {
        // musicProgress / musicDuration 都是毫秒，Slider 用秒。
        final double durationSeconds = management.musicDuration <= 0
            ? 1000000.0
            : management.musicDuration / 1000.0;
        final double progressSeconds = (progressMs / 1000.0).clamp(
          0.0,
          durationSeconds,
        );
        final double sliderValue = _dragging
            ? _dragValue.clamp(0.0, durationSeconds)
            : progressSeconds;

        return Column(
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                // 通过 trackHeight 控制滑轨高度
                trackHeight: 10.0,
                // 调整拇指（圆点）半径
                thumbShape: RoundSliderThumbShape(enabledThumbRadius: 5.0),
                // 调整按下时的覆盖层半径
                overlayShape: RoundSliderOverlayShape(overlayRadius: 0.0),
                // 轨道和拇指的颜色（可按需替换）
                activeTrackColor: AppColors.musicProgressColor,
                inactiveTrackColor: Colors.grey.shade300,
                thumbColor: AppColors.musicProgressColor,
              ),
              child: Slider(
                value: sliderValue,
                min: 0.0,
                max: durationSeconds,
                onChangeStart: (value) {
                  setState(() {
                    _dragging = true;
                    _dragValue = value;
                  });
                },
                onChanged: (value) {
                  setState(() {
                    _dragValue = value;
                  });
                },
                onChangeEnd: (value) {
                  setState(() {
                    _dragging = false;
                    _dragValue = value;
                  });
                  // Slider 的 value 单位是秒，changeProgress 收的是毫秒
                  management.playMusicControl.changeProgress(
                    (value * 1000).round(),
                  );
                },
              ),
            ),

            // ),
            SizedBox(height: 10), // 时间和进度条之间的间距

            Row(
              mainAxisAlignment: MainAxisAlignment.center, // 垂直居中
              crossAxisAlignment: CrossAxisAlignment.center, // 水平居中
              children: [
                Text(
                  _formatTime(sliderValue),
                  style: TextStyle(color: Colors.white),
                ), // 当前时间

                Expanded(child: SizedBox()), // 占位

                Text(
                  management.playbackState.time,
                  style: TextStyle(color: Colors.white),
                ), // 总时间
              ],
            ),
          ],
        );
      },
    );
  }
}

class DisplayLyric extends StatefulWidget {
  const DisplayLyric({Key? key}) : super(key: key);

  @override
  State<DisplayLyric> createState() => _DisplayLyricState();
}

class _DisplayLyricState extends State<DisplayLyric> {
  /// 滚动动画时长。太短会显得跳，太长会追不上快歌。
  static const Duration _scrollDuration = Duration(milliseconds: 320);

  /// 当前行在视口中的位置比例（上边缘）。
  /// 1/4 表示上方留 1/4 屏、下方留 3/4 屏给后续歌词；改成 3/4 则相反。
  /// 上和下的留白会按这个比例自动分配，第一行与最后一行都能落到该位置。
  static const double _lineAnchor = 1 / 4;

  /// 歌词列表上下渐隐的过渡区高度，取视口高度的比例。
  /// 顶部向下 _fadeExtent 由全透明渐变到不透明，底部对称，中间全清晰。
  /// 要比 _lineAnchor 小，当前行（落在 _lineAnchor 处）才不会跟着被淡掉。
  static const double _fadeExtent = 0.15;

  final Management _management = Management();
  final ScrollController _scrollController = ScrollController();

  /// 每一行歌词的 GlobalKey。
  ///
  /// 要把某一行滚到中间，必须先拿到那一行的 BuildContext。
  /// ListView.builder 只构建视口附近的行，屏幕外的行取不到 context，
  /// 所以这里换成 SingleChildScrollView + Column 整段构建。
  final List<GlobalKey> _lineKeys = [];

  /// 上一次已经滚过去的目标行，用来避免重复滚动。
  int _scrolledIndex = -1;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// 目标行与上一次不同时，等这一帧布局完成后把它滚到 _lineAnchor 处。
  ///
  /// 之所以在 build 里发起（而不是订阅通知回调），是为了同时覆盖两种情况：
  /// 播放中切换歌词行，以及播放到一半才打开歌词页（那时行号早就有值了）。
  void _scheduleLineAnchor(int index) {
    if (index == _scrolledIndex) {
      return;
    }
    _scrolledIndex = index;
    WidgetsBinding.instance.addPostFrameCallback((_) => _anchorLine(index));
  }

  void _anchorLine(int index) {
    if (!mounted || index < 0 || index >= _lineKeys.length) {
      return;
    }

    final BuildContext? lineContext = _lineKeys[index].currentContext;
    if (lineContext == null) {
      return;
    }

    // ensureVisible 的 alignment 是这一行「上边缘」在视口中的位置比例，
    // 所以传 1/3 时行的中心会比 1/3 线再低半个行高（约十几像素），
    // 肉眼看就是"当前行落在偏上的三分之一处"。
    Scrollable.ensureVisible(
      lineContext,
      alignment: _lineAnchor,
      duration: _scrollDuration,
      curve: Curves.easeOutCubic,
    );
  }

  /// 让 _lineKeys 与歌词行数保持一致（行数只在换歌时变化）。
  void _syncLineKeys(int count) {
    while (_lineKeys.length < count) {
      _lineKeys.add(GlobalKey());
    }
    if (_lineKeys.length > count) {
      _lineKeys.removeRange(count, _lineKeys.length);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 歌词列表整体替换（换歌）时跟随 Management 重建；
    // 播放中的行高亮与滚动只订阅 lyricLineNotifier，
    // 避免进度回调每几百毫秒把整棵页面子树重建一次。
    return ListenableBuilder(
      listenable: Listenable.merge([
        _management,
        _management.lyricLineNotifier,
      ]),
      builder: (BuildContext context, Widget? child) {
        // 这里必须实时读取列表，不能缓存成字段：
        // getMusicLyric 每次换歌都是整体替换 list 对象。
        final List<LyricsMap> lyricList = _management.displayLyricList;
        if (lyricList.isEmpty) {
          _lineKeys.clear();
          _scrolledIndex = -1;
          return const SizedBox.shrink();
        }

        final int currentIndex = _management.lyricLineNotifier.value;
        _syncLineKeys(lyricList.length);
        _scheduleLineAnchor(currentIndex);

        return LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            // 滚动区的上下留白要够，第一行和最后一行才都能被推到 _lineAnchor 处：
            // 上方至少留 _lineAnchor 屏，下方至少留 (1 - _lineAnchor) 屏。
            // 上方留少了，目标会被夹在更靠下的位置；下方留少了，
            // 最后几行就只能停在比目标更靠中间的地方。
            final double viewportHeight = constraints.maxHeight;

            // 桌面端 MaterialScrollBehavior.buildScrollbar 会给垂直滚动视图
            // 自动套一层 Scrollbar，滑块就落在歌词右侧、还会占掉一条宽度。
            // 歌词页不要这个滑块，在本子树里把它关掉；
            // 滚轮 / 拖拽滚动仍然照常（那由 Scrollable 自己负责）。
            return ScrollConfiguration(
              behavior: const _NoScrollbarBehavior(),
              // 上下渐隐：把歌词列表当成一张图，用「顶部透明 → 中间不透明 →
              // 底部透明」的遮罩裁掉它两端的透明度。
              //
              // 遮罩铺在 ShaderMask 自己的区域上，也就是这个滚动视口，
              // 所以它固定在屏幕上，滚动时不会跟着歌词一起跑 ——
              // 这正是想要的效果：歌词从上下两端淡入淡出。
              //
              // ShaderMask 不影响命中测试，歌词的点击跳转照常。
              child: ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (Rect bounds) {
                  return LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    // dstIn 只看 alpha，颜色用白色占位即可。
                    colors: const [
                      Colors.transparent,
                      Colors.white,
                      Colors.white,
                      Colors.transparent,
                    ],
                    stops: [0.0, _fadeExtent, 1 - _fadeExtent, 1.0],
                  ).createShader(bounds);
                },
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: EdgeInsets.only(
                    top: viewportHeight * _lineAnchor,
                    bottom: viewportHeight * (1 - _lineAnchor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (int i = 0; i < lyricList.length; i++)
                        KeyedSubtree(
                          key: _lineKeys[i],
                          // 用行索引判断当前行：同一时间戳可能有多行歌词，
                          // 用 time 比较会同时点亮多行。
                          //
                          // 点击跳转交给 _LyricLine（那里包在 Text 外面）：
                          // 包在这一层会把整行、包括文字右侧的空白都变成点击区域，
                          // 因为 ListTile 内部无条件套了一层 InkWell，
                          // 而 InkWell 的 GestureDetector 用的是 HitTestBehavior.opaque。
                          child: _LyricLine(
                            lyric: lyricList[i].lyric,
                            isCurrent: i == currentIndex,
                            onTap: () {
                              // 点击歌词文字跳转播放进度
                              _management.playMusicControl.changeProgress(
                                lyricList[i].time,
                              );
                              print('点击歌词行跳转播放进度: ${lyricList[i].time}');
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// 单行歌词。独立出来是为了让每行的样式互不影响，
/// 后续要接逐字高亮也只改这里。
class _LyricLine extends StatelessWidget {
  const _LyricLine({required this.lyric, required this.isCurrent, this.onTap});

  /// 字号 / 颜色过渡时长，与列表居中滚动的动画（_DisplayLyricState._scrollDuration）
  /// 保持同一档，切行时滚动和文字放大看起来是一个动作。
  static const Duration _styleDuration = Duration(milliseconds: 300);

  final List<String> lyric;
  final bool isCurrent;

  /// 点击这一行文字时的回调（点击跳转进度）。为 null 时不可点。
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // 用 TweenAnimationBuilder 把旧的 TextStyle 和新的做 lerp，
    // 字号和颜色就是渐变过去的，而不是切行瞬间硬切。
    //
    // 样式仍然交给 Text（而不是用 AnimatedDefaultTextStyle 包一层），
    // 因为 ListTile 会给标题套一层 AnimatedDefaultTextStyle（bodyLarge，
    // 含 height: 1.5），外面再包一层会把它整个替换掉、行高跟着变。
    // 交给 Text 则会正常合并，渲染结果和改动前一致。
    return ListTile(
      // ListTile 在 M3 下默认 contentPadding 是 start:16 / end:24，
      // 会把每行歌词相对歌名、歌手往里推 16px。
      // 这里清零，歌词的左边缘才和歌名、歌手落在同一条竖线上
      // （垂直方向的 minVerticalPadding 不受影响，行高照旧）。
      contentPadding: EdgeInsets.zero,
      title: Align(
        alignment: Alignment.centerLeft,
        // 这一层 Align 是"只有文字能点"的关键：
        // ListTile 给标题的是紧宽度约束（list_tile.dart 里的
        // textConstraints = looseConstraints.tighten(width: ...)），
        // 直接往标题里放文本，它的盒子会被撑满整行宽，点右侧空白也会命中。
        // Align 把约束放松给子级，子级按文字实际宽度收缩，
        // 于是下面的 GestureDetector 只覆盖文字本身。
        child: GestureDetector(
          onTap: onTap,
          child: TweenAnimationBuilder<TextStyle>(
            duration: _styleDuration,
            curve: Curves.easeOutCubic,
            // 只给 end：begin 为空时 TweenAnimationBuilder 会从当前值起步，
            // 首帧不会有多余动画，动画中途被打断也能接着当前值继续。
            tween: TextStyleTween(
              end: TextStyle(
                fontSize: isCurrent ? 30 : 25,
                color: isCurrent
                    ? AppColors.lyricPlayColor
                    : AppColors.lyricColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            builder: (BuildContext context, TextStyle style, Widget? child) {
              return Text(
                lyric.join('\n'),
                textAlign: TextAlign.left,
                style: style,
              );
            },
          ),
        ),
      ),
    );
  }
}

/// 去掉滚动条滚动的行为：只覆写 buildScrollbar，其余（滚动物理、拖拽设备等）
/// 全部沿用 MaterialScrollBehavior。
///
/// 桌面端的 MaterialScrollBehavior.buildScrollbar 在垂直方向会返回
/// `Scrollbar(controller: details.controller, child: child)`，
/// 这里直接返回 child，等于这个子树里不构建任何滚动条。
class _NoScrollbarBehavior extends MaterialScrollBehavior {
  const _NoScrollbarBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}
