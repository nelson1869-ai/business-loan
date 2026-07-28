import '../../../core/database/database_service.dart';
import '../../../core/security/encryption_service.dart';
import 'admin_assistant_repository.dart';

/// Read-only assistant backed exclusively by previously synchronized SQLite data.
class LocalAdminAssistantService {
  const LocalAdminAssistantService(this._databaseService, this._encryption);

  final DatabaseService _databaseService;
  final EncryptionService _encryption;

  Future<AdminAssistantReply> answer(
    String message, {
    String? selectedBorrowerId,
    int offset = 0,
  }) async {
    final db = await _databaseService.database;
    final text = message.toLowerCase();
    final now = DateTime.now().toUtc().add(const Duration(hours: 8));
    final today = _date(now);
    final tomorrow = _date(now.add(const Duration(days: 1)));
    final lastSync = await _lastSync();

    if ({
      'hi',
      'hello',
      'hey',
      'help',
      'kumusta',
      'tulong',
    }.contains(text.trim())) {
      return _reply(
        'You are offline, but synchronized records are ready. Ask for the '
        'borrower list, portfolio, collections, due accounts, or a borrower balance.',
        today,
        lastSync,
      );
    }

    if (_asksForBorrowerDirectory(text)) {
      final encryptedRows = await db.query(
        'borrowers',
        columns: ['id', 'first_name', 'last_name', 'status'],
        where: "deleted_at IS NULL AND status != 'Deleted'",
        orderBy: 'last_name, first_name',
      );
      final rows = await _decryptBorrowerNames(encryptedRows);
      final search = _borrowerSearchTerm(text);
      final matches = search == null
          ? rows
          : rows
                .where((row) {
                  final name =
                      '${row['first_name'] ?? ''} ${row['last_name'] ?? ''}'
                          .toLowerCase();
                  return name.contains(search);
                })
                .toList(growable: false);
      final records = matches
          .skip(offset)
          .take(50)
          .map(
            (row) => AdminAssistantRecord(
              borrowerId: row['id']?.toString() ?? '',
              borrowerName:
                  '${row['first_name'] ?? ''} ${row['last_name'] ?? ''}'.trim(),
              loanId: '',
              amountDue: '0.00',
              dueDate: null,
              status: row['status']?.toString() ?? 'Active',
              recordType: 'borrower',
            ),
          )
          .toList(growable: false);
      final noun = matches.length == 1 ? 'borrower' : 'borrowers';
      return _reply(
        matches.isEmpty
            ? 'No synchronized borrower records were found.'
            : 'I found ${matches.length} synchronized $noun. '
                  'Select a borrower to open their profile.',
        today,
        lastSync,
        records: records,
        totalCount: matches.length,
        offset: offset,
      );
    }

    if ((text.contains('this month') || text.contains('ngayong buwan')) &&
        (text.contains('collect') ||
            text.contains('income') ||
            text.contains('received') ||
            text.contains('nakolekta') ||
            text.contains('koleksyon') ||
            text.contains('kita'))) {
      final monthStart =
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-01';
      final rows = await db.query(
        'repayments',
        columns: ['amount', 'entry_type'],
        where: 'effective_date >= ? AND effective_date <= ?',
        whereArgs: [monthStart, today],
      );
      var cents = 0;
      for (final row in rows) {
        final value = _cents(row['amount']);
        cents += row['entry_type'] == 'Reversal' ? -value : value;
      }
      return _reply(
        'Synchronized collections this month total PHP ${_money(cents)}.',
        today,
        lastSync,
      );
    }

    if (text.contains('portfolio') || text.contains('outstanding')) {
      final rows = await db.query(
        'loans',
        columns: ['outstanding_principal', 'status'],
        where: "deleted_at IS NULL AND status NOT IN ('Paid', 'Cancelled')",
      );
      final cents = rows.fold<int>(
        0,
        (sum, row) => sum + _cents(row['outstanding_principal']),
      );
      final overdue = rows.where((row) => row['status'] == 'Overdue').length;
      return _reply(
        'The synchronized outstanding portfolio is PHP ${_money(cents)}, '
        'with ${rows.length} active accounts and $overdue marked overdue.',
        today,
        lastSync,
      );
    }

    final asksTomorrowPayments =
        (text.contains('tomorrow') || text.contains('bukas')) &&
        (text.contains('due') ||
            text.contains('pay') ||
            text.contains('installment'));
    if (text.contains('not paid today') ||
        text.contains('due today') ||
        text.contains('hindi nagbayad today') ||
        text.contains('di nagbayad today') ||
        text.contains('due ngayon') ||
        asksTomorrowPayments ||
        text.contains('overdue')) {
      final target = (text.contains('tomorrow') || text.contains('bukas'))
          ? tomorrow
          : today;
      final operator = text.contains('overdue') ? '<' : '=';
      final rows = await db.rawQuery(
        '''
        SELECT s.loan_id, s.due_date, s.expected_payment, s.paid_amount,
               s.status, l.borrower_id, b.first_name, b.last_name
        FROM loan_schedules s
        JOIN loans l ON l.id = s.loan_id
        JOIN borrowers b ON b.id = l.borrower_id
        WHERE s.due_date $operator ?
          AND s.status NOT IN ('Paid', 'Cancelled')
          AND CAST(s.expected_payment AS REAL) > CAST(s.paid_amount AS REAL)
        ORDER BY s.due_date
        ''',
        [target],
      );
      final total = rows.fold<int>(
        0,
        (sum, row) =>
            sum +
            _cents(
              (double.tryParse(row['expected_payment']?.toString() ?? '') ??
                      0) -
                  (double.tryParse(row['paid_amount']?.toString() ?? '') ?? 0),
            ),
      );
      final records = rows
          .skip(offset)
          .take(50)
          .map(
            (row) => AdminAssistantRecord(
              borrowerId: row['borrower_id']?.toString() ?? '',
              borrowerName:
                  '${row['first_name'] ?? ''} ${row['last_name'] ?? ''}'.trim(),
              loanId: row['loan_id']?.toString() ?? '',
              amountDue: _money(
                _cents(row['expected_payment']) - _cents(row['paid_amount']),
              ),
              dueDate: row['due_date']?.toString(),
              status: row['status']?.toString() ?? '',
            ),
          )
          .toList(growable: false);
      return _reply(
        '${rows.length} synchronized installments match, totaling PHP ${_money(total)}.',
        today,
        lastSync,
        records: records,
        totalCount: rows.length,
        offset: offset,
      );
    }

    final encryptedBorrowerRows = await db.query(
      'borrowers',
      columns: ['id', 'first_name', 'last_name'],
      where: 'deleted_at IS NULL',
    );
    final borrowerRows = await _decryptBorrowerNames(encryptedBorrowerRows);
    final matches = selectedBorrowerId == null
        ? borrowerRows.where((row) {
            final name = '${row['first_name'] ?? ''} ${row['last_name'] ?? ''}'
                .trim()
                .toLowerCase();
            return name.isNotEmpty && text.contains(name);
          }).toList()
        : borrowerRows
              .where((row) => row['id']?.toString() == selectedBorrowerId)
              .toList();
    final refersToPreviousBorrower = const [
      ' they ',
      ' them ',
      ' their ',
      'that borrower',
      'this borrower',
      'the borrower',
    ].any((phrase) => ' $text '.contains(phrase));
    if (matches.isEmpty &&
        refersToPreviousBorrower &&
        borrowerRows.length > 1) {
      return AdminAssistantReply(
        answer: 'Which borrower do you mean?',
        records: const [],
        asOf: today,
        source: 'Synchronized local database',
        disclaimer: 'Offline result may be stale.',
        answerSource: 'offline',
        aiStatus: 'unavailable',
        lastSyncedAt: lastSync,
        clarification: borrowerRows
            .take(20)
            .map(
              (row) => BorrowerClarificationOption(
                borrowerId: row['id']?.toString() ?? '',
                displayName:
                    '${row['first_name'] ?? ''} ${row['last_name'] ?? ''}'
                        .trim(),
                maskedReference: _maskedBorrowerReference(row['id']),
              ),
            )
            .toList(growable: false),
      );
    }
    if (matches.isEmpty &&
        refersToPreviousBorrower &&
        borrowerRows.length == 1) {
      matches.add(borrowerRows.single);
    }
    if (matches.length > 1) {
      return AdminAssistantReply(
        answer: 'Multiple synchronized borrowers match. Select one.',
        records: const [],
        asOf: today,
        source: 'Synchronized local database',
        disclaimer: 'Offline result may be stale.',
        answerSource: 'offline',
        aiStatus: 'unavailable',
        lastSyncedAt: lastSync,
        clarification: matches
            .map(
              (row) => BorrowerClarificationOption(
                borrowerId: row['id']?.toString() ?? '',
                displayName:
                    '${row['first_name'] ?? ''} ${row['last_name'] ?? ''}'
                        .trim(),
                maskedReference: _maskedBorrowerReference(row['id']),
              ),
            )
            .toList(growable: false),
      );
    }
    if (matches.length == 1) {
      final borrower = matches.single;
      final loans = await db.query(
        'loans',
        where:
            "borrower_id = ? AND deleted_at IS NULL AND status NOT IN ('Paid', 'Cancelled')",
        whereArgs: [borrower['id']],
      );
      final outstanding = loans.fold<int>(
        0,
        (sum, row) => sum + _cents(row['outstanding_principal']),
      );
      final originalPrincipal = loans.fold<int>(
        0,
        (sum, row) => sum + _cents(row['original_principal']),
      );
      final name =
          '${borrower['first_name'] ?? ''} ${borrower['last_name'] ?? ''}'
              .trim();
      final borrowerId = borrower['id']?.toString() ?? '';
      if (_asksForPaymentHistory(text)) {
        final payments = await db.rawQuery(
          '''
          SELECT r.loan_id, r.amount, r.effective_date, r.entry_type
          FROM repayments r
          JOIN loans l ON l.id = r.loan_id
          WHERE l.borrower_id = ? AND l.deleted_at IS NULL
          ORDER BY r.effective_date DESC, r.created_at DESC
          ''',
          [borrowerId],
        );
        final records = payments
            .skip(offset)
            .take(50)
            .map(
              (row) => AdminAssistantRecord(
                borrowerId: borrowerId,
                borrowerName: name,
                loanId: row['loan_id']?.toString() ?? '',
                amountDue: '0.00',
                dueDate: null,
                status: row['entry_type']?.toString() ?? 'Payment',
                recordType: 'payment',
                amountPaid: row['amount']?.toString(),
                effectiveDate: row['effective_date']?.toString(),
              ),
            )
            .toList(growable: false);
        return _reply(
          records.isEmpty
              ? '$name has no synchronized payment entries.'
              : '$name has ${records.length} synchronized payment entries.',
          today,
          lastSync,
          records: records,
          totalCount: payments.length,
          offset: offset,
        );
      }
      if (_asksForNextPayment(text) || _asksForOverdueInstallments(text)) {
        final overdueOnly = _asksForOverdueInstallments(text);
        final schedules = await db.rawQuery(
          '''
          SELECT s.loan_id, s.due_date, s.expected_payment, s.paid_amount, s.status
          FROM loan_schedules s
          JOIN loans l ON l.id = s.loan_id
          WHERE l.borrower_id = ?
            AND l.deleted_at IS NULL
            AND s.status NOT IN ('Paid', 'Cancelled')
            AND CAST(s.expected_payment AS REAL) > CAST(s.paid_amount AS REAL)
            ${overdueOnly ? 'AND s.due_date < ?' : ''}
          ORDER BY s.due_date
          ${overdueOnly ? '' : 'LIMIT 1'}
          ''',
          [borrowerId, if (overdueOnly) today],
        );
        final records = schedules
            .skip(overdueOnly ? offset : 0)
            .take(50)
            .map(
              (row) => AdminAssistantRecord(
                borrowerId: borrowerId,
                borrowerName: name,
                loanId: row['loan_id']?.toString() ?? '',
                amountDue: _money(
                  _cents(row['expected_payment']) - _cents(row['paid_amount']),
                ),
                dueDate: row['due_date']?.toString(),
                status: row['status']?.toString() ?? 'Scheduled',
              ),
            )
            .toList(growable: false);
        if (overdueOnly) {
          return _reply(
            records.isEmpty
                ? '$name has no overdue synchronized installments.'
                : '$name has ${records.length} overdue synchronized installments.',
            today,
            lastSync,
            records: records,
            totalCount: schedules.length,
            offset: offset,
          );
        }
        final next = records.firstOrNull;
        return _reply(
          next == null
              ? '$name has no unpaid synchronized installment.'
              : "$name's next payment is PHP ${next.amountDue} "
                    'due on ${next.dueDate}.',
          today,
          lastSync,
          records: records,
          totalCount: records.length,
        );
      }
      if (_asksForLoanSummary(text)) {
        final overdueRows = await db.rawQuery(
          '''
          SELECT COUNT(*) AS count
          FROM loan_schedules s
          JOIN loans l ON l.id = s.loan_id
          WHERE l.borrower_id = ?
            AND l.deleted_at IS NULL
            AND s.due_date < ?
            AND s.status NOT IN ('Paid', 'Cancelled')
            AND CAST(s.expected_payment AS REAL) > CAST(s.paid_amount AS REAL)
          ''',
          [borrowerId, today],
        );
        final overdueCount =
            int.tryParse(overdueRows.first['count']?.toString() ?? '') ?? 0;
        return _reply(
          '$name has ${loans.length} active loans, '
          'PHP ${_money(originalPrincipal)} in original principal, '
          'PHP ${_money(outstanding)} outstanding, and '
          '$overdueCount overdue installments.',
          today,
          lastSync,
        );
      }
      return _reply(
        _asksForOriginalPrincipal(text)
            ? "$name's synchronized original principal across active loans is "
                  'PHP ${_money(originalPrincipal)}.'
            : '$name has a synchronized outstanding balance of '
                  'PHP ${_money(outstanding)}.',
        today,
        lastSync,
      );
    }

    return _reply(
      'That information is not available offline. Try asking for the borrower '
      'list, portfolio, collections this month, due accounts, overdue accounts, '
      'or a borrower balance.',
      today,
      lastSync,
    );
  }

  Future<DateTime?> _lastSync() async {
    final db = await _databaseService.database;
    final rows = await db.rawQuery('''
      SELECT MAX(value) AS last_sync FROM (
        SELECT last_synced_at AS value FROM loans
        UNION ALL
        SELECT last_synced_at AS value FROM borrowers
      ) WHERE value IS NOT NULL AND value != ''
      ''');
    return DateTime.tryParse(rows.firstOrNull?['last_sync']?.toString() ?? '');
  }

  AdminAssistantReply _reply(
    String answer,
    String asOf,
    DateTime? lastSync, {
    List<AdminAssistantRecord> records = const [],
    int totalCount = 0,
    int offset = 0,
  }) => AdminAssistantReply(
    answer: answer,
    records: records,
    asOf: asOf,
    source: 'Synchronized local database',
    disclaimer: 'Offline result may be stale. Verify after reconnecting.',
    answerSource: 'offline',
    aiStatus: 'unavailable',
    lastSyncedAt: lastSync,
    totalMatchingCount: totalCount,
    hasMore: totalCount > offset + records.length,
    nextOffset: totalCount > offset + records.length
        ? offset + records.length
        : null,
  );

  String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  int _cents(Object? value) =>
      ((double.tryParse(value?.toString() ?? '') ?? 0) * 100).round();

  String _money(int cents) => (cents / 100).toStringAsFixed(2);

  bool _asksForBorrowerDirectory(String text) {
    return const [
      'list borrower',
      'list of borrower',
      'show borrower',
      'show all borrower',
      'borrower directory',
      'all borrower',
      'listahan ng borrower',
      'mga borrower',
      'hanapin borrower',
      'find borrower',
      'search borrower',
      'search for borrower',
    ].any(text.contains);
  }

  String? _borrowerSearchTerm(String text) {
    final match = RegExp(
      r'(?:find|search(?:\s+for)?|hanapin)\s+(?:the\s+)?borrower\s+(.+)',
    ).firstMatch(text);
    final value = match
        ?.group(1)
        ?.replaceAll(RegExp(r"[^a-z0-9 '\-]"), '')
        .trim();
    return value == null || value.isEmpty ? null : value;
  }

  bool _asksForOriginalPrincipal(String text) {
    return const [
      'how much borrowed',
      'how much did',
      'how much they borrow',
      'borrow amount',
      'borrowed amount',
      'loan amount',
      'original principal',
      'magkano hiniram',
      'halaga ng utang',
    ].any(text.contains);
  }

  bool _asksForPaymentHistory(String text) => const [
    'payment history',
    'payments made',
    'mga binayad',
    'nakaraang bayad',
  ].any(text.contains);

  bool _asksForNextPayment(String text) {
    return const [
      'next payment',
      'next due',
      'susunod',
      'kailan',
    ].any(text.contains);
  }

  bool _asksForOverdueInstallments(String text) => const [
    'overdue installment',
    'late installment',
    'lampas due',
    'huling bayad',
  ].any(text.contains);

  bool _asksForLoanSummary(String text) => const [
    'loan summary',
    'loan position',
    'loan details',
    'summary',
  ].any(text.contains);

  String _maskedBorrowerReference(Object? id) {
    final value = (id?.toString() ?? '').padLeft(4);
    return 'Borrower ••••${value.substring(value.length - 4)}';
  }

  Future<List<Map<String, Object?>>> _decryptBorrowerNames(
    List<Map<String, Object?>> rows,
  ) async {
    final decrypted = <Map<String, Object?>>[];
    for (final row in rows) {
      decrypted.add({
        ...row,
        'first_name': await _encryption.decrypt(
          row['first_name']?.toString() ?? '',
        ),
        'last_name': await _encryption.decrypt(
          row['last_name']?.toString() ?? '',
        ),
      });
    }
    return decrypted;
  }
}
