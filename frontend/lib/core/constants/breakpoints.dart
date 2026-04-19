import 'package:flutter/material.dart';

/// 替代flutter_adaptive_scaffold的Breakpoints类
class Breakpoints {
  const Breakpoints._();

  /// 小屏幕断点
  static const double small = 0;

  /// 中等屏幕断点
  static const double medium = 600;

  /// 窄手机断点
  static const double mini = 420;

  /// 紧凑平板断点
  static const double compact = 700;

  /// 中大屏幕断点
  static const double mediumLarge = 840;

  /// 宽布局断点
  static const double wideLayout = 1040;

  /// 大屏幕断点
  static const double large = 1200;

  /// 超大屏幕断点
  static const double extraLarge = 1600;

  /// 判断是否为小屏幕（移动设备）
  static bool isSmall(double width) => width < medium;

  /// 判断是否为中等屏幕（平板）
  static bool isMedium(double width) => width >= medium && width < mediumLarge;

  /// 判断是否为中大屏幕（大平板/小桌面）
  static bool isMediumLarge(double width) => width >= mediumLarge && width < large;

  /// 判断是否为大屏幕（桌面）
  static bool isLarge(double width) => width >= large && width < extraLarge;

  /// 判断是否为超大屏幕
  static bool isExtraLarge(double width) => width >= extraLarge;

  /// 判断是否为移动设备（包含小屏幕）
  static bool isMobile(double width) => width < medium;

  /// 判断是否为窄手机屏幕
  static bool isMini(double width) => width < mini;

  /// 判断是否为平板设备（包含中等和中等大屏幕）
  static bool isTablet(double width) => width >= medium && width < large;

  /// 判断是否为桌面设备（包含大和超大屏幕）
  static bool isDesktop(double width) => width >= large;
}

/// 扩展方法，用于通过BuildContext获取断点信息
extension BreakpointsExtension on BuildContext {
  /// 获取当前屏幕宽度
  double get screenWidth => MediaQuery.of(this).size.width;

  /// 获取当前屏幕高度
  double get screenHeight => MediaQuery.of(this).size.height;

  /// 判断是否为小屏幕
  bool get isSmall => Breakpoints.isSmall(screenWidth);

  /// 判断是否为中等屏幕
  bool get isMedium => Breakpoints.isMedium(screenWidth);

  /// 判断是否为中大屏幕
  bool get isMediumLarge => Breakpoints.isMediumLarge(screenWidth);

  /// 判断是否为大屏幕
  bool get isLarge => Breakpoints.isLarge(screenWidth);

  /// 判断是否为超大屏幕
  bool get isExtraLarge => Breakpoints.isExtraLarge(screenWidth);

  /// 判断是否为移动设备
  bool get isMobile => Breakpoints.isMobile(screenWidth);

  /// 判断是否为平板设备
  bool get isTablet => Breakpoints.isTablet(screenWidth);

  /// 判断是否为桌面设备
  bool get isDesktop => Breakpoints.isDesktop(screenWidth);

  /// 判断是否为横屏
  bool get isLandscape => MediaQuery.of(this).orientation == Orientation.landscape;

  /// 判断是否为竖屏
  bool get isPortrait => MediaQuery.of(this).orientation == Orientation.portrait;
}
