import 'package:flutter/material.dart';

/// 应用颜色集中管理。
/// 在应用中使用 AppColors.* 以便于统一管理。
class AppColors {
  AppColors._(); // 禁止实例化

  // 主 Scaffold 背景色
  static const Color background = Color(0xFFFFFFFF);

  // 通用面板 / 卡片背景色
  static const Color panel = Color(0xFFF0F0F0);
  static const Color lyricPgaePanel = Color(0x00000000);

  // 浮层表面色（侧边栏等盖在页面上的面板）。
  // 和 AppColors.background 同为纯白，浮层盖在白色页面上时
  // 靠背后的 AppColors.scrim 暗化层和自身投影分离出来。
  static const Color overlaySurface = Color(0xFFFFFFFF);

  // 浮层背后的暗化遮罩：压暗浮层以外的整片页面，
  // 避免纯白浮层和白色页面糊成一片、看不出边界。
  static const Color scrim = Color(0x4D000000);

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
  static const Color lyricPgaeFloating = Color(0x55F0F0F0);

  // 应用名颜色
  static const Color appName = Color(0xff505050);

  // 按钮图标颜色
  static const Color buttonIcon = Color(0xff505050);

  // 歌词页按钮图标颜色（深色背景上使用）
  static const Color lyricPgaeButtonIcon = Color(0xffffffff);

  // 关闭按钮颜色
  static const Color closeIcon = Color(0xffffffff);

  // 关闭按钮悬浮颜色
  static const Color closeIconHover = Color(0xffff5f57);

  // 账号页服务商舞台色：酷狗天蓝、网易云红、Navidrome 蓝
  static const Color accountStageKuGou = Color(0xFF147FC0);
  static const Color accountStageNetEaseCloud = Color(0xFFC82C36);
  static const Color accountStageNavidrome = Color(0xFF1769AA);
  static const Color accountStageDefault = Color(0xFF26334A);

  // 账号页服务商舞台边缘色
  static const Color accountStageKuGouBorder = Color(0xFF9ADCFD);
  static const Color accountStageNetEaseCloudBorder = Color(0xFFFFB4B9);
  static const Color accountStageNavidromeBorder = Color(0xFF9DCCF2);
  static const Color accountStageDefaultBorder = Color(0xFF71819B);

  // 账号页静态目录表面色
  static const Color accountSurface = Color(0xEFFFFFFF);

  // 账号页冷雾背景与磨砂层
  static const Color accountGlass = Color(0xDEFFFFFF);
  static const Color accountGlassStrong = Color(0xF2FFFFFF);
  static const Color accountGlassHover = Color(0xFFE7F3FF);
  static const Color accountGlassBorder = Color(0xB8FFFFFF);
  static const Color accountGlassOutline = Color(0xFFDAE5F2);
  static const Color accountDivider = Color(0xFFDFE8F2);
  static const Color accountInk = Color(0xFF18243A);
  static const Color accountMutedInk = Color(0xFF63728A);
  static const Color accountDisabledFill = Color(0x9CFFFFFF);
  static const Color accountDisabledInk = Color(0xFF93A0B3);
  static const Color accountSelection = Color(0xD9E8F5FF);
  static const Color accountSelectionBorder = Color(0xFFB8D6F4);
  static const Color accountStageBorder = Color(0xB3FFFFFF);
  static const Color accountRecordGroove = Color(0x140E2340);
  static const Color accountRecordCenter = Color(0xEFFFFFFF);
  static const Color accountShadow = Color(0x1A24324F);

  // 音乐名称颜色
  static const Color musicNameColor = Color(0xff333333);

  // 歌手名称颜色
  static const Color musicSingerColor = Color(0xff666666);

  // 音乐时间颜色
  static const Color musicTimeColor = Color(0xff666666);

  // 音乐进度条颜色
  static const Color musicProgressColor = Color(0xff95cffd);

  // 收藏按钮颜色
  static const Color likeIconColor = Color(0xffff5f57);

  // 歌单名称颜色
  static const Color playlistNameColor = Color(0xff333333);

  // 播放全部按钮颜色
  static const Color playAllButtonColor = Color(0xFF64AFFF);

  // 歌曲数量显示颜色
  static const Color musicQuantityColor = Color(0xff666666);

  // 歌曲索引显示颜色
  static const Color musicIndexColor = Color(0xff666666);

  // 专辑名称颜色
  static const Color albumNameColor = Color(0xff666666);

  // 登录按钮颜色
  static const Color loginButtonColor = Color(0xFFE0E0E0);

  // 圆弧边缘颜色
  static const Color border = Color(0xffeeeeee);

  static const Color lyricColor = Color(0xffcccccc);
  static const Color lyricPlayColor = Color(0xffffffff);
}