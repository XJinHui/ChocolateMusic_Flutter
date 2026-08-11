import 'dart:io';

import 'package:flutter/material.dart';
import 'package:chocolate_music/theme/app_colors.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';

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
          const OperationButton(),
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
          prefixIcon: Icon(Icons.search),
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

class OperationButton extends StatefulWidget {
  const OperationButton({super.key});

  @override
  State<OperationButton> createState() => _OperationButtonState();
}

class _OperationButtonState extends State<OperationButton> {
  final double size = 30;
  final double iconSize = 18;
  final List<IconData> iconList = const [
    Icons.remove,
    Icons.crop_square,
    Icons.close,
  ];

  Future<void> _toggleMaximize() async {
    // bitsdojo_window exposes maximize/restore operations on appWindow.
    if (appWindow.isMaximized) {
      appWindow.restore();
    } else {
      appWindow.maximize();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      decoration: BoxDecoration(
        color: AppColors.transparent,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () async {
              if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
                appWindow.minimize();
              }
            },
            child: WindowActionButton(
              icon: iconList[0],
              floatingIconColor: AppColors.buttonIcon,
              floatingColor: AppColors.floating,
              size: iconSize,
              width: size,
              height: size,
              radius: size / 2,
            ),
          ),

          const SizedBox(width: 5),

          GestureDetector(
            onTap: () async {
              if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
                await _toggleMaximize();
              }
            },
            child: WindowActionButton(
              icon: iconList[1],
              floatingIconColor: AppColors.buttonIcon,
              floatingColor: AppColors.floating,
              size: iconSize,
              width: size,
              height: size,
              radius: size / 2,
            ),
          ),

          const SizedBox(width: 5),

          GestureDetector(
            onTap: () async {
              if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
                appWindow.close();
              }
            },
            child: WindowActionButton(
              icon: iconList[2],
              floatingIconColor: AppColors.closeIcon,
              floatingColor: AppColors.closeIconHover,
              size: iconSize,
              width: size,
              height: size,
              radius: size / 2,
            ),
          ),
        ],
      ),
    );
  }
}

class WindowActionButton extends StatefulWidget {
  final IconData icon;
  final Color floatingIconColor;
  final Color floatingColor;
  final double size;
  final double width;
  final double height;
  final double radius;

  const WindowActionButton({
    super.key,
    required this.icon,
    required this.floatingIconColor,
    required this.floatingColor,
    required this.size,
    required this.width,
    required this.height,
    required this.radius,
  });

  @override
  State<WindowActionButton> createState() => _WindowActionButtonState();
}

class _WindowActionButtonState extends State<WindowActionButton> {
  bool isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        setState(() {
          isHovering = true;
        });
      },
      onExit: (_) {
        setState(() {
          isHovering = false;
        });
      },
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: isHovering ? widget.floatingColor : AppColors.panel,
          borderRadius: BorderRadius.circular(widget.radius),
        ),
        child: Icon(
          widget.icon,
          size: widget.size,
          color: isHovering ? widget.floatingIconColor : AppColors.buttonIcon,
        ),
      ),
    );
  }
}
