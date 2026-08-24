import 'package:flutter/material.dart';
import 'package:bootstrap_icons/bootstrap_icons.dart';
import 'package:chocolate_music/theme/app_colors.dart';
import 'package:chocolate_music/Management.dart';
import 'package:chocolate_music/components/RemoteImage.dart';

class PlaybackControlBar extends StatefulWidget {
  final Management management = Management();

  @override
  State<PlaybackControlBar> createState() => _PlaybackControlBarState();
}

class _PlaybackControlBarState extends State<PlaybackControlBar> {
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
                PlaybackControlButton(),
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
                      },
                      child: widget.management.account.type != '' && widget.management.cloud.collectionList.contains(
                          widget.management.setting.id)
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

class MusicData extends StatelessWidget {
  final management = Management();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12), // 根据需要设置圆角大小
          child: RemoteImage(
            // widget.cover,
            management.setting.cover,
            headers: const {
              'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/131.0.0.0 Safari/537.36',
            },
            width: 70,
            height: 70,
            fit: BoxFit.cover,
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

        SizedBox(width: 10),

        Container(
          width: 80,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center, // 垂直居中
            crossAxisAlignment: CrossAxisAlignment.start, // 左对齐
            children: [
              Text(
                management.setting.name,
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

class PlaybackControlButton extends StatefulWidget {
  @override
  _PlaybackControlButtonState createState() => _PlaybackControlButtonState();
}

class _PlaybackControlButtonState extends State<PlaybackControlButton> {
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
          },
          // child: Icon(BootstrapIcons.pause_circle_fill, color: Colors.black, size: 35,), // 播放图标
          child: Icon(
            BootstrapIcons.play_circle_fill,
            color: Colors.black,
            size: 35,
          ), // 播放图标
        ),

        SizedBox(width: 10), // 图标之间的间距

        GestureDetector(
          onTap: () {
            // TODO: 实现下一首功能
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
            // TODO: 实现下一首功能
          },
          child: Icon(
            BootstrapIcons.music_note_list,
            color: Colors.black,
            size: 25,
          ), // 下一首图标
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
  late double timerValue = 0;
  late String displayTime = '00:00';
  final management = Management();

  // 将秒数（或毫秒）转换为 mm:ss 格式的字符串
  // 默认情况下，传入的 value 被视为秒数。如果你的值是毫秒，请先除以 1000 再传入，
  // 或者调用 _formatTimeFromMilliseconds(value).
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.center, // 垂直居中
      crossAxisAlignment: CrossAxisAlignment.center, // 水平居中
      children: [
        Text(
          displayTime,
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
              value: timerValue, // 当前播放进度，范围 0.0 到 1.0
              min: 0.0,
              max: 253000,
              onChanged: (value) {
                setState(() {
                  timerValue = value;
                  displayTime = _formatTime(value / 1000);
                });
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
            management.setting.volumeType = !management.setting.volumeType;
            management.updateSetting();
            setState(() {});
          },
          child: Icon(
            !management.setting.volumeType || management.setting.volume == 0
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
              value: !management.setting.volumeType
                  ? 0
                  : management.setting.volume, // 当前音量，范围 0.0 到 1.0
              min: 0,
              max: 100,
              onChanged: (value) {
                setState(() {
                  management.setting.volume = value;
                  if (value == 0) {
                    management.setting.volumeType = false;
                  } else {
                    management.setting.volumeType = true;
                  }
                });
                // 音量拖动过程中只刷新界面，避免每个滑块事件都触发磁盘写入。
                management.refresh();

                print('音量调整到: $value'); // TODO: 实现音量调整功能
              },
            ),
          ),
        ),
      ],
    );
  }
}
