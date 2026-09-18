import 'package:flutter/material.dart';
import 'package:bootstrap_icons/bootstrap_icons.dart';

import 'package:chocolate_music/Management.dart';
import 'package:chocolate_music/theme/app_colors.dart';
import 'package:chocolate_music/components/RemoteImage.dart';

class DownloadPage extends StatefulWidget {
  const DownloadPage({super.key});

  @override
  State<DownloadPage> createState() => _DownloadPageState();
}

class _DownloadPageState extends State<DownloadPage> {
  late int downloadQualityTier = Management().setting.downloadQualityTier;

  final qualityTiers = ['标准音质', '高品音质', '无损音质'];

  _downloadMusic() {
    print('下载音乐《${Management().selectedMusic.name}》，选择的音质等级：${qualityTiers[downloadQualityTier]}');
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            '下载歌曲',
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

  /// 核心内容占位区域，后续替换为实际的下载管理界面。
  Widget _content() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Container(
        alignment: Alignment.center,
        constraints: const BoxConstraints(maxWidth: 320),
        child: Column(
          spacing: 10, // 每个子项之间的间距
          children: [
            MusicData(),

            SizedBox(height: 10),

            for (int i = 0; i < qualityTiers.length; i++)
              GestureDetector(
                onTap: () {
                  setState(() {
                    downloadQualityTier = i;
                  });
                },
                child: QualityTierChoose(
                  qualityTier: qualityTiers[i],
                  isSelected: i == downloadQualityTier,
                ),
              ),

            SizedBox(height: 10),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _downloadMusic,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.selectedText,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: const Text(
                  '下载',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
            ),
          ],
        ),
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
        RemoteImage(
          management.selectedMusic.cover,
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

        SizedBox(width: 20),

        Container(
          width: 80,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center, // 垂直居中
            crossAxisAlignment: CrossAxisAlignment.start, // 左对齐
            children: [
              Text(
                management.selectedMusic.name,
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
                management.selectedMusic.singer,
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

class QualityTierChoose extends StatefulWidget {
  final String qualityTier;
  final bool isSelected;

  const QualityTierChoose({
    Key? key,
    required this.qualityTier,
    required this.isSelected,
  }) : super(key: key);

  @override
  State<QualityTierChoose> createState() => _QualityTierChooseState();
}

class _QualityTierChooseState extends State<QualityTierChoose> {
  bool isHovering = false;

  @override
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
        height: 50,
        padding: EdgeInsets.only(left: 15, right: 15),
        decoration: BoxDecoration(
          // 根据 isSelected 的值决定背景颜色
          color: widget.isSelected
              ? AppColors.selected
              : isHovering
              ? AppColors.floating
              : AppColors.transparent,
          borderRadius: BorderRadius.circular(15), // 圆角
        ),
        child: Row(
          children: [
            Text(
              widget.qualityTier,
              style: TextStyle(
                color: widget.isSelected
                    ? AppColors.selectedText
                    : AppColors.normalText,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),

            Expanded(child: SizedBox()),

            if (widget.isSelected)
              Icon(BootstrapIcons.check, color: AppColors.selectedText),
          ],
        ),
      ),
    );
  }
}
