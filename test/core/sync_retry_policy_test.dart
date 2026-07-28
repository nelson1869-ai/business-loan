import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lending_nelson/core/network/sync_retry_policy.dart';

void main() {
  group('SyncRetryPolicy Tests', () {
    const policy = SyncRetryPolicy(
      initialDelay: Duration(seconds: 5),
      maxDelay: Duration(seconds: 300),
      multiplier: 2.0,
      jitterFactor: 0.0, // Disable jitter for deterministic math checks
    );

    final now = DateTime.utc(2026, 7, 28, 12, 0, 0);

    test('initial retry delay starts at 5 seconds', () {
      final nextRetry = policy.calculateNextRetryAt(
        lastAttemptAt: now,
        retryCount: 0,
      );
      expect(nextRetry, now.add(const Duration(seconds: 5)));
    });

    test('exponential backoff grows correctly per retry count', () {
      // Retry 1: 5 * 2^0 = 5s
      final r1 = policy.calculateNextRetryAt(lastAttemptAt: now, retryCount: 1);
      expect(r1, now.add(const Duration(seconds: 5)));

      // Retry 2: 5 * 2^1 = 10s
      final r2 = policy.calculateNextRetryAt(lastAttemptAt: now, retryCount: 2);
      expect(r2, now.add(const Duration(seconds: 10)));

      // Retry 3: 5 * 2^2 = 20s
      final r3 = policy.calculateNextRetryAt(lastAttemptAt: now, retryCount: 3);
      expect(r3, now.add(const Duration(seconds: 20)));

      // Retry 4: 5 * 2^3 = 40s
      final r4 = policy.calculateNextRetryAt(lastAttemptAt: now, retryCount: 4);
      expect(r4, now.add(const Duration(seconds: 40)));
    });

    test('retry delay is bounded by maximum cap of 300 seconds', () {
      final r10 = policy.calculateNextRetryAt(
        lastAttemptAt: now,
        retryCount: 10,
      );
      expect(r10, now.add(const Duration(seconds: 300)));
    });

    test('jitter applies offset within configured jitterFactor range', () {
      const policyWithJitter = SyncRetryPolicy(
        initialDelay: Duration(seconds: 10),
        maxDelay: Duration(seconds: 300),
        multiplier: 2.0,
        jitterFactor: 0.2, // ±20%
      );

      final nextRetry = policyWithJitter.calculateNextRetryAt(
        lastAttemptAt: now,
        retryCount: 2, // base = 20s, jitter range = ±4s => 16s to 24s
        customRandom: Random(42),
      );

      final diffSec = nextRetry.difference(now).inMilliseconds / 1000.0;
      expect(diffSec, greaterThanOrEqualTo(16.0));
      expect(diffSec, lessThanOrEqualTo(24.0));
    });

    test('categorizeError sanitizes network errors safely', () {
      expect(
        SyncRetryPolicy.categorizeError('Connection refused by host'),
        SanitizedErrorCategory.connectionFailed,
      );
      expect(
        SyncRetryPolicy.categorizeError('Receive deadline exceeded'),
        SanitizedErrorCategory.networkTimeout,
      );
      expect(
        SyncRetryPolicy.categorizeError('HTTP 503 Service Unavailable'),
        SanitizedErrorCategory.serverUnavailable,
      );
      expect(
        SyncRetryPolicy.categorizeError('Unknown internal exception'),
        SanitizedErrorCategory.unknownError,
      );
    });

    test('sanitizeErrorMessage strips PII, tokens, and URLs', () {
      const raw =
          'Error posting to https://api.example.com/v1/payments with token=secret123 and Bearer xyz.999! Borrower John Doe';
      final sanitized = SyncRetryPolicy.sanitizeErrorMessage(
        raw,
        SanitizedErrorCategory.connectionFailed,
      );

      expect(sanitized, isNot(contains('https://api.example.com')));
      expect(sanitized, isNot(contains('secret123')));
      expect(sanitized, isNot(contains('xyz.999')));
      expect(sanitized, contains('[SERVER_ENDPOINT]'));
      expect(sanitized, contains('[REDACTED]'));
    });
  });
}
