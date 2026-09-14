import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:chocolate_music/theme/app_colors.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:bootstrap_icons/bootstrap_icons.dart';
import 'package:chocolate_music/Management.dart';

class OperationButton extends StatefulWidget {
  const OperationButton({super.key, this.lyricMode});

  /// 歌词页退出期间仍使用深色页面样式，直到淡出结束。
  final bool? lyricMode;

  @override
  State<OperationButton> createState() => _OperationButtonState();
}

class _OperationButtonState extends State<OperationButton> {
  static const double _buttonSize = 30;
  // Bootstrap 图标以 16 为设计网格，按整数 16 渲染可以让描边落在设计宽度上，
  // 避免 15px 时 0.94px 的次像素描边导致图标发虚、粗细不均。
  static const double _iconSize = 14;
  static const Duration _windowStatePollInterval = Duration(milliseconds: 500);

  bool _isMaximized = false;
  Timer? _windowStateTimer;

  bool get _isTestEnvironment =>
      Platform.environment.containsKey('FLUTTER_TEST');

  bool get _isDesktopPlatform =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  @override
  void initState() {
    super.initState();
    if (_isDesktopPlatform && !_isTestEnvironment) {
      _isMaximized = appWindow.isMaximized;
      // bitsdojo_window 没有窗口状态变化回调（系统级最大化、双击标题栏等），
      // 用轻量轮询保持“还原/最大化”图标与实际窗口状态同步。
      _windowStateTimer = Timer.periodic(
        _windowStatePollInterval,
            (_) => _syncMaximizeState(),
      );
    }
  }

  @override
  void dispose() {
    _windowStateTimer?.cancel();
    super.dispose();
  }

  void _syncMaximizeState() {
    if (!mounted) return;
    final bool maximized = appWindow.isMaximized;
    if (maximized != _isMaximized) {
      setState(() => _isMaximized = maximized);
    }
  }

  void _toggleMaximize() {
    if (appWindow.isMaximized) {
      appWindow.restore();
    } else {
      appWindow.maximize();
    }
    // bitsdojo 的最大化/还原是同步原生调用，立即刷新一次图标。
    _syncMaximizeState();
  }

  void _minimize() {
    if (_isDesktopPlatform) appWindow.minimize();
  }

  void _maximizeOrRestore() {
    if (_isDesktopPlatform) _toggleMaximize();
  }

  void _close() {
    if (_isDesktopPlatform) appWindow.close();
  }

  IconData get _maximizeIcon =>
      _isMaximized ? BootstrapIcons.copy : BootstrapIcons.square;

  @override
  Widget build(BuildContext context) {
    // 悬停/静止两种背景色与图标色都在这里一次性判定后传入，
    // WindowActionButton 不直接读 Management()，保证各状态的颜色来源一致。
    final bool lyricMode = widget.lyricMode ?? Management().lyricShow;
    final Color restingColor =
        lyricMode ? AppColors.lyricPgaePanel : AppColors.panel;
    final Color hoverColor =
        lyricMode ? AppColors.lyricPgaeFloating : AppColors.floating;
    // 歌词页深色背景上静止图标用白色；悬停时按钮底色变亮，图标翻回黑色保持对比。
    final Color restingIconColor =
        lyricMode ? AppColors.lyricPgaeButtonIcon : AppColors.buttonIcon;
    return Container(
      height: _buttonSize,
      decoration: BoxDecoration(
        color: AppColors.transparent,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          _buildWindowButton(
            icon: BootstrapIcons.dash_lg,
            restingColor: restingColor,
            hoverColor: hoverColor,
            restingIconColor: restingIconColor,
            hoverIconColor: restingIconColor,
            onTap: _minimize,
          ),
          const SizedBox(width: 5),
          _buildWindowButton(
            icon: _maximizeIcon,
            restingColor: restingColor,
            hoverColor: hoverColor,
            restingIconColor: restingIconColor,
            hoverIconColor: restingIconColor,
            onTap: _maximizeOrRestore,
            quarterTurns: 2,
          ),
          const SizedBox(width: 5),
          _buildWindowButton(
            icon: BootstrapIcons.x_lg,
            restingColor: restingColor,
            hoverColor: AppColors.closeIconHover,
            restingIconColor: restingIconColor,
            hoverIconColor: AppColors.closeIcon,
            onTap: _close,
          ),
        ],
      ),
    );
  }

  Widget _buildWindowButton({
    required IconData icon,
    required Color restingColor,
    required Color hoverColor,
    required Color restingIconColor,
    required VoidCallback onTap,
    Color hoverIconColor = AppColors.buttonIcon,
    int quarterTurns = 0,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: WindowActionButton(
        icon: icon,
        restingColor: restingColor,
        restingIconColor: restingIconColor,
        floatingIconColor: hoverIconColor,
        floatingColor: hoverColor,
        iconSize: _iconSize,
        width: _buttonSize,
        height: _buttonSize,
        radius: _buttonSize / 2,
        quarterTurns: quarterTurns,
      ),
    );
  }
}

class WindowActionButton extends StatefulWidget {
  final IconData icon;
  final Color restingColor;
  final Color restingIconColor;
  final Color floatingIconColor;
  final Color floatingColor;
  final double iconSize;
  final double width;
  final double height;
  final double radius;
  // 图标旋转量，取值为 90° 的倍数（quarterTurns: 2 即 180°）。
  final int quarterTurns;

  const WindowActionButton({
    super.key,
    required this.icon,
    required this.restingColor,
    required this.restingIconColor,
    required this.floatingIconColor,
    required this.floatingColor,
    required this.iconSize,
    required this.width,
    required this.height,
    required this.radius,
    this.quarterTurns = 0,
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
          color: isHovering ? widget.floatingColor : widget.restingColor,
          borderRadius: BorderRadius.circular(widget.radius),
        ),
        child: RotatedBox(
          quarterTurns: widget.quarterTurns,
          child: Icon(
            widget.icon,
            size: widget.iconSize,
            color: isHovering
                ? widget.floatingIconColor
                : widget.restingIconColor,
          ),
        ),
      ),
    );
  }
}
