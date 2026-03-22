import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// A wrapper widget that provides scroll-to-top functionality for its child content.
///
/// This widget wraps any content in a SingleChildScrollView and exposes
/// a scrollToTop() method that can be called via a GlobalKey.
class ScrollableContentWrapper extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const ScrollableContentWrapper({
    super.key,
    required this.child,
    this.padding,
  });

  @override
  State<ScrollableContentWrapper> createState() => ScrollableContentWrapperState();
}

class ScrollableContentWrapperState extends State<ScrollableContentWrapper>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();

  /// Scroll to the top of the content
  void scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RepaintBoundary(
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: widget.padding,
        physics: _getScrollPhysics(),
        child: widget.child,
      ),
    );
  }

  ScrollPhysics _getScrollPhysics() {
    if (kIsWeb) {
      return const ClampingScrollPhysics();
    }
    switch (Theme.of(context).platform) {
      case TargetPlatform.android:
        return const BouncingScrollPhysics();
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return const BouncingScrollPhysics();
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return const ClampingScrollPhysics();
    }
  }
}
