import 'package:flutter/material.dart';
import 'package:chocolate_music/components/ComputerNavBar.dart';
import 'package:chocolate_music/components/TopToolBar.dart';
import 'package:chocolate_music/components/PlaybackControlBar.dart';
import 'package:chocolate_music/pages/computer/MainView.dart';
import 'package:chocolate_music/theme/app_colors.dart';

class ComputerHomePage extends StatefulWidget {
  const ComputerHomePage({super.key});

  @override
  State<ComputerHomePage> createState() => _ComputerHomePageState();
}

class _ComputerHomePageState extends State<ComputerHomePage> {
  String selectedIndex = 'RecommendPage';

  void _onNavDestinationSelected(String newSelectedIndex) {
    // 定义一个回调函数
    setState(() {
      selectedIndex = newSelectedIndex; // 更新状态
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        color: AppColors.background,
        padding: EdgeInsets.all(10), // 和边框的间距
        child: Stack(
          children: [
            Row(
              children: [
                ChocolateNavBar(
                  selectedIndex: selectedIndex, // 传递当前选中项
                  onDestinationSelected:
                      _onNavDestinationSelected, // 传递回调函数给导航栏
                ),
                SizedBox(width: 10), //
                Expanded(
                  child: Column(
                    children: [
                      TopToolBar(),
                      SizedBox(height: 10),
                      Expanded(child: MainView(selectedIndex: selectedIndex)),
                      SizedBox(height: 10),
                      PlaybackControlBar(),

                      // Expanded(
                      //   child: Stack(
                      //     children: [
                      //       Expanded(
                      //         child: MainView(selectedIndex: selectedIndex),
                      //       ),
                      //       Column(
                      //         children: [
                      //           Expanded(child: Container()), // 占位，推到最底部
                      //           PlaybackControlBar(),
                      //           SizedBox(height: 10,)
                      //         ],
                      //       ),
                      //     ],
                      //   ),
                      // ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
