import 'package:flutter/material.dart';
import 'package:personal_ai_assistant/core/platform/platform_helper.dart';

PreferredSizeWidget adaptiveAppBar(
  BuildContext context, {
  String? title,
  Widget? titleWidget,
  List<Widget>? actions,
  Widget? leading,
  bool? centerTitle,
  Color? backgroundColor,
}) {
  final isIOS = PlatformHelper.isIOS(context);
  return AppBar(
    title: titleWidget ?? (title != null ? Text(title) : null),
    elevation: 0,
    scrolledUnderElevation: isIOS ? 0.1 : 0,
    centerTitle: centerTitle ?? isIOS,
    backgroundColor: backgroundColor ?? Colors.transparent,
    surfaceTintColor: Colors.transparent,
    actions: actions,
    leading: leading,
  );
}
