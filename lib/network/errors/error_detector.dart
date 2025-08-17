import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'error_severity.dart';

class ModernErrorDetector {
  static NetworkError analyzeError(dynamic error, {http.Response? response}) {
    return switch (error) {
    // Network connectivity errors
      SocketException() => NoConnectionError(),

    // Timeout errors with context
      TimeoutException() => TimeoutError(Duration(seconds: 10)),

    // HTTP response errors
      _ when response != null => switch (response.statusCode) {
        401 || 403 => AuthenticationError(),
        429 => ServerError(response.statusCode),
        >= 400 && < 500 => ServerError(
          response.statusCode,
          serverMessage: _extractServerMessage(response),
        ),
        >= 500 => ServerError(
          response.statusCode,
          serverMessage: _extractServerMessage(response),
        ),
        _ => ServerError(response.statusCode),
      },

    // JSON parsing errors
      FormatException(message: final message) => ParserError(message),

    // Unknown errors
      _ => ServerError(0, serverMessage: error.toString()),
    };
  }

  static String? _extractServerMessage(http.Response response) {
    try {
      final json = jsonDecode(response.body);
      return switch (json) {
        {'error': String message} => message,
        {'message': String message} => message,
        {'details': String details} => details,
        _ => null,
      };
    } catch (e) {
      return null;
    }
  }
}
