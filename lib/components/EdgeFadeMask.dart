import 'package:flutter/material.dart';

/// 通用列表渐隐组件。
///
/// 包在任意可滚动组件（ListView、GridView、CustomScrollView、
/// SingleChildScrollView 等）外层，内容滚出上/下边缘时平滑淡出，
/// 而不是被生硬裁切；某一方向不可滚动（内容不足一屏或已滚到底）时，
/// 该侧不渐隐。
///
/// ```dart
/// EdgeFadeMask(
///   child: ListView.builder(...),
/// )
/// ```
class EdgeFadeMask extends StatefulWidget {
  const EdgeFadeMask({
    Key? key,
    required this.child,
    this.fadeExtent = 24.0,
    this.topFade = true,
    this.bottomFade = true,
  }) : super(key: key);

  /// 需要渐隐的可滚动组件
  final Widget child;

  /// 单侧渐隐区域的像素高度
  final double fadeExtent;

  /// 顶部是否允许渐隐。
  /// 列表最上方有固定不动（pinned）的标题栏等内容时设为 false，
  /// 否则固定标题栏本身会被渐隐遮罩盖住。
  final bool topFade;

  /// 底部是否允许渐隐
  final bool bottomFade;

  @override
  State<EdgeFadeMask> createState() => _EdgeFadeMaskState();
}

class _EdgeFadeMaskState extends State<EdgeFadeMask> {
  // 当前能否向上/向下滚动，用于决定渐隐遮罩显示在哪一侧
  bool _canScrollUp = false;
  bool _canScrollDown = false;

  void _updateScrollState(ScrollMetrics metrics) {
    final bool canScrollUp = metrics.pixels > metrics.minScrollExtent + 1;
    final bool canScrollDown = metrics.pixels < metrics.maxScrollExtent - 1;
    if (canScrollUp == _canScrollUp && canScrollDown == _canScrollDown) {
      return;
    }
    setState(() {
      _canScrollUp = canScrollUp;
      _canScrollDown = canScrollDown;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (Rect bounds) {
        final double height = bounds.height;
        if (height <= 0) {
          return const LinearGradient(
            colors: [Colors.white, Colors.white],
          ).createShader(bounds);
        }
        final double t = (widget.fadeExtent / height).clamp(0.0, 0.5);
        final bool showTop = widget.topFade && _canScrollUp;
        final bool showBottom = widget.bottomFade && _canScrollDown;
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            showTop ? Colors.transparent : Colors.white,
            Colors.white,
            Colors.white,
            showBottom ? Colors.transparent : Colors.white,
          ],
          stops: [0.0, t, 1 - t, 1.0],
        ).createShader(bounds);
      },
      child: NotificationListener<ScrollMetricsNotification>(
        // 内容高度变化（列表增减、窗口缩放）时同步滚动状态
        onNotification: (ScrollMetricsNotification notification) {
          _updateScrollState(notification.metrics);
          return false;
        },
        child: NotificationListener<ScrollNotification>(
          // 滚动过程中同步滚动状态
          onNotification: (ScrollNotification notification) {
            _updateScrollState(notification.metrics);
            return false;
          },
          child: widget.child,
        ),
      ),
    );
  }
}
