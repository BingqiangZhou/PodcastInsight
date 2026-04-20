import 'package:dio/dio.dart';
import 'package:personal_ai_assistant/core/network/exceptions/exception_parser.dart';

abstract class AppException implements Exception {
  const AppException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;

  /// Human-readable error message for UI display.
  String get userMessage {
    final trimmed = message.trim();
    if (trimmed.isNotEmpty) return trimmed;
    return 'An unexpected error occurred. Please try again.';
  }
}

class NetworkException extends AppException {
  const NetworkException(super.message);

  static NetworkException fromDioError(DioException error) {
    return switch (error.type) {
      DioExceptionType.connectionTimeout =>
        const NetworkException('Connection timeout'),
      DioExceptionType.sendTimeout =>
        const NetworkException('Request timeout'),
      DioExceptionType.receiveTimeout =>
        const NetworkException('Response timeout'),
      DioExceptionType.connectionError =>
        const NetworkException('No internet connection'),
      _ => NetworkException(error.message ?? 'Network error occurred'),
    };
  }
}

class AuthException extends AppException {
  const AuthException(super.message, {super.statusCode});

  static AuthException fromDioError(DioException error) {
    final backendMessage = extractErrorMessage(error, '');
    if (backendMessage.contains('Could not validate credentials') ||
        backendMessage.contains('Invalid credentials') ||
        backendMessage.contains('Token has expired') ||
        backendMessage.contains('Invalid token')) {
      return const AuthException('Session expired. Please login again.', statusCode: 401);
    }
    return AuthException(
      backendMessage.isNotEmpty ? backendMessage : 'Authentication failed',
      statusCode: error.response?.statusCode,
    );
  }
}

class ServerException extends AppException {
  const ServerException(super.message, {super.statusCode, this.fieldErrors});
  final Map<String, dynamic>? fieldErrors;

  /// Convenience getter for compatibility
  Map<String, dynamic>? get details => fieldErrors;

  static ServerException fromDioError(DioException error) {
    final statusCode = error.response?.statusCode;
    final message = extractErrorMessage(error, 'Server error');
    final fieldErrors = _parseFieldErrors(error);
    return ServerException(message, statusCode: statusCode, fieldErrors: fieldErrors);
  }

  static Map<String, String>? _parseFieldErrors(DioException error) {
    final data = error.response?.data;
    if (data is! Map || data['errors'] is! List) return null;
    final fieldErrors = <String, String>{};
    for (final e in (data['errors'] as List)) {
      if (e is! Map) continue;
      var field = e['field']?.toString() ?? '';
      if (field.startsWith('body -> ')) field = field.substring(7);
      var msg = e['message']?.toString() ?? '';
      if (msg.startsWith('Value error, ')) msg = msg.substring(13);
      fieldErrors[field] = msg;
    }
    return fieldErrors.isEmpty ? null : fieldErrors;
  }
}

class UnknownException extends AppException {
  const UnknownException(super.message);
}
