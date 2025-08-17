import 'package:api_app/network/retry/retry_config.dart';

import '../errors/error_severity.dart';

class ContextualRetryManager {
  static RetryConfig getRetryConfig(RequestContext context) {
    return switch (context) {
      RequestContext.userInitiated => RetryConfig.aggressive,
      RequestContext.background => RetryConfig.conservative,
      RequestContext.critical => const RetryConfig(
        maxAttempts: 5,
        initialDelay: Duration(milliseconds: 100),
        maxDelay: Duration(seconds: 30),
      ),
      RequestContext.optional => const RetryConfig(
        maxAttempts: 1,
        initialDelay: Duration(seconds: 1),
      ),
    };
  }

  // Smart retry decision based on error type and context
  static bool shouldRetryError(NetworkError error, RequestContext context) {
    return switch ((error, context)) {
    // Never retry auth errors
      (AuthenticationError(), _) => false,

    // Always retry connection issues for critical requests
      (NoConnectionError(), RequestContext.critical) => true,

    // Don't retry timeouts for background requests
      (TimeoutError(), RequestContext.background) => false,

    // Retry server errors unless it's a client error (4xx)
      (ServerError(statusCode: final code), _) => code >= 500,

    // Default to error's recommendation
      (_, _) => error.recommendedStrategy == RecoveryStrategy.retry,
    };
  }
}

enum RequestContext {
  userInitiated,    // User tapped refresh button
  background,       // Auto-refresh or background sync
  critical,         // Essential data for app function
  optional,         // Nice-to-have data
}
