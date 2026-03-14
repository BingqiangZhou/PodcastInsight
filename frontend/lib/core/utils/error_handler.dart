import 'package:flutter/material.dart';

import '../network/exceptions/network_exceptions.dart';
import '../widgets/top_floating_notice.dart';

/// Centralized error handling utilities.
///
/// Provides consistent error message extraction and display across the app.
class ErrorHandler {
  ErrorHandler._();

  /// Extracts a user-friendly message from an error object.
  ///
  /// Handles the following error types:
  /// - [AppException] and subclasses: uses the message property
  /// - [Exception]: uses toString()
  /// - Other objects: uses toString()
  static String extractMessage(Object error, [String? fallbackMessage]) {
    if (error is AppException) {
      return error.message;
    }
    final message = error.toString();
    // Remove common prefixes like "Exception: " if present
    if (message.startsWith('Exception: ')) {
      return message.substring(11);
    }
    return message.isNotEmpty ? message : (fallbackMessage ?? 'An error occurred');
  }

  /// Shows an error notice to the user.
  ///
  /// This is a convenience method that combines [extractMessage] with
  /// [showTopFloatingNotice] for the common error display pattern.
  ///
  /// Example:
  /// ```dart
  /// try {
  ///   await someOperation();
  /// } catch (error) {
  ///   if (mounted) {
  ///     ErrorHandler.showError(context, error);
  ///   }
  /// }
  /// ```
  static void showError(
    BuildContext context,
    Object error, {
    String? fallbackMessage,
    Duration duration = const Duration(seconds: 3),
    double extraTopOffset = 0,
  }) {
    final message = extractMessage(error, fallbackMessage);
    showTopFloatingNotice(
      context,
      message: message,
      isError: true,
      duration: duration,
      extraTopOffset: extraTopOffset,
    );
  }

  /// Shows a success notice to the user.
  ///
  /// Convenience wrapper around [showTopFloatingNotice] for success messages.
  static void showSuccess(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 3),
    double extraTopOffset = 0,
  }) {
    showTopFloatingNotice(
      context,
      message: message,
      isError: false,
      duration: duration,
      extraTopOffset: extraTopOffset,
    );
  }
}
