import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../core/database/database_provider.dart';
import '../../../../core/database/database_service.dart';
import '../../domain/models/loan.dart';
import '../../domain/models/payment.dart';

class LocalLoanRepository {
  LocalLoanRepository(this._dbService);

  final DatabaseService _dbService;

  /* -------------------------------------------------------------------------- */
  /*  Loans                                                                    */
  /* -------------------------------------------------------------------------- */

  Future<void> saveLoans(List<Loan> loans) async {
    final db = await _dbService.database;
    final now = DateTime.now().toUtc().toIso8601String();
    final batch = db.batch();
    for (final loan in loans) {
      batch.insert('loans', {
        'id': loan.id,
        'borrower_id': loan.borrowerId,
        'data_json': jsonEncode(loan.toJson()),
        'cached_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> syncLoans(List<Loan> loans) async {
    final db = await _dbService.database;
    final remoteIds = loans.map((l) => l.id).toSet();
    final localMaps = await db.query('loans', columns: ['id']);
    for (final map in localMaps) {
      final id = map['id'] as String;
      if (!remoteIds.contains(id)) {
        await db.delete('loans', where: 'id = ?', whereArgs: [id]);
      }
    }
    await saveLoans(loans);
  }

  Future<void> saveLoan(Loan loan) async {
    final db = await _dbService.database;
    await db.insert('loans', {
      'id': loan.id,
      'borrower_id': loan.borrowerId,
      'data_json': jsonEncode(loan.toJson()),
      'cached_at': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Loan>> getLoans({String? borrowerId}) async {
    final db = await _dbService.database;
    final rows = await db.query(
      'loans',
      where: borrowerId != null ? 'borrower_id = ?' : null,
      whereArgs: borrowerId != null ? [borrowerId] : null,
      orderBy: 'cached_at DESC',
    );
    return rows
        .map((row) {
          final data =
              jsonDecode(row['data_json'] as String) as Map<String, dynamic>;
          return Loan.fromJson(data);
        })
        .toList(growable: false);
  }

  Future<Loan?> getLoan(String loanId) async {
    final db = await _dbService.database;
    final rows = await db.query(
      'loans',
      where: 'id = ?',
      whereArgs: [loanId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final data =
        jsonDecode(rows.first['data_json'] as String) as Map<String, dynamic>;
    return Loan.fromJson(data);
  }

  Future<void> deleteLoan(String loanId) async {
    final db = await _dbService.database;
    await db.delete('loans', where: 'id = ?', whereArgs: [loanId]);
  }

  /* -------------------------------------------------------------------------- */
  /*  Payments                                                                 */
  /* -------------------------------------------------------------------------- */

  Future<void> savePayments(String loanId, List<LoanPayment> payments) async {
    final db = await _dbService.database;
    final now = DateTime.now().toUtc().toIso8601String();
    final batch = db.batch();
    for (final payment in payments) {
      batch.insert('loan_payments', {
        'id': payment.id,
        'loan_id': loanId,
        'data_json': jsonEncode(_paymentToJson(payment)),
        'cached_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> savePayment(LoanPayment payment) async {
    final db = await _dbService.database;
    await db.insert('loan_payments', {
      'id': payment.id,
      'loan_id': payment.loanId,
      'data_json': jsonEncode(_paymentToJson(payment)),
      'cached_at': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<LoanPayment>> getPayments(String loanId) async {
    final db = await _dbService.database;
    final rows = await db.query(
      'loan_payments',
      where: 'loan_id = ?',
      whereArgs: [loanId],
      orderBy: 'cached_at DESC',
    );
    return rows
        .map((row) {
          final data =
              jsonDecode(row['data_json'] as String) as Map<String, dynamic>;
          return LoanPayment.fromJson(data);
        })
        .toList(growable: false);
  }

  Map<String, dynamic> _paymentToJson(LoanPayment payment) => <String, dynamic>{
    'id': payment.id,
    'requestId': payment.requestId,
    'loanId': payment.loanId,
    'installmentId': payment.installmentId,
    'entryType': payment.entryType,
    'reversalOfPaymentId': payment.reversalOfPaymentId,
    'amount': payment.amount,
    'effectiveDate': payment.effectiveDate,
    'note': payment.note,
    'createdAt': payment.createdAt,
    'allocation': <String, dynamic>{
      'appliedInterest': payment.allocation.appliedInterest,
      'appliedPrincipal': payment.allocation.appliedPrincipal,
      'unappliedCredit': payment.allocation.unappliedCredit,
      'interestAfter': payment.allocation.interestAfter,
      'principalAfter': payment.allocation.principalAfter,
      'overdueDays': payment.allocation.overdueDays,
    },
  };
}

final localLoanRepositoryProvider = Provider<LocalLoanRepository>((ref) {
  return LocalLoanRepository(ref.watch(databaseServiceProvider));
});
