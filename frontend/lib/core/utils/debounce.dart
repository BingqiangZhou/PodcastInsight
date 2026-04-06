import 'dart:async';
import 'dart:ui';

/// 防抖定时器工具类
///
/// 用于延迟执行函数，避免频繁触发
class DebounceTimer {

  /// 创建防抖定时器
  ///
  /// Parameters:
  /// - [duration] 延迟时间
  /// - [callback] 延迟后执行的回调函数
  DebounceTimer(Duration duration, VoidCallback callback) {
    _timer = Timer(duration, callback);
  }
  Timer? _timer;

  /// 取消定时器
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  /// 是否已激活
  bool get isActive => _timer?.isActive ?? false;

  /// 释放资源
  void dispose() {
    cancel();
  }
}
