import 'package:flutter/material.dart';

import 'package:chocolate_music/theme/app_colors.dart';

class DownloadPage extends StatefulWidget {
  const DownloadPage({super.key});

  @override
  State<DownloadPage> createState() => _DownloadPageState();
}

class _DownloadPageState extends State<DownloadPage> {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            '下载管理',
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
        decoration: BoxDecoration(
          color: AppColors.panel,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Text(
          '下载内容待实现',
          style: TextStyle(color: AppColors.buttonIcon, fontSize: 14),
        ),
      ),
    );
  }
}