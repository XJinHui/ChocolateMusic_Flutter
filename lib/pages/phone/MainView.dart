import 'package:flutter/material.dart';
import 'package:chocolate_music/theme/app_colors.dart';
import 'package:chocolate_music/components/PhoneNavBar.dart.dart';
import 'package:chocolate_music/pages/phone/MyPage.dart';
import 'package:chocolate_music/pages/phone/RecommendPage.dart';

// 手机页面

class MainView extends StatefulWidget {
  @override
  State<MainView> createState() => _MainViewState();
}

class _MainViewState extends State<MainView> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        // bottomNavigationBar: ChocolateNavBar(),
        body: SafeArea(
          child: TabBarView(
          children: [
            RecommendPage(),
            MyPage(),
          ],
        ),
        ),
      ),
    );
  }
}
