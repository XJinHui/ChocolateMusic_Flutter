import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// 桌面端默认的 [MaterialScrollBehavior] 有两条限制，会让横向列表彻底滚不动：
///
/// 1. [ScrollBehavior.dragDevices] 的默认值只有 touch / stylus / trackpad 等，
///    **不含 [PointerDeviceKind.mouse]**，所以鼠标按住拖动不会驱动任何滚动；
/// 2. [MaterialScrollBehavior.buildScrollbar] 遇到横向滚动视图直接返回 child，
///    只有纵向才会自动挂上 [Scrollbar]，横向连滑块都没得拖。
///
/// 两条叠加后，横向列表既拖不动、也没有滚动条，滚轮又只读 scrollDelta.dy
/// 而被丢弃。这里把 mouse 加回拖拽设备集合，一次修好所有滚动区域。
///
/// 不会和点击冲突：拖拽手势要超过 kTouchSlop 才会在手势竞技场中胜出，
/// 普通点击、右键菜单、TextField 的文本选择都不受影响。
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => <PointerDeviceKind>{
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.stylus,
    PointerDeviceKind.invertedStylus,
    PointerDeviceKind.trackpad,
    // VoiceAccess 在滚动时会产生 unknown 类型的指针事件，保留默认集合里的这一项。
    PointerDeviceKind.unknown,
  };
}