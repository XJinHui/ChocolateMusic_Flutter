import 'package:flutter/material.dart';
import 'package:chocolate_music/theme/app_colors.dart';

import 'package:chocolate_music/pages/computer/RecommendPage.dart';

// 计算机页面

class MainView extends StatefulWidget {
  final String selectedIndex;

  const MainView({Key? key, required this.selectedIndex}) : super(key: key);

  @override
  State<MainView> createState() => _MainViewState();
}

class _MainViewState extends State<MainView> {
  Widget _buildPage() {
    switch (widget.selectedIndex) {
      case 'RecommendPage':
        return RecommendPage();
      default:
        return Text(widget.selectedIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      // color: Color(0xffffffdd),
        decoration: BoxDecoration(
        color: AppColors.transparent,
        borderRadius: BorderRadius.circular(15), // 圆角
      ),
      child: Column(
        children: [
          Expanded(child: _buildPage(),)
        ],
      ),
    );
  }
}
