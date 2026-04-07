import 'package:dio/dio.dart';
import 'package:personal_ai_assistant/core/network/exceptions/exception_parser.dart';

/// Categorizes network/HTTP errors for consistent UI localization.
///
/// Each code maps to a localized message in the UI layer (see
/// `AsyncValueWidget._friendlyErrorMessage`). This avoids hardcoded
/// English strings in the exception layer.
enum NetworkErrorCode {
  connectionTimeout,
  sendTimeout,
  receiveTimeout,
  noConnection,
  serverError,
  authExpired,
  accessDenied,
  notFound,
  conflict,
  validation,
  unknown,
}

abstract class AppException implements Exception {

  const AppException(this.message, {this.statusCode, this.errorCode});
  final String message;
  final int? statusCode;
  final NetworkErrorCode? errorCode;

  @override
  String toString() => message;
}

class NetworkException extends AppException {
  const NetworkException(super.message, {super.errorCode});

  static NetworkException fromDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
        return const NetworkException(
          'Connection timeout',
          errorCode: NetworkErrorCode.connectionTimeout,
        );
      case DioExceptionType.sendTimeout:
        return const NetworkException(
          'Request timeout',
          errorCode: NetworkErrorCode.sendTimeout,
        );
      case DioExceptionType.receiveTimeout:
        return const NetworkException(
          'Response timeout',
          errorCode: NetworkErrorCode.receiveTimeout,
        );
      case DioExceptionType.connectionError:
        return const NetworkException(
          'No internet connection',
          errorCode: NetworkErrorCode.noConnection,
        );
      case DioExceptionType.badResponse:
        final message = extractErrorMessage(error, 'Server error');

        return NetworkException(message);
      default:
        return NetworkException(
          error.message ?? 'Network error occurred',
        );
    }
  }
}

class ServerException extends AppException {
  const ServerException(super.message, {super.statusCode});

  static ServerException fromDioError(DioException error) {
    final statusCode = error.response?.statusCode;
    final message = extractErrorMessage(error, 'Server error');

    return ServerException(message, statusCode: statusCode);
  }
}

class AuthenticationException extends AppException {
  const AuthenticationException(super.message)
      : super(statusCode: 401, errorCode: NetworkErrorCode.authExpired);

  static AuthenticationException fromDioError(DioException error) {
    final backendMessage = extractErrorMessage(error, '');

    // Map known backend messages to user-friendly text
    if (backendMessage.contains('Could not validate credentials') ||
        backendMessage.contains('Invalid credentials') ||
        backendMessage.contains('Token has expired') ||
        backendMessage.contains('Invalid token')) {
      return const AuthenticationException('Session expired. Please login again.');
    }

    return AuthenticationException(
      backendMessage.isNotEmpty ? backendMessage : 'Authentication failed',
    );
  }
}

class AuthorizationException extends AppException {
  const AuthorizationException(super.message)
      : super(statusCode: 403, errorCode: NetworkErrorCode.accessDenied);

  static AuthorizationException fromDioError(DioException error) {
    final message = extractErrorMessage(error, 'Access denied');

    return AuthorizationException(message);
  }
}

class NotFoundException extends AppException {
  const NotFoundException(super.message)
      : super(statusCode: 404, errorCode: NetworkErrorCode.notFound);

  static NotFoundException fromDioError(DioException error) {
    final message = extractErrorMessage(error, 'Resource not found');

    return NotFoundException(message);
  }
}

class ConflictException extends AppException {
  const ConflictException(super.message)
      : super(statusCode: 409, errorCode: NetworkErrorCode.conflict);

  static ConflictException fromDioError(DioException error) {
    final message = extractErrorMessage(error, 'Resource conflict');

    return ConflictException(message);
  }
}

class ValidationException extends AppException {

  const ValidationException(super.message, {this.fieldErrors})
      : super(statusCode: 422, errorCode: NetworkErrorCode.validation);
  final Map<String, dynamic>? fieldErrors;

  static ValidationException fromDioError(DioException error) {
    final data = error.response?.data;
    final message = extractErrorMessage(error, 'Validation failed');

    // Parse field errors from the errors array
    final fieldErrors = <String, String>{};
    if (data is Map && data['errors'] != null && data['errors'] is List) {
      final errors = data['errors'] as List;
      for (final error in errors) {
        if (error is! Map) continue;

        // Extract field name (remove "body -> " prefix)
        var field = error['field']?.toString() ?? '';
        if (field.startsWith('body -> ')) {
          field = field.substring(7);
        }

        // Clean up the message (remove "Value error, " prefix)
        var errorMsg = error['message']?.toString() ?? '';
        if (errorMsg.startsWith('Value error, ')) {
          errorMsg = errorMsg.substring(13);
        }

        fieldErrors[field] = errorMsg;
      }
    }

    return ValidationException(message, fieldErrors: fieldErrors);
  }

  // Getter for compatibility with existing code
  Map<String, dynamic>? get details => fieldErrors;
}

class UnknownException extends AppException {
  const UnknownException(super.message);
}
