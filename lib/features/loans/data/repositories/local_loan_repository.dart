import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/database_provider.dart';
import '../../../../core/database/database_service.dart';
import '../../../../core/utils/loan_calculator.dart';
import '../models/loan_create_request.dart';
import '../../domain/models/installment.dart';
import '../../domain/models/loan.dart';
import '../../domain/models/payment.dart';

class LocalLoanRepository {
  LocalLoanRepository(this._dbService);

  final DatabaseService _dbService;
  final Uuid _uuid = const Uuid();

  Future<Set<String>> _getExistingColumns(
    DatabaseExecutor db,
    String tableName,
  ) async {
    try {
      final info = await db.rawQuery('PRAGMA table_info($tableName)');
      return info.map((row) => row['name'] as String).toSet();
    } catch (_) {
      return const <String>{};
    }
  }

  Map<String, dynamic> _sanitizeRow(
    Map<String, dynamic> row,
    Set<String> validColumns,
  ) {
    if (validColumns.isEmpty) return row;
    final sanitized = <String, dynamic>{};
    for (final entry in row.entries) {
      if (validColumns.contains(entry.key)) {
        sanitized[entry.key] = entry.value;
      }
    }
    return sanitized;
  }

  /* -------------------------------------------------------------------------- */
  /*  Loans                                                                    */
  /* -------------------------------------------------------------------------- */

  Future<void> saveLoans(
    List<Loan> loans, {
    String syncStatus = 'synced',
  }) async {
    final db = await _dbService.database;
    final now = DateTime.now().toUtc().toIso8601String();

    await db.transaction((txn) async {
      final loanCols = await _getExistingColumns(txn, 'loans');
      final scheduleCols = await _getExistingColumns(txn, 'loan_schedules');

      for (final loan in loans) {
        final loanRow = _sanitizeRow({
          'id': loan.id,
          'server_id': loan.id,
          'borrower_id': loan.borrowerId,
          'request_id': loan.requestId,
          'original_principal': loan.originalPrincipal,
          'monthly_rate': loan.monthlyRate,
          'term_months': loan.termMonths,
          'payments_per_month': loan.paymentsPerMonth,
          'start_date': loan.startDate,
          'first_due_date': loan.firstDueDate,
          'final_due_date': loan.finalDueDate,
          'outstanding_principal': loan.outstandingPrincipal,
          'status': loan.status,
          'data_json': jsonEncode(loan.toJson()),
          'cached_at': now,
          'created_at': loan.createdAt,
          'sync_status': syncStatus,
          'last_synced_at': now,
        }, loanCols);

        await txn.insert(
          'loans',
          loanRow,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        for (final inst in loan.installments) {
          final instRow = _sanitizeRow({
            'id': inst.id,
            'server_id': inst.id,
            'loan_id': loan.id,
            'installment_number': inst.installmentNumber,
            'due_date': inst.dueDate,
            'expected_payment': inst.expectedPayment,
            'interest_amount': inst.expectedInterest,
            'principal_amount': inst.expectedPrincipal,
            'paid_amount': inst.paidAmount,
            'status': inst.status,
            'created_at': inst.createdAt,
            'sync_status': syncStatus,
          }, scheduleCols);

          await txn.insert(
            'loan_schedules',
            instRow,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    });
  }

  Future<void> syncLoans(List<Loan> loans) async {
    final db = await _dbService.database;
    final remoteIds = loans.map((l) => l.id).toSet();
    final localMaps = await db.query(
      'loans',
      columns: ['id'],
      where: "sync_status = 'synced'",
    );
    for (final map in localMaps) {
      final id = map['id'] as String;
      if (!remoteIds.contains(id)) {
        await db.delete('loans', where: 'id = ?', whereArgs: [id]);
        await db.delete(
          'loan_schedules',
          where: 'loan_id = ?',
          whereArgs: [id],
        );
      }
    }
    await saveLoans(loans, syncStatus: 'synced');
  }

  Future<Loan> createLoanOffline(LoanCreateRequest request) async {
    final db = await _dbService.database;

    final borrowerRows = await db.query(
      'borrowers',
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [request.borrowerId],
      limit: 1,
    );
    if (borrowerRows.isEmpty) {
      await db.insert('borrowers', <String, dynamic>{
        'id': request.borrowerId,
        'full_name': 'Borrower',
        'phone_number': '',
        'national_id': '',
        'status': 'Active',
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'sync_status': 'pending',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    final loanId = _uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();
    final double periodicRate =
        (double.tryParse(request.monthlyRate) ?? 0.0) /
        request.paymentsPerMonth;
    final int numberOfPayments = request.termMonths * request.paymentsPerMonth;

    final schedule = LoanCalculator.buildInstallmentSchedule(
      originalPrincipal: request.originalPrincipal,
      periodicRate: periodicRate,
      numberOfPayments: numberOfPayments,
    );

    final firstDue = DateTime.parse(request.firstDueDate);
    final installments = <Installment>[];
    String finalDueDate = request.firstDueDate;

    for (var i = 0; i < schedule.length; i++) {
      final item = schedule[i];
      final dueDate = DateTime(firstDue.year, firstDue.month + i, firstDue.day);
      final dueDateStr =
          '${dueDate.year.toString().padLeft(4, '0')}-${dueDate.month.toString().padLeft(2, '0')}-${dueDate.day.toString().padLeft(2, '0')}';
      if (i == schedule.length - 1) {
        finalDueDate = dueDateStr;
      }

      installments.add(
        Installment(
          id: _uuid.v4(),
          loanId: loanId,
          installmentNumber: item.number,
          dueDate: dueDateStr,
          expectedPayment: item.paymentAmount,
          expectedInterest: item.interestAmount,
          expectedPrincipal: item.principalAmount,
          expectedRemainingPrincipal: item.remainingPrincipal,
          paidAmount: '0.00',
          status: 'Scheduled',
          createdAt: now,
        ),
      );
    }

    final loan = Loan(
      id: loanId,
      requestId: request.requestId,
      borrowerId: request.borrowerId,
      createdByUserId: 'system-officer',
      originalPrincipal: request.originalPrincipal,
      outstandingPrincipal: request.originalPrincipal,
      monthlyRate: request.monthlyRate,
      termMonths: request.termMonths,
      paymentsPerMonth: request.paymentsPerMonth,
      numberOfPayments: numberOfPayments,
      regularPaymentAmount: schedule.first.paymentAmount,
      calculationMethod: 'fixed_periodic_reducing_balance',
      startDate: request.startDate,
      firstDueDate: request.firstDueDate,
      finalDueDate: finalDueDate,
      status: 'Active',
      createdAt: now,
      installments: installments,
    );

    await saveLoan(loan, syncStatus: 'pending');
    return loan;
  }

  Future<void> saveLoan(Loan loan, {String syncStatus = 'synced'}) async {
    final db = await _dbService.database;
    final now = DateTime.now().toUtc().toIso8601String();

    await db.transaction((txn) async {
      await txn.insert('loans', {
        'id': loan.id,
        'server_id': syncStatus == 'synced' ? loan.id : null,
        'borrower_id': loan.borrowerId,
        'request_id': loan.requestId,
        'original_principal': loan.originalPrincipal,
        'monthly_rate': loan.monthlyRate,
        'term_months': loan.termMonths,
        'payments_per_month': loan.paymentsPerMonth,
        'start_date': loan.startDate,
        'first_due_date': loan.firstDueDate,
        'final_due_date': loan.finalDueDate,
        'outstanding_principal': loan.outstandingPrincipal,
        'status': loan.status,
        'data_json': jsonEncode(loan.toJson()),
        'cached_at': now,
        'created_at': loan.createdAt,
        'sync_status': syncStatus,
        'last_synced_at': syncStatus == 'synced' ? now : null,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      for (final inst in loan.installments) {
        await txn.insert('loan_schedules', {
          'id': inst.id,
          'server_id': syncStatus == 'synced' ? inst.id : null,
          'loan_id': loan.id,
          'installment_number': inst.installmentNumber,
          'due_date': inst.dueDate,
          'expected_payment': inst.expectedPayment,
          'interest_amount': inst.expectedInterest,
          'principal_amount': inst.expectedPrincipal,
          'paid_amount': inst.paidAmount,
          'status': inst.status,
          'created_at': inst.createdAt,
          'sync_status': syncStatus,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<List<Loan>> getLoans({String? borrowerId, String? status}) async {
    final db = await _dbService.database;
    final whereConditions = <String>[];
    final whereArgs = <dynamic>[];

    if (borrowerId != null) {
      whereConditions.add('borrower_id = ?');
      whereArgs.add(borrowerId);
    }
    if (status != null) {
      whereConditions.add('status = ?');
      whereArgs.add(status);
    }

    whereConditions.add('deleted_at IS NULL');

    final rows = await db.query(
      'loans',
      where: whereConditions.join(' AND '),
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
    );

    final results = <Loan>[];
    for (final row in rows) {
      final loanId = (row['id'] ?? '').toString();
      if (loanId.isEmpty) continue;
      final dataStr = row['data_json'] as String?;
      if (dataStr != null && dataStr.isNotEmpty) {
        try {
          final data = jsonDecode(dataStr) as Map<String, dynamic>;
          results.add(Loan.fromJson(data));
          continue;
        } catch (_) {}
      }

      final scheduleRows = await db.query(
        'loan_schedules',
        where: 'loan_id = ?',
        whereArgs: [loanId],
        orderBy: 'installment_number ASC',
      );
      final installments = scheduleRows
          .map(
            (s) => Installment.fromJson({
              'id': (s['id'] ?? '').toString(),
              'loanId': (s['loan_id'] ?? loanId).toString(),
              'installmentNumber':
                  (s['installment_number'] as num?)?.toInt() ?? 1,
              'dueDate': (s['due_date'] ?? '').toString(),
              'expectedPayment': (s['expected_payment'] ?? '0.00').toString(),
              'expectedInterest': (s['interest_amount'] ?? '0.00').toString(),
              'expectedPrincipal': (s['principal_amount'] ?? '0.00').toString(),
              'expectedRemainingPrincipal': '0.00',
              'paidAmount': (s['paid_amount'] ?? '0.00').toString(),
              'status': (s['status'] ?? 'Scheduled').toString(),
              'createdAt': (s['created_at'] ?? '').toString(),
            }),
          )
          .toList();

      results.add(
        Loan(
          id: loanId,
          requestId: (row['request_id'] ?? loanId).toString(),
          borrowerId: (row['borrower_id'] ?? '').toString(),
          createdByUserId: 'system-officer',
          originalPrincipal: (row['original_principal'] ?? '0.00').toString(),
          outstandingPrincipal: (row['outstanding_principal'] ?? '0.00')
              .toString(),
          monthlyRate: (row['monthly_rate'] ?? '0.00').toString(),
          termMonths: (row['term_months'] as num?)?.toInt() ?? 1,
          paymentsPerMonth: (row['payments_per_month'] as num?)?.toInt() ?? 1,
          numberOfPayments: installments.length,
          regularPaymentAmount: installments.isNotEmpty
              ? installments.first.expectedPayment
              : '0.00',
          calculationMethod: 'fixed_periodic_reducing_balance',
          startDate: (row['start_date'] ?? '').toString(),
          firstDueDate: (row['first_due_date'] ?? '').toString(),
          finalDueDate: (row['final_due_date'] ?? '').toString(),
          status: (row['status'] ?? 'Active').toString(),
          createdAt: (row['created_at'] ?? '').toString(),
          installments: installments,
        ),
      );
    }
    return results;
  }

  Future<Loan?> getLoan(String loanId) async {
    final loans = await getLoans();
    for (final l in loans) {
      if (l.id == loanId) return l;
    }
    return null;
  }

  Future<void> deleteLoan(String loanId) async {
    final db = await _dbService.database;
    await db.delete('loans', where: 'id = ?', whereArgs: [loanId]);
    await db.delete(
      'loan_schedules',
      where: 'loan_id = ?',
      whereArgs: [loanId],
    );
  }

  /* -------------------------------------------------------------------------- */
  /*  Payments                                                                 */
  /* -------------------------------------------------------------------------- */

  Future<void> savePayments(String loanId, List<LoanPayment> payments) async {
    final db = await _dbService.database;
    final now = DateTime.now().toUtc().toIso8601String();
    final batch = db.batch();
    for (final payment in payments) {
      batch.insert('repayments', {
        'id': payment.id,
        'server_id': payment.id,
        'loan_id': loanId,
        'installment_id': payment.installmentId,
        'entry_type': payment.entryType,
        'request_id': payment.requestId,
        'reversal_of_payment_id': payment.reversalOfPaymentId,
        'amount': payment.amount,
        'effective_date': payment.effectiveDate,
        'note': payment.note,
        'allocation_json': jsonEncode(_paymentToJson(payment)),
        'created_at': payment.createdAt,
        'sync_status': 'synced',
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      batch.insert('loan_payments', {
        'id': payment.id,
        'loan_id': loanId,
        'data_json': jsonEncode(_paymentToJson(payment)),
        'cached_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> savePayment(
    LoanPayment payment, {
    String syncStatus = 'pending',
  }) async {
    final db = await _dbService.database;
    final now = DateTime.now().toUtc().toIso8601String();

    await db.transaction((txn) async {
      await txn.insert('repayments', {
        'id': payment.id,
        'server_id': syncStatus == 'synced' ? payment.id : null,
        'loan_id': payment.loanId,
        'installment_id': payment.installmentId,
        'entry_type': payment.entryType,
        'request_id': payment.requestId,
        'reversal_of_payment_id': payment.reversalOfPaymentId,
        'amount': payment.amount,
        'effective_date': payment.effectiveDate,
        'note': payment.note,
        'allocation_json': jsonEncode(_paymentToJson(payment)),
        'created_at': payment.createdAt,
        'sync_status': syncStatus,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      await txn.insert('loan_payments', {
        'id': payment.id,
        'loan_id': payment.loanId,
        'data_json': jsonEncode(_paymentToJson(payment)),
        'cached_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<List<LoanPayment>> getPayments(String loanId) async {
    final db = await _dbService.database;
    final rows = await db.query(
      'repayments',
      where: 'loan_id = ?',
      whereArgs: [loanId],
      orderBy: 'created_at DESC',
    );
    if (rows.isNotEmpty) {
      return rows.map((row) {
        final allocStr = row['allocation_json'] as String?;
        if (allocStr != null) {
          try {
            return LoanPayment.fromJson(
              jsonDecode(allocStr) as Map<String, dynamic>,
            );
          } catch (_) {}
        }
        return LoanPayment(
          id: row['id'] as String,
          requestId: row['request_id'] as String? ?? row['id'] as String,
          loanId: row['loan_id'] as String,
          installmentId: row['installment_id'] as String?,
          entryType: row['entry_type'] as String? ?? 'Payment',
          reversalOfPaymentId: row['reversal_of_payment_id'] as String?,
          amount: row['amount'] as String,
          effectiveDate: row['effective_date'] as String,
          note: row['note'] as String?,
          createdAt: row['created_at'] as String,
          allocation: const PaymentAllocation(
            appliedInterest: '0.00',
            appliedPrincipal: '0.00',
            unappliedCredit: '0.00',
            interestAfter: '0.00',
            principalAfter: '0.00',
            overdueDays: 0,
          ),
        );
      }).toList();
    }

    final fallbackRows = await db.query(
      'loan_payments',
      where: 'loan_id = ?',
      whereArgs: [loanId],
      orderBy: 'cached_at DESC',
    );
    return fallbackRows.map((row) {
      final data =
          jsonDecode(row['data_json'] as String) as Map<String, dynamic>;
      return LoanPayment.fromJson(data);
    }).toList();
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
