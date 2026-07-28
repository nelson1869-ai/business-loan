import 'package:sqflite/sqflite.dart';

/// Owns crash recovery and atomic acquisition of local drain leases.
class SyncLeaseManager {
  const SyncLeaseManager({this.staleAfter = const Duration(minutes: 2)});

  final Duration staleAfter;

  Future<int> recoverStale(DatabaseExecutor database, DateTime now) {
    final cutoff = now.toUtc().subtract(staleAfter).toIso8601String();
    return database.update(
      'offline_sync_queue',
      {'status': 'pending', 'drain_lease_id': null, 'lease_acquired_at': null},
      where:
          "status = 'syncing' AND "
          "(lease_acquired_at IS NULL OR lease_acquired_at < ?)",
      whereArgs: [cutoff],
    );
  }

  Future<void> acquire({
    required Database database,
    required String leaseId,
    required Iterable<String> transactionUuids,
    required DateTime now,
  }) async {
    final timestamp = now.toUtc().toIso8601String();
    await database.transaction((transaction) async {
      for (final uuid in transactionUuids) {
        final updated = await transaction.update(
          'offline_sync_queue',
          {
            'status': 'syncing',
            'drain_lease_id': leaseId,
            'lease_acquired_at': timestamp,
            'last_attempt_at': timestamp,
          },
          where:
              "transaction_uuid = ? AND "
              "status IN ('pending', 'retryableFailed')",
          whereArgs: [uuid],
        );
        if (updated != 1) {
          throw StateError('Queue lease was acquired by another drain');
        }
      }
      await transaction.insert('sync_metadata', {
        'key': 'last_sync_attempt_at',
        'value': timestamp,
        'updated_at': timestamp,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }
}
