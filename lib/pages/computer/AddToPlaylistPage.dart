import 'package:flutter/material.dart';

import 'package:chocolate_music/theme/app_colors.dart';

/// 「添加音乐」小窗中的页面内容。
///
/// 这里只有页面骨架，核心内容（搜索、本地导入、歌单选择等）尚未实现，
/// 后续在 [_content] 里填充即可。
/// 小窗外壳（居中弹窗 + 关闭按钮）见 `lib/components/AddMusicDialog.dart`。
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
            '添加音乐',
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
      child: Container(
        alignment: Alignment.center,
        constraints: const BoxConstraints(maxWidth: 320),
        decoration: BoxDecoration(
          color: AppColors.panel,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Text(
          '添加音乐内容待实现',
          style: TextStyle(color: AppColors.buttonIcon, fontSize: 14),
        ),
      ),
    );
  }
}