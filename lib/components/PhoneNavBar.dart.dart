import 'package:flutter/material.dart';
import 'package:chocolate_music/theme/app_colors.dart';

class ChocolateNavBar extends StatefulWidget {
  @override
  State<ChocolateNavBar> createState() => _ChocolateNavBarState();
}

class _ChocolateNavBarState extends State<ChocolateNavBar> {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: TabBar(
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        splashFactory: NoSplash.splashFactory,

        labelColor: AppColors.primary, // 选中颜色（按你的主题改）
        unselectedLabelColor: Colors.grey, // 未选中颜色

        dividerColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        tabs: const [
          Tab(icon: Icon(Icons.home), text: '首页'),
          Tab(icon: Icon(Icons.person), text: '我的'),
        ],
      ),
    );
  }
}
