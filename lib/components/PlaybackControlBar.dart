import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bootstrap_icons/bootstrap_icons.dart';
import 'package:chocolate_music/theme/app_colors.dart';
import 'package:chocolate_music/Management.dart';
import 'package:chocolate_music/components/RemoteImage.dart';
import 'package:chocolate_music/components/MusicComponents.dart';
import 'package:chocolate_music/components/LyricsTransition.dart';

class PlaybackControlBar extends StatefulWidget {
  final Management management = Management();

  @override
  State<PlaybackControlBar> createState() => _PlaybackControlBarState();
}

class _PlaybackControlBarState extends State<PlaybackControlBar> {
  @override
  void initState() {
    super.initState();
    FocusManager.instance.addEarlyKeyEventHandler(_handlePlaybackKey);
  }

  KeyEventResult _handlePlaybackKey(KeyEvent event) {
    final keyboard = HardwareKeyboard.instance;
    if (event.logicalKey != LogicalKeyboardKey.space ||
        keyboard.isControlPressed ||
        keyboard.isAltPressed ||
        keyboard.isMetaPressed ||
        keyboard.isShiftPressed) {
      return KeyEventResult.ignored;
    }

    // 窗口收到空格时优先处理，不依赖播放栏或输入框的焦点。
    // 忽略长按重复事件和窗口切换时补发的按键事件。
    if (event is KeyDownEvent && !event.synthesized) {
      widget.management.playMusicControl.pausePlayMusic();
    }
    return KeyEventResult.handled;
  }

  @override
  void dispose() {
    FocusManager.instance.removeEarlyKeyEventHandler(_handlePlaybackKey);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 90,
      padding: EdgeInsets.only(bottom: 10, top: 10, left: 15, right: 15),
      // 和边框的间距
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(15), // 圆角
      ),
      // color: Color(0xffffddff),
      child: Row(
        children: [
          MusicData(),

          SizedBox(width: 20),

          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center, // 垂直居中
              crossAxisAlignment: CrossAxisAlignment.center, // 水平居中
              children: [
                PlayControlButton(),
                SizedBox(height: 5),
                PlaybackProgressBar(),
              ],
            ),
          ),

          SizedBox(width: 20),

          Column(
            children: [
              SizedBox(height: 45),

              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      // 处理喜欢按钮点击事件
                      Management().like(Management().setting.id).then((
                        bool success,
                      ) {
                        // 更新收藏状态
                        final isCollected =
                            Management().cloud.collectionList.contains(
                              Management().setting.id,
                            ) ??
                            false;
                        if (success) {
                          showMusicToast(
                            context,
                            message:
                                '歌曲 《${Management().setting.name}》 ${isCollected ? '收藏' : '取消收藏'}成功',
                          );
                        } else {
                          showMusicToast(
                            context,
                            message:
                                '歌曲 《${Management().setting.name}》 ${isCollected ? '取消收藏' : '收藏'}失败',
                            success: false,
                          );
                        }
                      });
                    },
                    child:
                        widget.management.account.type != '' &&
                            widget.management.cloud.collectionList.contains(
                              widget.management.setting.id,
                            )
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

                  SizedBox(width: 15),

                  VolumeControl(volume: 100),
                ],
              ),
            ],
          ),

          SizedBox(width: 10),
        ],
      ),
    );
  }
}

class MusicData extends StatefulWidget {
  @override
  State<MusicData> createState() => _MusicDataState();
}

class _MusicDataState extends State<MusicData> {
  final management = Management();

  // 封面是否被按住：按住缩小，松开弹回（与歌词页封面同款点击动画）
  bool _coverPressed = false;

  static const Duration _pressDuration = Duration(milliseconds: 120);
  static const Duration _releaseDuration = Duration(milliseconds: 200);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTapDown: (_) => setState(() => _coverPressed = true),
          onTapCancel: () => setState(() => _coverPressed = false),
          onTapUp: (_) {
            // 从实际按压尺寸衔接退出，不再等待回弹或留下延迟任务。
            setState(() => _coverPressed = false);
            Management().lyricShow = true;
            print('打开歌词页');
          },
          child: AnimatedScale(
            scale: _coverPressed ? 0.95 : 1.0,
            duration: _coverPressed ? _pressDuration : _releaseDuration,
            curve: _coverPressed ? Curves.easeOut : Curves.easeOutBack,
            child: LyricsCoverAnchor(
              child: RemoteImage(
                management.setting.cover,
                headers: const {
                  'User-Agent':
                      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/131.0.0.0 Safari/537.36',
                },
                width: 70,
                height: 70,
                fit: BoxFit.cover,
                borderRadius: 12,
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
                // 加载失败时，errorBuilder 会被调用
                errorBuilder: (context, error, stackTrace) {
                  // 返回你的本地图片
                  return Image.asset(
                    'assets/images/app_photo.png',
                    width: 70,
                    height: 70,
                    fit: BoxFit.cover,
                  );
                },
              ),
            ),
          ),
        ),

        SizedBox(width: 10),

        Container(
          width: 80,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center, // 垂直居中
            crossAxisAlignment: CrossAxisAlignment.start, // 左对齐
            children: [
              Text(
                management.setting.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.left,
                style: TextStyle(
                  fontSize: 18,
                  color: AppColors.musicNameColor,
                  fontWeight: FontWeight.bold,
                ),
              ),

              SizedBox(height: 5),

              Text(
                management.setting.singer,
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
      ],
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
        GestureDetector(
          onTap: () {
            management.updatePlayType();
            management.updatePlayType();
          },
          child: Icon(
            sequence[management.setting.playType],
            color: Colors.black,
            size: 25,
          ), // TODO: 根据当前播放模式显示不同的图标
        ),

        SizedBox(width: 10), // 图标之间的间距

        GestureDetector(
          onTap: () {
            // TODO: 实现上一首功能
            management.playMusicControl.lastMusic();
            print('上一首');
          },
          child: Icon(
            BootstrapIcons.skip_start_fill,
            color: Colors.black,
            size: 35,
          ), // 上一首图标
        ),

        SizedBox(width: 10), // 图标之间的间距

        GestureDetector(
          onTap: () {
            // TODO: 实现播放/暂停功能
            management.playMusicControl.pausePlayMusic();
            // print('播放/暂停');
          },
          // child: Icon(BootstrapIcons.pause_circle_fill, color: Colors.black, size: 35,), // 播放图标
          child: Icon(
            management.setting.play
                ? BootstrapIcons.pause_circle_fill
                : BootstrapIcons.play_circle_fill,
            color: Colors.black,
            size: 35,
          ), // 播放图标a
        ),

        SizedBox(width: 10), // 图标之间的间距

        GestureDetector(
          onTap: () {
            // TODO: 实现下一首功能
            management.playMusicControl.nextMusic();
            print('下一首');
          },
          child: Icon(
            BootstrapIcons.skip_end_fill,
            color: Colors.black,
            size: 35,
          ), // 下一首图标
        ),

        SizedBox(width: 10), // 图标之间的间距

        GestureDetector(
          onTap: () {
            // TODO: 实现查看播放列表功能
            management.playlistShow = !management.playlistShow;
          },
          child: Icon(
            BootstrapIcons.music_note_list,
            color: Colors.black,
            size: 25,
          ), // 查看播放列表图标
        ),
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

        return Row(
          mainAxisAlignment: MainAxisAlignment.center, // 垂直居中
          crossAxisAlignment: CrossAxisAlignment.center, // 水平居中
          children: [
            Text(
              _formatTime(sliderValue),
              style: TextStyle(color: AppColors.musicTimeColor),
            ), // 当前时间
            SizedBox(width: 10), // 时间和进度条之间的间距

            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  // 通过 trackHeight 控制滑轨高度
                  trackHeight: 4.0,
                  // 调整拇指（圆点）半径
                  thumbShape: RoundSliderThumbShape(enabledThumbRadius: 2.0),
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
            ),

            SizedBox(width: 10), // 时间和进度条之间的间距
            Text(
              management.setting.time,
              style: TextStyle(color: AppColors.musicTimeColor),
            ), // 总时间
          ],
        );
      },
    );
  }
}

class VolumeControl extends StatefulWidget {
  final double volume; // 音量，范围 0 到 100
  const VolumeControl({Key? key, required this.volume}) : super(key: key);

  @override
  State<VolumeControl> createState() => _VolumeControlState();
}

class _VolumeControlState extends State<VolumeControl> {
  final management = Management();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: () {
            // TODO: 实现静音/取消静音功能
            this.management.setting.volumeType =
                !this.management.setting.volumeType;
            this.management.updateSetting();
            this.management.playMusicControl.updateVolume(
              this.management.setting.volume.toInt(),
            );
            setState(() {});
          },
          child: Icon(
            !this.management.setting.volumeType ||
                    this.management.setting.volume == 0
                ? BootstrapIcons.volume_mute_fill
                : BootstrapIcons.volume_up_fill,
            color: Colors.black,
            size: 25,
          ), // 音量图标
        ),

        SizedBox(width: 10), // 图标和滑动条之间的间距

        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4.0,
            thumbShape: RoundSliderThumbShape(enabledThumbRadius: 2.0),
            overlayShape: RoundSliderOverlayShape(overlayRadius: 0.0),
            activeTrackColor: AppColors.musicProgressColor,
            inactiveTrackColor: Colors.grey.shade300,
            thumbColor: AppColors.musicProgressColor,
          ),
          child: SizedBox(
            width: 100, // 设置滑动条的宽度
            child: Slider(
              value: !this.management.setting.volumeType
                  ? 0
                  : this.management.setting.volume, // 当前音量，范围 0.0 到 1.0
              min: 0,
              max: 100,
              onChanged: (value) {
                setState(() {
                  this.management.setting.volume = value;
                  if (value == 0) {
                    this.management.setting.volumeType = false;
                  } else {
                    this.management.setting.volumeType = true;
                  }
                  this.management.updateSetting();
                  this.management.playMusicControl.updateVolume(value.toInt());
                });
                // 音量拖动过程中只刷新界面，避免每个滑块事件都触发磁盘写入。
                this.management.refresh();

                print('音量调整到: $value'); // TODO: 实现音量调整功能
              },
            ),
          ),
        ),
      ],
    );
  }
}
