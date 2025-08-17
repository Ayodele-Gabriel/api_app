enum NetworkErrorSeverity { low, medium, high, critical }

enum RecoveryStrategy { retry, cache, manual, abort }

sealed class NetworkError {
  const NetworkError();

  NetworkErrorSeverity get severity;
  RecoveryStrategy get recommendedStrategy;
  Duration get retryDelay;
  int get maxRetries;
  String get userMessage;
  List<String> get recoverySuggestions;
}

// Specific error types with tailored responses
class NoConnectionError extends NetworkError {
  @override
  NetworkErrorSeverity get severity => NetworkErrorSeverity.high;

  @override
  RecoveryStrategy get recommendedStrategy => RecoveryStrategy.cache;

  @override
  Duration get retryDelay => Duration(seconds: 5);

  @override
  int get maxRetries => 3;

  @override
  String get userMessage => '🌐 No internet connection detected';

  @override
  List<String> get recoverySuggestions => [
    'Check your WiFi or mobile data connection',
    'Move to an area with better signal strength',
    'Try again in a few moments',
    'Enable airplane mode, wait 10 seconds, then disable it',
  ];
}

class TimeoutError extends NetworkError {
  final Duration timeoutDuration;

  const TimeoutError(this.timeoutDuration);

  @override
  NetworkErrorSeverity get severity => NetworkErrorSeverity.medium;

  @override
  RecoveryStrategy get recommendedStrategy => RecoveryStrategy.retry;

  @override
  Duration get retryDelay => Duration(seconds: timeoutDuration.inSeconds * 2);

  @override
  int get maxRetries => 5;

  @override
  String get userMessage => '⏰ Request timed out after ${timeoutDuration.inSeconds}s';

  @override
  List<String> get recoverySuggestions => [
    'Your connection might be slow',
    'Try again with a better network connection',
    'The server might be experiencing high load',
  ];
}

class ServerError extends NetworkError {
  final int statusCode;
  final String? serverMessage;

  const ServerError(this.statusCode, {this.serverMessage});

  @override
  NetworkErrorSeverity get severity => switch (statusCode) {
    >= 500 && < 600 => NetworkErrorSeverity.critical,
    == 429 => NetworkErrorSeverity.medium,
    _ => NetworkErrorSeverity.high,
  };

  @override
  RecoveryStrategy get recommendedStrategy => switch (statusCode) {
    429 => RecoveryStrategy.retry, // Rate limited
    >= 500 => RecoveryStrategy.retry, // Server errors
    _ => RecoveryStrategy.manual,
  };

  @override
  Duration get retryDelay => switch (statusCode) {
    429 => Duration(minutes: 1), // Rate limit - wait longer
    502 || 503 => Duration(seconds: 30), // Bad gateway/service unavailable
    _ => Duration(seconds: 10),
  };

  @override
  int get maxRetries => switch (statusCode) {
    429 => 2, // Rate limited
    >= 500 => 4, // Server errors
    _ => 1,
  };

  @override
  String get userMessage => switch (statusCode) {
    429 => '🚦 Too many requests - please wait a moment',
    500 => "🔥 Server error - we're working on it",
    502 => '🔧 Server maintenance - try again shortly',
    503 => '⚠️ Service temporarily unavailable',
    _ => '❌ Server error ($statusCode)',
  };

  @override
  List<String> get recoverySuggestions => switch (statusCode) {
    429 => ['Wait a minute before trying again', "You've made too many requests too quickly"],
    >= 500 => [
      'This is a server problem, not your device',
      'Try again in a few minutes',
      'Check our status page for updates',
    ],
    _ => ['Contact support if this continues', 'Try again later'],
  };
}

class AuthenticationError extends NetworkError {
  @override
  NetworkErrorSeverity get severity => NetworkErrorSeverity.high;

  @override
  RecoveryStrategy get recommendedStrategy => RecoveryStrategy.manual;

  @override
  Duration get retryDelay => Duration.zero;

  @override
  int get maxRetries => 0;

  @override
  String get userMessage => '🔐 Authentication required';

  @override
  List<String> get recoverySuggestions => [
    'Please log in to continue',
    'Your session may have expired',
    'Check your login credentials',
  ];
}

class ParserError extends NetworkError {
  final String details;

  const ParserError(this.details);

  @override
  NetworkErrorSeverity get severity => NetworkErrorSeverity.medium;

  @override
  RecoveryStrategy get recommendedStrategy => RecoveryStrategy.retry;

  @override
  Duration get retryDelay => Duration(seconds: 2);

  @override
  int get maxRetries => 2;

  @override
  String get userMessage => '📄 Invalid data received from server';

  @override
  List<String> get recoverySuggestions => [
    'The server returned unexpected data',
    'Try refreshing to get fresh data',
    'This usually resolves itself quickly',
  ];
}
