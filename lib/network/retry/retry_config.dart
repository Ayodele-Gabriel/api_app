import 'dart:math' as math;

import '../errors/error_detector.dart';
import '../errors/error_severity.dart';

class RetryConfig {
  final int maxAttempts;
  final Duration initialDelay;
  final Duration maxDelay;
  final double backoffMultiplier;
  final double jitter;
  final bool enableJitter;

  const RetryConfig({
    this.maxAttempts = 3,
    this.initialDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(minutes: 5),
    this.backoffMultiplier = 2.0,
    this.jitter = 0.1,
    this.enableJitter = true,
  });

  // Predefined configurations for different scenarios
  static const conservative = RetryConfig(
    maxAttempts: 2,
    initialDelay: Duration(seconds: 2),
    backoffMultiplier: 1.5,
  );

  static const aggressive = RetryConfig(
    maxAttempts: 5,
    initialDelay: Duration(milliseconds: 500),
    backoffMultiplier: 2.5,
  );

  static const userTriggered = RetryConfig(
    maxAttempts: 1,
    initialDelay: Duration.zero,
  );
}

// Modern retry system with smart decision making
class SmartRetrySystem {
  static Future<T> executeWithRetry<T>(
      Future<T> Function() operation, {
        RetryConfig config = const RetryConfig(),
        bool Function(NetworkError error)? shouldRetry,
        void Function(int attempt, NetworkError error, Duration delay)? onRetry,
      }) async {
    int attempt = 0;
    Duration currentDelay = config.initialDelay;

    while (true) {
      attempt++;

      try {
        final result = await operation();

        // Success - log if this was a retry
        if (attempt > 1) {
          print('✅ Operation succeeded on attempt $attempt');
        }

        return result;

      } catch (error) {
        final networkError = ModernErrorDetector.analyzeError(error);

        // Check if we should give up
        if (attempt >= config.maxAttempts) {
          print('❌ Operation failed after $attempt attempts');
          throw NetworkRetryExhaustedException(
            'Failed after $attempt attempts',
            lastError: networkError,
            totalAttempts: attempt,
          );
        }

        // Check if this error type is retryable
        final isRetryable = shouldRetry?.call(networkError) ??
            _isRetryableError(networkError);

        if (!isRetryable) {
          print('🚫 Error is not retryable: ${networkError.userMessage}');
          rethrow;
        }

        // Calculate delay with jitter and backoff
        final delayWithBackoff = Duration(
          milliseconds: math.min(
            currentDelay.inMilliseconds,
            config.maxDelay.inMilliseconds,
          ),
        );

        final finalDelay = config.enableJitter
            ? _addJitter(delayWithBackoff, config.jitter)
            : delayWithBackoff;

        print('🔄 Attempt $attempt failed, retrying in ${finalDelay.inSeconds}s...');
        print('   Error: ${networkError.userMessage}');

        // Notify callback
        onRetry?.call(attempt, networkError, finalDelay);

        // Wait before retry
        await Future.delayed(finalDelay);

        // Increase delay for next attempt
        currentDelay = Duration(
          milliseconds: (currentDelay.inMilliseconds * config.backoffMultiplier).round(),
        );
      }
    }
  }

  static bool _isRetryableError(NetworkError error) {
    return switch (error.recommendedStrategy) {
      RecoveryStrategy.retry => true,
      RecoveryStrategy.cache => false, // Handle with cache instead
      RecoveryStrategy.manual => false, // Requires user intervention
      RecoveryStrategy.abort => false, // Don't retry
    };
  }

  static Duration _addJitter(Duration delay, double jitterFactor) {
    final jitterMs = (delay.inMilliseconds * jitterFactor *
        (math.Random().nextDouble() * 2 - 1)).round();
    return Duration(
      milliseconds: math.max(0, delay.inMilliseconds + jitterMs),
    );
  }
}

class NetworkRetryExhaustedException implements Exception {
  final String message;
  final NetworkError lastError;
  final int totalAttempts;

  const NetworkRetryExhaustedException(
      this.message, {
        required this.lastError,
        required this.totalAttempts,
      });

  @override
  String toString() => 'NetworkRetryExhaustedException: $message';
}
