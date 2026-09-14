import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:chocolate_music/theme/app_colors.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:bootstrap_icons/bootstrap_icons.dart';
import 'package:chocolate_music/components/OperationButton.dart';


class TopToolBar extends StatefulWidget {
  const TopToolBar({super.key});

  @override
  State<TopToolBar> createState() => _TopToolBarState();
}

class _TopToolBarState extends State<TopToolBar> {
  bool get _isTestEnvironment =>
      Platform.environment.containsKey('FLUTTER_TEST');

  @override
  Widget build(BuildContext context) {
    final useDesktopWindowChrome =
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS) &&
        !_isTestEnvironment;

    final dragContent = Row(
      children: [
        const SizedBox(width: 50),
        const Expanded(child: ToolbarSearchBar()),
        const SizedBox(width: 50),
      ],
    );

    // Keep native drag handling away from the action buttons. MoveWindow
    // starts a platform drag on pointer down, which can defer child taps.
    final dragArea = Expanded(
      child: useDesktopWindowChrome
          ? MoveWindow(child: dragContent)
          : dragContent,
    );

    final topBar = Container(
      height: 30,
      decoration: BoxDecoration(
        color: AppColors.transparent,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          dragArea,
          OperationButton(),
        ],
      ),
    );

    if (useDesktopWindowChrome) {
      return WindowTitleBarBox(child: topBar);
    }

    return topBar;
  }
}

class ToolbarSearchBar extends StatefulWidget {
  const ToolbarSearchBar({super.key});

  @override
  State<ToolbarSearchBar> createState() => _ToolbarSearchBarState();
}

class _ToolbarSearchBarState extends State<ToolbarSearchBar> {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(15),
      ),
      child: TextField(
        decoration: InputDecoration(
          hintText: '搜索',
          border: InputBorder.none,
          prefixIcon: Icon(BootstrapIcons.search),
          // border: OutlineInputBorder(), // 边框样式
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 5),
        ),
        onChanged: (value) {
          // 处理搜索输入变化
          print('搜索输入: $value');
        },
      ),
    );
  }
}

