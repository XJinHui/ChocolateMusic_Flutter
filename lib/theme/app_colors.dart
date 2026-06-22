import 'package:flutter/material.dart';

/// 应用颜色集中管理。
/// 在应用中使用 AppColors.* 以便于统一管理。
class AppColors {
  AppColors._(); // 禁止实例化

  // 主 Scaffold 背景色
  static const Color background = Color(0xFFFFFFFF);

  // 通用面板 / 卡片背景色
  static const Color panel = Color(0xFFF0F0F0);

  // 透明色
  static const Color transparent = Color(0x00000000);

  // 主题色
  static const Color primary = Color(0xff000000);

  // 选中状态背景颜色
  // static const Color selected = Color(0xFFD8D8D8);
  static const Color selected = Color(0xFFDCECFB);

  // 选中状态文字颜色
  // static const Color selectedText = Color(0xFF000000);
  static const Color selectedText = Color(0xFF0673DA);

  // 普通状态文字颜色
  static const Color normalText = Color(0xFF000000);

  // 悬浮状态颜色
  static const Color floating = Color(0xFFE6E6E6);

  // 应用名颜色
  static const Color appName = Color(0xff505050);

  // 按钮图标颜色
  static const Color buttonIcon = Color(0xff505050);

  // 关闭按钮颜色
  static const Color closeIcon = Color(0xffffffff);

  // 关闭按钮悬浮颜色
  static const Color closeIconHover = Color(0xffff5f57);

  // 音乐名称颜色
  static const Color musicNameColor = Color(0xff333333);

  // 歌手名称颜色
  static const Color musicSingerColor = Color(0xff999999);

  // 音乐时间颜色
  static const Color musicTimeColor = Color(0xff333333);

  // 音乐进度条颜色
  static const Color musicProgressColor = Color(0xff95cffd);

  // 收藏按钮颜色
  static const Color likeIconColor = Color(0xffff5f57);
}

