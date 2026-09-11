import 'package:flutter/material.dart';
import 'package:chocolate_music/theme/app_colors.dart';

import 'package:chocolate_music/Management.dart';
import 'package:chocolate_music/pages/computer/RecommendPage.dart';
import 'package:chocolate_music/pages/computer/PlaylistPage.dart';
import 'package:chocolate_music/pages/computer/AccountPage.dart';
import 'package:chocolate_music/pages/computer/SettingsPage.dart';

// 计算机页面

class MainView extends StatefulWidget {
  // final String selectedPage;
  final Management management = Management();

  // const MainView({Key? key, required this.selectedPage}) : super(key: key);
  // const MainView({Key? key}) : super(key: key);

  @override
  State<MainView> createState() => _MainViewState();
}

class _MainViewState extends State<MainView> {

  Widget _buildPage() {
    switch (widget.management.selectedPage) {
      case 'RecommendPage':
        return RecommendPage();
      case 'LikedPage':
        return PlaylistPage();
      case 'PlaylistPage':
        return PlaylistPage();
      case 'AccountPage':
        return AccountPage();
      case 'SettingsPage':
        return SettingsPage();
      default:
        return Text(widget.management.selectedPage);
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
      child: Column(children: [Expanded(child: _buildPage())]),
    );
  }
}
