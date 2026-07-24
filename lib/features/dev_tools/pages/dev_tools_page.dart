import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../borrowers/providers/borrowers_state.dart';
import '../../dashboard/providers/dashboard_state.dart';
import '../../loans/presentation/providers/loans_provider.dart';

class DevToolsPage extends ConsumerStatefulWidget {
  const DevToolsPage({super.key});

  @override
  ConsumerState<DevToolsPage> createState() => _DevToolsPageState();
}

class _DevToolsPageState extends ConsumerState<DevToolsPage> {
  final _logs = <String>[];
  final _uuid = const Uuid();
  bool _running = false;

  void _log(String msg) {
    setState(
      () => _logs.insert(
        0,
        '[${DateTime.now().toString().substring(11, 19)}] $msg',
      ),
    );
  }

  Future<Dio> _dio() async => ref.read(apiClientProvider);

  Future<void> _deleteAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete All Data?'),
        content: const Text(
          'This will delete ALL borrowers and loans on the backend. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Everything'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _running = true;
      _logs.clear();
    });
    _log('Starting delete...');
    final dio = await _dio();

    try {
      await dio.post<Map<String, dynamic>>(ApiEndpoints.adminReset);
      _log('Backend data cleared');
    } on DioException catch (e) {
      _log('Could not reset backend: ${e.message}');
    }

    _log('Clearing local cache...');
    try {
      final db = await ref.read(databaseServiceProvider).database;
      await db.delete('borrowers');
      await db.delete('loans');
      await db.delete('loan_payments');
      await db.delete('offline_sync_queue');
      _log('Local cache cleared');
    } catch (e) {
      _log('Could not clear local cache: $e');
    }

    ref.invalidate(borrowersNotifierProvider);
    ref.invalidate(dashboardProvider);
    ref.invalidate(allLoansProvider);
    ref.invalidate(todaysCollectionsProvider);

    _log('Delete complete');
    setState(() => _running = false);
  }

  Future<void> _seed() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Seed Test Data?'),
        content: const Text(
          'This will add sample borrowers, loans, and payments '
          'covering paid-off, active, overdue, late, early payoff, '
          'reversal, and due-today scenarios.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Seed Data'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _running = true;
      _logs.clear();
    });
    _log('Starting seed...');
    final dio = await _dio();

    Future<String> createBorrower({
      required String firstName,
      required String lastName,
      required String nationalId,
      required String phone,
      required String dateOfBirth,
      required String status,
      required String createdAt,
    }) async {
      final id = _uuid.v4();
      await dio.post<void>(
        ApiEndpoints.borrowers,
        data: {
          'id': id,
          'firstName': firstName,
          'lastName': lastName,
          'nationalId': nationalId,
          'phone': phone,
          'dateOfBirth': dateOfBirth,
          'status': status,
          'createdAt': createdAt,
        },
      );
      _log('Created borrower: $firstName $lastName ($status)');
      return id;
    }

    Future<String> createLoan({
      required String borrowerId,
      required String originalPrincipal,
      required String monthlyRate,
      required int termMonths,
      required int paymentsPerMonth,
      required String startDate,
      required String firstDueDate,
    }) async {
      final response = await dio.post<Map<String, dynamic>>(
        ApiEndpoints.loans,
        data: {
          'borrowerId': borrowerId,
          'requestId': _uuid.v4(),
          'originalPrincipal': originalPrincipal,
          'monthlyRate': monthlyRate,
          'termMonths': termMonths,
          'paymentsPerMonth': paymentsPerMonth,
          'startDate': startDate,
          'firstDueDate': firstDueDate,
        },
      );
      final loanId = response.data!['id'] as String;
      _log(
        'Created loan $loanId ($originalPrincipal, ${termMonths}m @ $monthlyRate)',
      );
      return loanId;
    }

    Future<Map<String, dynamic>> fetchLoan(String loanId) async {
      final resp = await dio.get<Map<String, dynamic>>(
        '${ApiEndpoints.loans}/$loanId',
      );
      return resp.data!;
    }

    Future<String> recordPayment({
      required String loanId,
      required String amount,
      required String effectiveDate,
      String? note,
    }) async {
      final response = await dio.post<Map<String, dynamic>>(
        ApiEndpoints.loanPayments(loanId),
        data: {
          'requestId': _uuid.v4(),
          'amount': amount,
          'effectiveDate': effectiveDate,
          if (note != null && note.isNotEmpty) 'note': note,
        },
      );
      final paymentId = response.data!['id'] as String;
      _log('Recorded payment $paymentId: $amount on $effectiveDate');
      return paymentId;
    }

    Future<int> payAllInstallments(String loanId) async {
      final loan = await fetchLoan(loanId);
      final installments = loan['installments'] as List<dynamic>;
      int count = 0;
      for (final inst in installments) {
        final status = inst['status'] as String;
        if (status == 'Paid' || status == 'Cancelled') continue;
        final dueDate = inst['dueDate'] as String;
        final expected = inst['expectedPayment'] as String;
        await recordPayment(
          loanId: loanId,
          amount: expected,
          effectiveDate: dueDate,
        );
        count++;
      }
      return count;
    }

    Future<void> reversePayment({
      required String loanId,
      required String paymentId,
      required String effectiveDate,
      required String reason,
    }) async {
      await dio.post<void>(
        '${ApiEndpoints.loanPayments(loanId)}/$paymentId/reversal',
        data: {
          'requestId': _uuid.v4(),
          'effectiveDate': effectiveDate,
          'reason': reason,
        },
      );
      _log('Reversed payment $paymentId on $effectiveDate');
    }

    try {
      final ts = DateTime.now().millisecondsSinceEpoch;

      // ── Borrowers ──────────────────────────────────────────────────
      // Each borrower demonstrates a distinct status scenario.
      // nationalId includes a timestamp so re-seeding does not collide.

      final john = await createBorrower(
        firstName: 'John',
        lastName: 'Smith',
        nationalId: 'ID-$ts-001',
        phone: '+254701234567',
        dateOfBirth: '1990-05-15',
        status: 'Active',
        createdAt: '2026-01-01T09:00:00Z',
      );
      _log('Borrower: John Smith — Active (paid-off + current loan)');

      final mary = await createBorrower(
        firstName: 'Mary',
        lastName: 'Johnson',
        nationalId: 'ID-$ts-002',
        phone: '+254712345678',
        dateOfBirth: '1995-08-22',
        status: 'Pending',
        createdAt: '2026-07-20T10:30:00Z',
      );
      _log('Borrower: Mary Johnson — Pending (new registration)');

      final robert = await createBorrower(
        firstName: 'Robert',
        lastName: 'Williams',
        nationalId: 'ID-$ts-003',
        phone: '+254723456789',
        dateOfBirth: '1988-11-03',
        status: 'Active',
        createdAt: '2026-02-15T08:00:00Z',
      );
      _log('Borrower: Robert Williams — Active (overdue + current loan)');

      final patricia = await createBorrower(
        firstName: 'Patricia',
        lastName: 'Brown',
        nationalId: 'ID-$ts-004',
        phone: '+254734567890',
        dateOfBirth: '1992-04-10',
        status: 'Active',
        createdAt: '2026-01-20T11:00:00Z',
      );
      _log('Borrower: Patricia Brown — Active (early payoff + current loan)');

      final james = await createBorrower(
        firstName: 'James',
        lastName: 'Miller',
        nationalId: 'ID-$ts-005',
        phone: '+254745678901',
        dateOfBirth: '1985-07-30',
        status: 'Active',
        createdAt: '2026-03-01T07:45:00Z',
      );
      _log('Borrower: James Miller — Active (late, under, reversal)');

      final susan = await createBorrower(
        firstName: 'Susan',
        lastName: 'Davis',
        nationalId: 'ID-$ts-006',
        phone: '+254756789012',
        dateOfBirth: '1993-12-05',
        status: 'Deleted',
        createdAt: '2026-04-01T08:00:00Z',
      );
      _log('Borrower: Susan Davis — Deleted (had paid-off loan)');

      final now = DateTime.now();
      final todayStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final yesterday = DateTime(now.year, now.month, now.day - 1);
      final yesterdayStr =
          '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

      final grace = await createBorrower(
        firstName: 'Grace',
        lastName: 'Mwangi',
        nationalId: 'ID-$ts-007',
        phone: '+254767890123',
        dateOfBirth: '1991-06-18',
        status: 'Active',
        createdAt: '${todayStr}T08:00:00Z',
      );
      _log('Borrower: Grace Mwangi — Active (installment due today)');

      // ════════════════════════════════════════════════════════════════
      //  LOANS
      // ════════════════════════════════════════════════════════════════
      //
      // monthlyRate is stored as a DECIMAL FRACTION on the backend.
      // 10 % per month  →  "0.10"
      //  8 % per month  →  "0.08"
      // 12 % per month  →  "0.12"
      // 15 % per month  →  "0.15"

      // John A — 6 on-time payments → Paid off
      final johnLoan1 = await createLoan(
        borrowerId: john,
        originalPrincipal: '50000.00',
        monthlyRate: '0.10',
        termMonths: 6,
        paymentsPerMonth: 1,
        startDate: '2026-01-01',
        firstDueDate: '2026-02-01',
      );

      // John B — 1 on-time payment so far → Current / Active
      final johnLoan2 = await createLoan(
        borrowerId: john,
        originalPrincipal: '30000.00',
        monthlyRate: '0.08',
        termMonths: 3,
        paymentsPerMonth: 1,
        startDate: '2026-06-01',
        firstDueDate: '2026-07-01',
      );

      // Mary A — Pending borrower with an active loan (edge case)
      await createLoan(
        borrowerId: mary,
        originalPrincipal: '12000.00',
        monthlyRate: '0.10',
        termMonths: 2,
        paymentsPerMonth: 1,
        startDate: '2026-08-01',
        firstDueDate: '2026-09-01',
      );

      // Robert A — No payments for 4 months → Overdue
      await createLoan(
        borrowerId: robert,
        originalPrincipal: '25000.00',
        monthlyRate: '0.12',
        termMonths: 4,
        paymentsPerMonth: 1,
        startDate: '2026-03-01',
        firstDueDate: '2026-04-01',
      );

      // Robert B — New loan, partial payment then reversed → Active
      final robertLoan2 = await createLoan(
        borrowerId: robert,
        originalPrincipal: '10000.00',
        monthlyRate: '0.10',
        termMonths: 3,
        paymentsPerMonth: 1,
        startDate: '2026-07-15',
        firstDueDate: '2026-08-15',
      );

      // Patricia A — Early overpay before first due → Paid
      final patriciaLoan = await createLoan(
        borrowerId: patricia,
        originalPrincipal: '20000.00',
        monthlyRate: '0.10',
        termMonths: 3,
        paymentsPerMonth: 1,
        startDate: '2026-01-15',
        firstDueDate: '2026-02-15',
      );

      // Patricia B — 1 on-time payment → Current / Active
      final patriciaLoan2 = await createLoan(
        borrowerId: patricia,
        originalPrincipal: '15000.00',
        monthlyRate: '0.10',
        termMonths: 2,
        paymentsPerMonth: 1,
        startDate: '2026-07-01',
        firstDueDate: '2026-08-01',
      );

      // James A — Late pays, underpayment, reversal, same-day split → Mixed
      final jamesLoan = await createLoan(
        borrowerId: james,
        originalPrincipal: '40000.00',
        monthlyRate: '0.15',
        termMonths: 5,
        paymentsPerMonth: 1,
        startDate: '2026-02-01',
        firstDueDate: '2026-03-01',
      );

      // Susan A — Paid off on a Deleted borrower (edge case)
      final susanLoan = await createLoan(
        borrowerId: susan,
        originalPrincipal: '18000.00',
        monthlyRate: '0.10',
        termMonths: 3,
        paymentsPerMonth: 1,
        startDate: '2026-04-01',
        firstDueDate: '2026-05-01',
      );

      // Grace A — Due today so Today's Collections shows it
      await createLoan(
        borrowerId: grace,
        originalPrincipal: '22000.00',
        monthlyRate: '0.10',
        termMonths: 4,
        paymentsPerMonth: 1,
        startDate: yesterdayStr,
        firstDueDate: todayStr,
      );

      // ════════════════════════════════════════════════════════════════
      //  PAYMENTS
      // ════════════════════════════════════════════════════════════════

      // ── John A — All installments paid on time → Paid ─────────────
      _log('John A: paying all installments exactly on their due dates → Paid');
      await payAllInstallments(johnLoan1);

      // ── John B — First installment on time → Current ──────────────
      _log('John B: first installment paid on time → Current');
      {
        final loan = await fetchLoan(johnLoan2);
        final inst = (loan['installments'] as List<dynamic>).first;
        await recordPayment(
          loanId: johnLoan2,
          amount: inst['expectedPayment'] as String,
          effectiveDate: inst['dueDate'] as String,
        );
      }

      // ── Mary A — No payments → Active loan, Pending borrower ──────
      _log('Mary A: no payments (Pending borrower with active loan)');

      // ── Robert A — No payments → Overdue ──────────────────────────
      _log('Robert A: no payments → Overdue');

      // ── Robert B — Partial late payment, then reversed ────────────
      _log('Robert B: partial late payment, then reversed');
      {
        final partial = await recordPayment(
          loanId: robertLoan2,
          amount: '4000.00',
          effectiveDate: '2026-08-20',
        );
        await reversePayment(
          loanId: robertLoan2,
          paymentId: partial,
          effectiveDate: '2026-08-22',
          reason: 'Wrong amount — corrected via reversal',
        );
      }

      // ── Patricia A — Single large payment before first due → Early overpay → Paid
      _log('Patricia A: early overpay before first due → Paid');
      await recordPayment(
        loanId: patriciaLoan,
        amount: '25000.00',
        effectiveDate: '2026-01-25',
      );

      // ── Patricia B — First installment on time → Current ──────────
      _log('Patricia B: first installment paid on time → Current');
      {
        final loan = await fetchLoan(patriciaLoan2);
        final inst = (loan['installments'] as List<dynamic>).first;
        await recordPayment(
          loanId: patriciaLoan2,
          amount: inst['expectedPayment'] as String,
          effectiveDate: inst['dueDate'] as String,
        );
      }

      // ── James A — Late, under, reversal, re-pay, same-day split ──
      _log('James A: late pay, underpayment, reversal, re-pay, same-day split');
      {
        final loan = await fetchLoan(jamesLoan);
        final insts = loan['installments'] as List<dynamic>;

        // Installment 1 — late (due 2026-03-01, paid 2026-03-10)
        await recordPayment(
          loanId: jamesLoan,
          amount: (insts[0] as Map)['expectedPayment'] as String,
          effectiveDate: '2026-03-10',
        );

        // Installment 2 — late (due 2026-04-01, paid 2026-04-05)
        await recordPayment(
          loanId: jamesLoan,
          amount: (insts[1] as Map)['expectedPayment'] as String,
          effectiveDate: '2026-04-05',
        );

        // Installment 3 — underpayment (due 2026-05-01, paid 5000)
        final inst3Expected = (insts[2] as Map)['expectedPayment'] as String;
        final inst3Due = (insts[2] as Map)['dueDate'] as String;
        final underPayment = await recordPayment(
          loanId: jamesLoan,
          amount: '5000.00',
          effectiveDate: inst3Due,
        );

        // Reversal of the underpayment (latest unreversed payment)
        await reversePayment(
          loanId: jamesLoan,
          paymentId: underPayment,
          effectiveDate: '2026-05-10',
          reason: 'Incorrect amount — reversed',
        );

        // Re-pay installment 3 with the correct amount (now late)
        await recordPayment(
          loanId: jamesLoan,
          amount: inst3Expected,
          effectiveDate: '2026-05-15',
        );

        // Installment 4 — split into two same‑day payments
        final inst4Expected = (insts[3] as Map)['expectedPayment'] as String;
        final inst4Due = (insts[3] as Map)['dueDate'] as String;
        final half = (double.parse(inst4Expected) / 2).toStringAsFixed(2);
        await recordPayment(
          loanId: jamesLoan,
          amount: half,
          effectiveDate: inst4Due,
        );
        await recordPayment(
          loanId: jamesLoan,
          amount: half,
          effectiveDate: inst4Due,
        );
      }

      // ── Grace A — No payments → Scheduled installment due today ───
      _log('Grace A: no payments (installment due today)');

      // ── Susan A — All installments paid on time → Paid (Deleted borrower)
      _log('Susan A: paying all installments → Paid (Deleted borrower)');
      await payAllInstallments(susanLoan);

      // Refresh app providers so the UI picks up the new data
      ref.invalidate(borrowersNotifierProvider);
      ref.invalidate(allLoansProvider);
      ref.invalidate(dashboardProvider);
      ref.invalidate(todaysCollectionsProvider);

      _log('Seed complete!');
    } on DioException catch (e) {
      _log('Seed failed: ${e.message}');
    } catch (e) {
      _log('Seed failed: $e');
    }
    setState(() => _running = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/settings');
            }
          },
        ),
        title: const Text('Dev Tools'),
        actions: [
          if (_running)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _running ? null : _deleteAll,
                    icon: const Icon(Icons.delete_forever),
                    label: const Text('Delete All Data'),
                    style: FilledButton.styleFrom(backgroundColor: Colors.red),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _running ? null : _seed,
                    icon: const Icon(Icons.science),
                    label: const Text('Seed Test Data'),
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Divider(),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text('Logs', style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                if (_logs.isNotEmpty)
                  TextButton(
                    onPressed: () => setState(() => _logs.clear()),
                    child: const Text('Clear'),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _logs.isEmpty
                ? Center(
                    child: Text(
                      'Run an action above to see results here.',
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _logs.length,
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        _logs[i],
                        style: const TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
