import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/database/database_service.dart';
import '../domain/borrower_communication_log.dart';

class BorrowerCommunicationLogRepository {
  BorrowerCommunicationLogRepository(this._databaseService);

  final DatabaseService _databaseService;
  static const _uuid = Uuid();

  Future<BorrowerCommunicationLog> record({
    required String borrowerId,
    required String messageType,
    required String channel,
    required BorrowerCommunicationStatus status,
    String? loanId,
    String? paymentId,
  }) async {
    final now = DateTime.now().toUtc();
    final log = BorrowerCommunicationLog(
      id: _uuid.v4(),
      borrowerId: borrowerId,
      loanId: loanId,
      paymentId: paymentId,
      messageType: messageType,
      channel: channel,
      status: status,
      createdAt: now,
      updatedAt: now,
    );
    final db = await _databaseService.database;
    await db.insert('borrower_communication_logs', _toMap(log));
    return log;
  }

  Future<void> updateStatus(
    String id,
    BorrowerCommunicationStatus status,
  ) async {
    final db = await _databaseService.database;
    await db.update(
      'borrower_communication_logs',
      {
        'status': status.name,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<BorrowerCommunicationLog>> forBorrower(String borrowerId) async {
    final db = await _databaseService.database;
    final rows = await db.query(
      'borrower_communication_logs',
      where: 'borrower_id = ?',
      whereArgs: [borrowerId],
      orderBy: 'created_at DESC',
    );
    return rows.map(_fromMap).toList(growable: false);
  }

  Map<String, Object?> _toMap(BorrowerCommunicationLog log) => {
    'id': log.id,
    'borrower_id': log.borrowerId,
    'loan_id': log.loanId,
    'payment_id': log.paymentId,
    'message_type': log.messageType,
    'channel': log.channel,
    'status': log.status.name,
    'created_at': log.createdAt.toIso8601String(),
    'updated_at': log.updatedAt.toIso8601String(),
  };

  BorrowerCommunicationLog _fromMap(Map<String, Object?> row) {
    return BorrowerCommunicationLog(
      id: row['id']! as String,
      borrowerId: row['borrower_id']! as String,
      loanId: row['loan_id'] as String?,
      paymentId: row['payment_id'] as String?,
      messageType: row['message_type']! as String,
      channel: row['channel']! as String,
      status: BorrowerCommunicationStatus.values.byName(
        row['status']! as String,
      ),
      createdAt: DateTime.parse(row['created_at']! as String),
      updatedAt: DateTime.parse(row['updated_at']! as String),
    );
  }
}

final borrowerCommunicationLogRepositoryProvider =
    Provider<BorrowerCommunicationLogRepository>((ref) {
      return BorrowerCommunicationLogRepository(
        ref.watch(databaseServiceProvider),
      );
    });
