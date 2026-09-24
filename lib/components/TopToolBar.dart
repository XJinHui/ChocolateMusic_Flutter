import 'dart:async';
import 'dart:io';

import 'package:chocolate_music/Management.dart';
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
  bool isHovering = false;

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
        const SizedBox(width: 10),
      ],
    );

    // Keep native drag handling away from the action buttons. MoveWindow 内部是
    // GestureDetector(onPanStart: 拖窗口, onDoubleTap: 最大化/还原)，它必须和
    // 设置按钮、窗口按钮保持兄弟关系，不能当它们的祖先：同一次按下会让两个
    // 识别器进入同一个手势竞技场，而 onDoubleTap 会把竞技场 hold 到
    // kDoubleTapTimeout(300ms) 才放行，按钮的 onTap 因此要等 300ms 才触发；
    // 并且鼠标的 hit slop 只有 1px（触摸是 18px），按下时手抖超过 1px 就会被
    // onPanStart 抢走手势，按钮彻底点不动。
    final dragArea = Expanded(
      child: useDesktopWindowChrome
          ? MoveWindow(child: dragContent)
          : dragContent,
    );

    // 设置按钮右侧的 50px 留白同样要能拖动窗口。它和左边那段被设置按钮隔开，
    // 拼不进同一个 MoveWindow（MoveWindow 只能包住连续的一段），所以单独再包
    // 一层。注意别写成裸的 SizedBox(width: 50)：那样高度是 0，命中区域为零，
    // 拖不动。MoveWindow 内部会用 Column + Expanded 把它撑到整行高 30。
    final trailingDragArea = useDesktopWindowChrome
        ? MoveWindow(child: const SizedBox(width: 50))
        : const SizedBox(width: 50);

    final topBar = Container(
      height: 30,
      decoration: BoxDecoration(
        color: AppColors.transparent,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          dragArea,
          _buildSettingsButton(),
          trailingDragArea,
          OperationButton(),
        ],
      ),
    );

    if (useDesktopWindowChrome) {
      return WindowTitleBarBox(child: topBar);
    }

    return topBar;
  }

  /// 设置按钮。调用方必须把它放在 MoveWindow 之外，理由见 [build] 里的注释。
  Widget _buildSettingsButton() {
    return GestureDetector(
      onTap: () {
        // 处理点击设置按钮事件
        Management().selectedPage = 'SettingsPage';
      },
      child: MouseRegion(
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
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: isHovering ? AppColors.floating : AppColors.panel,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(
            BootstrapIcons.gear,
            size: 20,
            color: AppColors.buttonIcon,
          ),
        ),
      ),
    );
  }
}

class ToolbarSearchBar extends StatefulWidget {
  const ToolbarSearchBar({super.key});

  @override
  State<ToolbarSearchBar> createState() => _ToolbarSearchBarState();
}

class _ToolbarSearchBarState extends State<ToolbarSearchBar> {
  // 持有输入框文本，供点击搜索图标时读取
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose(); // 释放控制器资源
    super.dispose();
  }

  // 统一的搜索提交入口：回车与点击图标共用同一套逻辑
  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      return; // 空关键词不发起搜索
    }
    Management().search(value);
    Management().selectedPage = 'SearchPage';
    print('搜索提交: $value');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(15),
      ),
      child: TextField(
        controller: _controller,
        cursorHeight: 18,
        // 关键：光标高度，比字号略大即可
        cursorWidth: 1.5,
        // 可选：细一点更精致
        decoration: InputDecoration(
          hintText: '搜索',
          border: InputBorder.none,
          prefixIcon: GestureDetector(
            onTap: _submit, // 点击搜索图标触发搜索
            behavior: HitTestBehavior.opaque, // 图标周围空白区域同样可点击
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(BootstrapIcons.search),
            ),
          ),
          // prefixIcon 默认最小 48x48，会顶开高 30 的标题栏，这里显式收窄
          prefixIconConstraints: const BoxConstraints(
            minWidth: 34,
            minHeight: 30,
          ),
          // border: OutlineInputBorder(), // 边框样式
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 5),
        ),
        onChanged: (value) {
          // 处理搜索输入变化
          // print('搜索输入: $value');
        },
        onSubmitted: (value) {
          // 处理搜索提交事件（回车）
          _submit();
        },
      ),
    );
  }
}
