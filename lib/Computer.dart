import 'package:flutter/material.dart';
import 'package:chocolate_music/components/ComputerNavBar.dart';
import 'package:chocolate_music/components/TopToolBar.dart';
import 'package:chocolate_music/components/PlaybackControlBar.dart';
import 'package:chocolate_music/pages/computer/MainView.dart';
import 'package:chocolate_music/pages/computer/LyricsPage.dart';
import 'package:chocolate_music/theme/app_colors.dart';
import 'package:chocolate_music/Management.dart';
import 'package:chocolate_music/components/LyricsTransition.dart';
import 'package:chocolate_music/components/PlaybackListPanel.dart';

class ComputerHomePage extends StatefulWidget {
  const ComputerHomePage({super.key});

  @override
  State<ComputerHomePage> createState() => _ComputerHomePageState();
}

class _ComputerHomePageState extends State<ComputerHomePage> {
  // String selectedPage = 'RecommendPage';

  // void _onNavDestinationSelected(String newSelectedPage) {
  //   // 定义一个回调函数
  //   setState(() {
  //     selectedPage = newSelectedPage; // 更新状态
  //   });
  // }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Management(),
      builder: (BuildContext context, Widget? child) {
        return Scaffold(
          backgroundColor: AppColors.background,
          // 播放列表侧边栏铺在最外层，直接贴窗口边缘，
          // 不受下面 Container 那圈 10px 内边距影响。
          body: PlaybackListPanelHost(
            visible: Management().playlistShow,
            onDismiss: () => Management().playlistShow = false,
            child: LyricsTransitionHost(
              visible: Management().lyricShow,
              coverUrl: Management().setting.cover,
              page: LyricsPage(),
              child: Container(
                color: AppColors.background,
                padding: EdgeInsets.all(10), // 和边框的间距
                child: Stack(
                  children: [
                    Row(
                      children: [
                        ChocolateNavBar(
                          // selectedPage: selectedPage,
                          // onDestinationSelected:
                          //     _onNavDestinationSelected, // 传递回调函数给导航栏
                        ),
                        SizedBox(width: 10), //
                        Expanded(
                          child: Column(
                            children: [
                              TopToolBar(),
                              SizedBox(height: 10),
                              // Expanded(child: MainView(selectedPage: selectedPage)),
                              Expanded(child: MainView()),
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
            ),
          ),
        );
      },
    );
  }
}
