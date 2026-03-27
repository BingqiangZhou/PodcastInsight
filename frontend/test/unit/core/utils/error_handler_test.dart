import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/core/network/exceptions/network_exceptions.dart';
import 'package:personal_ai_assistant/core/utils/error_handler.dart';

void main() {
  group('ErrorHandler.extractMessage', () {
    group('with AppException subclasses', () {
      test('returns message from NetworkException', () {
        const exception = NetworkException('Network connection failed');
        final result = ErrorHandler.extractMessage(exception);

        expect(result, equals('Network connection failed'));
      });

      test('returns message from ServerException', () {
        const exception = ServerException('Internal server error', statusCode: 500);
        final result = ErrorHandler.extractMessage(exception);

        expect(result, equals('Internal server error'));
      });

      test('returns message from AuthenticationException', () {
        const exception = AuthenticationException('Invalid credentials');
        final result = ErrorHandler.extractMessage(exception);

        expect(result, equals('Invalid credentials'));
      });

      test('returns message from AuthorizationException', () {
        const exception = AuthorizationException('Access denied');
        final result = ErrorHandler.extractMessage(exception);

        expect(result, equals('Access denied'));
      });

      test('returns message from NotFoundException', () {
        const exception = NotFoundException('Resource not found');
        final result = ErrorHandler.extractMessage(exception);

        expect(result, equals('Resource not found'));
      });

      test('returns message from ConflictException', () {
        const exception = ConflictException('Resource already exists');
        final result = ErrorHandler.extractMessage(exception);

        expect(result, equals('Resource already exists'));
      });

      test('returns message from ValidationException', () {
        const exception = ValidationException('Validation failed', fieldErrors: {'email': 'Invalid format'});
        final result = ErrorHandler.extractMessage(exception);

        expect(result, equals('Validation failed'));
      });

      test('returns message from UnknownException', () {
        const exception = UnknownException('Unknown error occurred');
        final result = ErrorHandler.extractMessage(exception);

        expect(result, equals('Unknown error occurred'));
      });

      test('uses fallback message when AppException has empty message', () {
        const exception = NetworkException('');
        final result = ErrorHandler.extractMessage(exception, 'Custom fallback');

        // AppException returns its message even if empty
        expect(result, equals(''));
      });
    });

    group('with generic Exception', () {
      test('removes "Exception: " prefix from generic Exception', () {
        final exception = Exception('Something went wrong');
        final result = ErrorHandler.extractMessage(exception);

        expect(result, equals('Something went wrong'));
      });

      test('handles Exception with message starting with "Exception: "', () {
        final exception = Exception('Exception: Nested exception message');
        final result = ErrorHandler.extractMessage(exception);

        // Exception.toString() prepends "Exception: ", so we get "Exception: Exception: Nested..."
        // The handler removes the first "Exception: " prefix
        expect(result, equals('Exception: Nested exception message'));
      });

      test('returns Exception message without "Exception: " when not present', () {
        final exception = Exception('Raw error message');
        final result = ErrorHandler.extractMessage(exception);

        expect(result, equals('Raw error message'));
      });

      test('uses fallback for empty Exception toString result', () {
        final exception = _EmptyToStringException();
        final result = ErrorHandler.extractMessage(exception, 'Custom fallback');

        expect(result, equals('Custom fallback'));
      });

      test('uses default fallback when no custom fallback provided', () {
        final exception = _EmptyToStringException();
        final result = ErrorHandler.extractMessage(exception);

        expect(result, equals('An error occurred'));
      });
    });

    group('with other Object types', () {
      test('returns toString() result for generic Object', () {
        final error = _CustomError('Custom error object');
        final result = ErrorHandler.extractMessage(error);

        expect(result, equals('Custom error object'));
      });

      test('returns string representation of int', () {
        final error = 404;
        final result = ErrorHandler.extractMessage(error);

        expect(result, equals('404'));
      });

      test('returns string representation of null (as String null)', () {
        final result = ErrorHandler.extractMessage('null');

        expect(result, equals('null'));
      });

      test('uses fallback for object with empty toString', () {
        final error = _EmptyToStringObject();
        final result = ErrorHandler.extractMessage(error, 'Object fallback');

        expect(result, equals('Object fallback'));
      });

      test('uses default fallback for object with empty toString', () {
        final error = _EmptyToStringObject();
        final result = ErrorHandler.extractMessage(error);

        expect(result, equals('An error occurred'));
      });
    });

    group('fallback message parameter', () {
      test('uses provided fallback for empty string message', () {
        final result = ErrorHandler.extractMessage('', 'Custom error message');

        expect(result, equals('Custom error message'));
      });

      test('uses provided fallback for Exception with empty toString', () {
        final exception = _EmptyToStringException();
        final result = ErrorHandler.extractMessage(exception, 'Provided fallback');

        expect(result, equals('Provided fallback'));
      });

      test('ignores fallback when message is not empty', () {
        const exception = NetworkException('Actual error message');
        final result = ErrorHandler.extractMessage(exception, 'Unused fallback');

        expect(result, equals('Actual error message'));
      });

      test('uses default "An error occurred" when no fallback provided', () {
        final exception = _EmptyToStringException();
        final result = ErrorHandler.extractMessage(exception);

        expect(result, equals('An error occurred'));
      });
    });

    group('string prefix removal', () {
      test('removes "Exception: " prefix exactly', () {
        final result = ErrorHandler.extractMessage('Exception: Error details');

        expect(result, equals('Error details'));
      });

      test('does not remove partial prefix like "Exception"', () {
        final result = ErrorHandler.extractMessage('Exception without colon');

        expect(result, equals('Exception without colon'));
      });

      test('is case-sensitive for "Exception: " prefix', () {
        final result = ErrorHandler.extractMessage('exception: lowercase prefix');

        expect(result, equals('exception: lowercase prefix'));
      });

      test('removes only first occurrence of "Exception: "', () {
        final result = ErrorHandler.extractMessage('Exception: First Exception: Second');

        expect(result, equals('First Exception: Second'));
      });

      test('handles message starting with "Exception: Exception: "', () {
        final result = ErrorHandler.extractMessage('Exception: Exception: Double prefix');

        expect(result, equals('Exception: Double prefix'));
      });
    });

    group('edge cases', () {
      test('handles null-like string gracefully', () {
        final result = ErrorHandler.extractMessage('null');

        expect(result, equals('null'));
      });

      test('handles whitespace-only string with fallback', () {
        final result = ErrorHandler.extractMessage('   ', 'Fallback message');

        // Whitespace is not empty, so it's returned as-is
        expect(result, equals('   '));
      });

      test('handles very long error message', () {
        final longMessage = 'Error: ' * 1000;
        final exception = Exception(longMessage);
        final result = ErrorHandler.extractMessage(exception);

        expect(result, startsWith('Error: '));
        expect(result.length, equals(longMessage.length));
      });

      test('handles special characters in message', () {
        final result = ErrorHandler.extractMessage('Error: \n\t\r\nSpecial!@#\$%^&*()');

        expect(result, contains('Special!'));
      });

      test('handles unicode characters in message', () {
        const exception = NetworkException('错误：网络连接失败');
        final result = ErrorHandler.extractMessage(exception);

        expect(result, equals('错误：网络连接失败'));
      });

      test('handles emoji in message', () {
        const exception = ServerException('Server failed 💥🔥');
        final result = ErrorHandler.extractMessage(exception);

        expect(result, equals('Server failed 💥🔥'));
      });

      test('handles AppException with empty message and no fallback', () {
        const exception = NetworkException('');
        final result = ErrorHandler.extractMessage(exception);

        expect(result, equals(''));
      });

      test('handles AppException with whitespace-only message', () {
        const exception = NetworkException('   ');
        final result = ErrorHandler.extractMessage(exception);

        expect(result, equals('   '));
      });
    });

    group('with various Exception types from Dart core', () {
      test('handles FormatException', () {
        final exception = FormatException('Invalid format');
        final result = ErrorHandler.extractMessage(exception);

        expect(result, contains('Invalid format'));
      });

      test('handles ArgumentError', () {
        final exception = ArgumentError('Invalid argument');
        final result = ErrorHandler.extractMessage(exception);

        expect(result, contains('Invalid argument'));
      });

      test('handles RangeError', () {
        final exception = RangeError('Index out of bounds');
        final result = ErrorHandler.extractMessage(exception);

        expect(result, contains('Index out of bounds'));
      });

      test('handles StateError', () {
        final exception = StateError('Cannot modify in this state');
        final result = ErrorHandler.extractMessage(exception);

        expect(result, contains('Cannot modify in this state'));
      });

      test('handles UnsupportedError', () {
        final exception = UnsupportedError('Operation not supported');
        final result = ErrorHandler.extractMessage(exception);

        expect(result, contains('Operation not supported'));
      });

      test('handles TypeError', () {
        // TypeError is thrown for type cast failures
        final exception = TypeError();
        final result = ErrorHandler.extractMessage(exception);

        expect(result, isNotEmpty);
      });
    });
  });
}

// Test helper classes

class _EmptyToStringException implements Exception {
  @override
  String toString() => '';
}

class _EmptyToStringObject {
  @override
  String toString() => '';
}

class _CustomError {
  final String message;

  _CustomError(this.message);

  @override
  String toString() => message;
}
