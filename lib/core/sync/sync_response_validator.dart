/// A validated failure returned by the backend sync endpoint.
class ValidatedSyncFailure {
  const ValidatedSyncFailure({
    required this.transactionUuid,
    required this.code,
    required this.detail,
    required this.retryable,
  });

  final String transactionUuid;
  final String code;
  final String detail;
  final bool retryable;
}

/// Complete, validated accounting of a submitted sync batch.
class ValidatedSyncResponse {
  const ValidatedSyncResponse({
    required this.syncedTransactionUuids,
    required this.failures,
    required this.omittedTransactionUuids,
  });

  final Set<String> syncedTransactionUuids;
  final List<ValidatedSyncFailure> failures;
  final Set<String> omittedTransactionUuids;
}

/// Rejects malformed, duplicate, unknown, and contradictory batch results.
class SyncResponseValidator {
  const SyncResponseValidator();

  ValidatedSyncResponse validate({
    required Object? response,
    required Set<String> submittedTransactionUuids,
  }) {
    if (response is! Map<String, dynamic>) {
      return _protocolFailure(submittedTransactionUuids);
    }
    final syncedRaw = response['syncedTransactionUuids'];
    final failuresRaw = response['failures'];
    if (syncedRaw is! List<dynamic> || failuresRaw is! List<dynamic>) {
      return _protocolFailure(submittedTransactionUuids);
    }

    final synced = <String>{};
    var malformed = false;
    for (final value in syncedRaw) {
      if (value is! String ||
          !submittedTransactionUuids.contains(value) ||
          !synced.add(value)) {
        malformed = true;
      }
    }

    final failures = <ValidatedSyncFailure>[];
    final failedIds = <String>{};
    for (final value in failuresRaw) {
      if (value is! Map<String, dynamic>) {
        malformed = true;
        continue;
      }
      final uuid = value['transactionUuid'];
      final code = value['code'];
      final detail = value['detail'];
      final retryable = value['retryable'];
      if (uuid is! String ||
          code is! String ||
          detail is! String ||
          retryable is! bool ||
          !submittedTransactionUuids.contains(uuid) ||
          !failedIds.add(uuid) ||
          synced.contains(uuid)) {
        malformed = true;
        continue;
      }
      failures.add(
        ValidatedSyncFailure(
          transactionUuid: uuid,
          code: code,
          detail: detail,
          retryable: retryable,
        ),
      );
    }

    final accounted = {...synced, ...failedIds};
    final omitted = submittedTransactionUuids.difference(accounted);
    if (malformed) {
      return _protocolFailure(submittedTransactionUuids);
    }
    return ValidatedSyncResponse(
      syncedTransactionUuids: synced,
      failures: failures,
      omittedTransactionUuids: omitted,
    );
  }

  ValidatedSyncResponse _protocolFailure(Set<String> submitted) {
    return ValidatedSyncResponse(
      syncedTransactionUuids: const {},
      failures: const [],
      omittedTransactionUuids: Set.unmodifiable(submitted),
    );
  }
}
