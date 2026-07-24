import 'package:flutter_test/flutter_test.dart';
import 'package:lending_nelson/core/network/offline_sync_service.dart';

void main() {
  group('OfflineSyncService Queue Model & Enum Tests', () {
    test('QueueItemStatus string serialization and deserialization', () {
      expect(QueueItemStatus.pending.toDbValue(), equals('pending'));
      expect(QueueItemStatus.syncing.toDbValue(), equals('syncing'));
      expect(
        QueueItemStatus.retryableFailed.toDbValue(),
        equals('retryableFailed'),
      );
      expect(
        QueueItemStatus.permanentlyFailed.toDbValue(),
        equals('permanentlyFailed'),
      );
      expect(QueueItemStatus.conflict.toDbValue(), equals('conflict'));

      expect(
        QueueItemStatusX.fromDbValue('pending'),
        equals(QueueItemStatus.pending),
      );
      expect(
        QueueItemStatusX.fromDbValue('syncing'),
        equals(QueueItemStatus.syncing),
      );
      expect(
        QueueItemStatusX.fromDbValue('retryableFailed'),
        equals(QueueItemStatus.retryableFailed),
      );
      expect(
        QueueItemStatusX.fromDbValue('permanentlyFailed'),
        equals(QueueItemStatus.permanentlyFailed),
      );
      expect(
        QueueItemStatusX.fromDbValue('conflict'),
        equals(QueueItemStatus.conflict),
      );
      expect(
        QueueItemStatusX.fromDbValue('unknown'),
        equals(QueueItemStatus.pending),
      );
    });

    test('OfflineQueueState initialization and counts', () {
      const state = OfflineQueueState(
        pendingCount: 2,
        retryableFailedCount: 1,
        permanentlyFailedCount: 1,
        conflictCount: 0,
        totalCount: 4,
      );

      expect(state.pendingCount, equals(2));
      expect(state.retryableFailedCount, equals(1));
      expect(state.permanentlyFailedCount, equals(1));
      expect(state.conflictCount, equals(0));
      expect(state.totalCount, equals(4));
    });
  });
}
