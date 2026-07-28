import 'package:flutter_test/flutter_test.dart';
import 'package:lending_nelson/core/sync/sync_response_validator.dart';

void main() {
  const validator = SyncResponseValidator();
  const submitted = {'tx-1', 'tx-2'};

  test('accepts exactly one deterministic result per submitted item', () {
    final result = validator.validate(
      response: {
        'syncedTransactionUuids': ['tx-1'],
        'failures': [
          {
            'transactionUuid': 'tx-2',
            'code': 'TEMPORARY_DATABASE_ERROR',
            'detail': 'Temporary database error',
            'retryable': true,
          },
        ],
      },
      submittedTransactionUuids: submitted,
    );

    expect(result.syncedTransactionUuids, {'tx-1'});
    expect(result.failures.single.transactionUuid, 'tx-2');
    expect(result.omittedTransactionUuids, isEmpty);
  });

  test('unknown response UUID makes the whole response retryable', () {
    final result = validator.validate(
      response: {
        'syncedTransactionUuids': ['tx-1', 'tx-unknown'],
        'failures': <Map<String, dynamic>>[],
      },
      submittedTransactionUuids: submitted,
    );

    expect(result.syncedTransactionUuids, isEmpty);
    expect(result.omittedTransactionUuids, submitted);
  });

  test('duplicate or contradictory results are rejected', () {
    final duplicate = validator.validate(
      response: {
        'syncedTransactionUuids': ['tx-1', 'tx-1'],
        'failures': <Map<String, dynamic>>[],
      },
      submittedTransactionUuids: submitted,
    );
    final contradictory = validator.validate(
      response: {
        'syncedTransactionUuids': ['tx-1'],
        'failures': [
          {
            'transactionUuid': 'tx-1',
            'code': 'CONFLICT',
            'detail': 'Conflict',
            'retryable': false,
          },
        ],
      },
      submittedTransactionUuids: submitted,
    );

    expect(duplicate.omittedTransactionUuids, submitted);
    expect(contradictory.omittedTransactionUuids, submitted);
  });
}
