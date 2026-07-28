import 'dart:math';

/// Sanitized error categories for queue items.
class SanitizedErrorCategory {
  static const String networkTimeout = 'NETWORK_TIMEOUT';
  static const String serverUnavailable = 'SERVER_UNAVAILABLE';
  static const String connectionFailed = 'CONNECTION_FAILED';
  static const String dnsResolutionFailed = 'DNS_FAILED';
  static const String blockedByDependency = 'BLOCKED_BY_DEPENDENCY';
  static const String protocolError = 'PROTOCOL_ERROR';
  static const String unknownError = 'UNKNOWN_ERROR';
}

/// Pure policy calculating bounded exponential backoff with jitter and sanitized messages.
class SyncRetryPolicy {
  const SyncRetryPolicy({
    this.initialDelay = const Duration(seconds: 5),
    this.maxDelay = const Duration(seconds: 300),
    this.multiplier = 2.0,
    this.jitterFactor = 0.2,
    this.random,
  });

  final Duration initialDelay;
  final Duration maxDelay;
  final double multiplier;
  final double jitterFactor;
  final Random? random;

  /// Calculates the next retry timestamp from [lastAttemptAt] and [retryCount].
  DateTime calculateNextRetryAt({
    required DateTime lastAttemptAt,
    required int retryCount,
    Random? customRandom,
  }) {
    if (retryCount <= 0) {
      return lastAttemptAt.add(initialDelay);
    }

    final calculatedSeconds =
        initialDelay.inSeconds * pow(multiplier, retryCount - 1);
    final cappedSeconds = min(maxDelay.inSeconds.toDouble(), calculatedSeconds);

    // Apply jitter (± jitterFactor)
    final rng = customRandom ?? random ?? Random();
    final jitterRange = cappedSeconds * jitterFactor;
    final jitterOffset = (rng.nextDouble() * 2 - 1) * jitterRange;

    final finalSeconds = max(
      1.0,
      min(maxDelay.inSeconds.toDouble(), cappedSeconds + jitterOffset),
    );

    return lastAttemptAt.add(
      Duration(milliseconds: (finalSeconds * 1000).round()),
    );
  }

  /// Categorizes an exception into a sanitized, safe error code.
  static String categorizeError(dynamic error) {
    if (error == null) return SanitizedErrorCategory.unknownError;
    final str = error.toString().toLowerCase();

    if (str.contains('timeout') || str.contains('deadline')) {
      return SanitizedErrorCategory.networkTimeout;
    }
    if (str.contains('connection refused') ||
        str.contains('socketexception') ||
        str.contains('network is unreachable')) {
      return SanitizedErrorCategory.connectionFailed;
    }
    if (str.contains('nodename nor servname provided') ||
        str.contains('host not found') ||
        str.contains('dns')) {
      return SanitizedErrorCategory.dnsResolutionFailed;
    }
    if (str.contains('502') || str.contains('503') || str.contains('504')) {
      return SanitizedErrorCategory.serverUnavailable;
    }
    return SanitizedErrorCategory.unknownError;
  }

  /// Sanitizes an error message by stripping potential PII, URLs, or access tokens.
  static String sanitizeErrorMessage(String? rawMessage, String category) {
    if (rawMessage == null || rawMessage.trim().isEmpty) {
      return _defaultCategoryDescription(category);
    }

    // Strip tokens, authorization headers, bearer patterns, and full URLs
    var sanitized = rawMessage
        .replaceAll(
          RegExp(r'Bearer\s+[A-Za-z0-9\-\._~\+\/]+=*', caseSensitive: false),
          'Bearer [REDACTED]',
        )
        .replaceAll(
          RegExp(r'https?://[^\s]+', caseSensitive: false),
          '[SERVER_ENDPOINT]',
        )
        .replaceAll(
          RegExp(r'token=[^\s&]+', caseSensitive: false),
          'token=[REDACTED]',
        );

    // Truncate to safe maximum length
    if (sanitized.length > 200) {
      sanitized = '${sanitized.substring(0, 197)}...';
    }

    return sanitized;
  }

  static String _defaultCategoryDescription(String category) {
    switch (category) {
      case SanitizedErrorCategory.networkTimeout:
        return 'Network connection timed out';
      case SanitizedErrorCategory.serverUnavailable:
        return 'Server is temporarily unavailable';
      case SanitizedErrorCategory.connectionFailed:
        return 'Could not connect to the backend server';
      case SanitizedErrorCategory.dnsResolutionFailed:
        return 'Server domain name resolution failed';
      case SanitizedErrorCategory.blockedByDependency:
        return 'Waiting for parent dependency to synchronize';
      case SanitizedErrorCategory.protocolError:
        return 'Unexpected backend protocol response';
      default:
        return 'Synchronization retryable error occurred';
    }
  }
}
