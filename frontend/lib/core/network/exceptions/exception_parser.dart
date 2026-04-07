import 'package:dio/dio.dart';

/// Extracts a human-readable error message from a DioException response body.
///
/// Checks for Map responses with 'detail', 'message', or 'error' keys,
/// falls back to string response data, then to [fallback].
String extractErrorMessage(DioException error, String fallback) {
  final data = error.response?.data;
  if (data is Map) {
    return data['detail']?.toString() ??
        data['message']?.toString() ??
        data['error']?.toString() ??
        fallback;
  }
  if (data is String && data.isNotEmpty) {
    return data;
  }
  return fallback;
}
