import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:borrower_mobile/features/loans/models/borrower_loan.dart';
import 'package:borrower_mobile/features/loans/providers/loans_provider.dart';
import 'package:borrower_mobile/features/payments/models/borrower_payment.dart';
import 'package:borrower_mobile/features/payments/providers/payments_provider.dart';
import 'package:borrower_mobile/features/payments/receipt_modal.dart';
import 'package:borrower_mobile/core/widgets/route_back_navigation.dart';

class LoanDetailScreen extends ConsumerWidget {
  final String loanId;

  const LoanDetailScreen({
    super.key,
    required this.loanId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(loanDetailNotifierProvider(loanId));
    final scheduleState = ref.watch(loanScheduleNotifierProvider(loanId));
    final paymentsState = ref.watch(loanPaymentsNotifierProvider(loanId));
    final currencyFormat =
        NumberFormat.currency(symbol: '₱ ', decimalDigits: 2);
    final dateFormat = DateFormat('MMM dd, yyyy');
    final timeFormat = DateFormat('MMM dd, h:mm a');

    final title = state.detail?.loanReference ?? 'Loan Details';

    return RouteBackScope(
      fallbackLocation: '/loans',
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          leading: const RouteBackButton(
            fallbackLocation: '/loans',
            tooltip: 'Back to loans',
          ),
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            await Future.wait([
              ref
                  .read(loanDetailNotifierProvider(loanId).notifier)
                  .loadDetail(),
              ref
                  .read(loanScheduleNotifierProvider(loanId).notifier)
                  .loadSchedule(),
              ref
                  .read(loanPaymentsNotifierProvider(loanId).notifier)
                  .loadPayments(),
            ]);
          },
          child: _buildBody(
            context,
            ref,
            state,
            scheduleState,
            paymentsState,
            currencyFormat,
            dateFormat,
            timeFormat,
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    LoanDetailState state,
    LoanScheduleState scheduleState,
    LoanPaymentsState paymentsState,
    NumberFormat currencyFormat,
    DateFormat dateFormat,
    DateFormat timeFormat,
  ) {
    if (state.isLoading && state.detail == null) {
      return _buildSkeletonLoader();
    }

    if (state.errorMessage != null && state.detail == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.redAccent,
                  size: 48,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Loan detail not found',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    state.errorMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    ref
                        .read(loanDetailNotifierProvider(loanId).notifier)
                        .loadDetail();
                    ref
                        .read(loanScheduleNotifierProvider(loanId).notifier)
                        .loadSchedule();
                    ref
                        .read(loanPaymentsNotifierProvider(loanId).notifier)
                        .loadPayments();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final detail = state.detail;
    if (detail == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 100),
          Center(child: Text('Loan account not found or access denied.')),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        if (detail.isFromCache)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              border: Border.all(color: Colors.amber.shade400),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.wifi_off_rounded,
                    color: Colors.amber.shade800, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Offline Mode • Displaying cached detail from ${timeFormat.format(detail.lastUpdated.toLocal())}',
                    style: TextStyle(
                      color: Colors.amber.shade900,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Header Status Banner
        Card(
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      detail.loanReference,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    _buildStatusChip(detail.status),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Outstanding Balance',
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 4),
                Text(
                  currencyFormat
                      .format(detail.financialSummary.outstandingBalance),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Financial Summary Section
        _buildFinancialSummaryCard(detail.financialSummary, currencyFormat),

        const SizedBox(height: 16),

        // Loan Terms Section
        _buildTermsCard(detail.terms, currencyFormat, dateFormat),

        const SizedBox(height: 16),

        // Next Payment Preview Section
        if (detail.nextInstallment != null) ...[
          _buildNextPaymentCard(
              detail.nextInstallment!, currencyFormat, dateFormat),
          const SizedBox(height: 16),
        ],

        // Installment Schedule Section
        _buildInstallmentScheduleCard(
            scheduleState, currencyFormat, dateFormat),

        const SizedBox(height: 16),

        // Payment History Section
        _buildPaymentHistoryCard(
            context, paymentsState, currencyFormat, dateFormat),
      ],
    );
  }

  Widget _buildFinancialSummaryCard(
    BorrowerLoanFinancialSummary fin,
    NumberFormat currencyFormat,
  ) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Financial Summary',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 14),
            _buildDetailRow('Original Principal',
                currencyFormat.format(fin.principalAmount)),
            const Divider(height: 20),
            _buildDetailRow('Total Scheduled Interest',
                currencyFormat.format(fin.interestAmount)),
            const Divider(height: 20),
            _buildDetailRow(
                'Total Repayable', currencyFormat.format(fin.totalRepayable),
                isBold: true),
            const Divider(height: 20),
            _buildDetailRow(
                'Total Amount Paid', currencyFormat.format(fin.amountPaid),
                color: Colors.green),
            const Divider(height: 20),
            _buildDetailRow('Outstanding Balance',
                currencyFormat.format(fin.outstandingBalance),
                isBold: true),
            if (fin.overdueAmount > 0) ...[
              const Divider(height: 20),
              _buildDetailRow(
                  'Overdue Balance', currencyFormat.format(fin.overdueAmount),
                  color: Colors.red, isBold: true),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTermsCard(
    BorrowerLoanTerms terms,
    NumberFormat currencyFormat,
    DateFormat dateFormat,
  ) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Loan Terms',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 14),
            _buildDetailRow(
                'Payment Frequency', _formatFrequency(terms.paymentFrequency)),
            const Divider(height: 20),
            _buildDetailRow(
                'Installments Count', '${terms.installmentCount} payments'),
            const Divider(height: 20),
            _buildDetailRow('Regular Installment',
                currencyFormat.format(terms.installmentAmount)),
            const Divider(height: 20),
            _buildDetailRow('Monthly Interest Rate',
                '${terms.interestRate.toStringAsFixed(2)}%'),
            const Divider(height: 20),
            _buildDetailRow('Start Date', dateFormat.format(terms.startDate)),
            const Divider(height: 20),
            _buildDetailRow(
                'Maturity Date', dateFormat.format(terms.maturityDate)),
          ],
        ),
      ),
    );
  }

  Widget _buildNextPaymentCard(
    BorrowerNextInstallment nextInst,
    NumberFormat currencyFormat,
    DateFormat dateFormat,
  ) {
    final isOverdue = nextInst.status.toLowerCase() == 'overdue';

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Next Payment Preview',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isOverdue ? Colors.red.shade50 : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isOverdue ? 'OVERDUE' : 'UPCOMING',
                    style: TextStyle(
                      color: isOverdue
                          ? Colors.red.shade700
                          : Colors.blue.shade700,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _buildDetailRow(
                'Installment Number', '#${nextInst.installmentNumber}'),
            const Divider(height: 20),
            _buildDetailRow('Due Date', dateFormat.format(nextInst.dueDate)),
            const Divider(height: 20),
            _buildDetailRow(
                'Amount Due', currencyFormat.format(nextInst.remainingAmount),
                isBold: true),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    bool isBold = false,
    Color? color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: color ?? const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  Widget _buildSkeletonLoader() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          height: 120,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          height: 220,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(String status) {
    Color bg = Colors.blue.shade50;
    Color text = Colors.blue.shade700;
    String label = status.toUpperCase();

    if (status.toLowerCase() == 'active') {
      bg = Colors.green.shade50;
      text = Colors.green.shade700;
      label = 'ACTIVE';
    } else if (status.toLowerCase() == 'overdue') {
      bg = Colors.red.shade50;
      text = Colors.red.shade700;
      label = 'OVERDUE';
    } else if (status.toLowerCase() == 'paid') {
      bg = Colors.purple.shade50;
      text = Colors.purple.shade700;
      label = 'PAID';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style:
            TextStyle(color: text, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  String _formatFrequency(String freq) {
    switch (freq.toLowerCase()) {
      case 'monthly':
        return 'Monthly';
      case 'semi_monthly':
        return 'Semi-Monthly';
      case 'weekly':
        return 'Weekly';
      case 'daily':
        return 'Daily';
      default:
        return freq;
    }
  }

  Widget _buildInstallmentScheduleCard(
    LoanScheduleState scheduleState,
    NumberFormat currencyFormat,
    DateFormat dateFormat,
  ) {
    if (scheduleState.isLoading && scheduleState.schedule == null) {
      return Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final schedule = scheduleState.schedule;
    if (schedule == null || schedule.items.isEmpty) {
      return Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Padding(
          padding: EdgeInsets.all(20),
          child: Center(
            child: Text(
              'No installment schedule available.',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Installment Schedule',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${schedule.paidInstallmentsCount}/${schedule.totalInstallments} Paid',
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: schedule.items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = schedule.items[index];
                return _buildScheduleItemRow(item, currencyFormat, dateFormat);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleItemRow(
    BorrowerInstallmentItem item,
    NumberFormat currencyFormat,
    DateFormat dateFormat,
  ) {
    Color statusBg = Colors.grey.shade100;
    Color statusText = Colors.grey.shade700;
    String statusLabel = item.status.toUpperCase();

    final cleanStatus = item.status.toLowerCase();
    if (cleanStatus == 'paid') {
      statusBg = Colors.green.shade50;
      statusText = Colors.green.shade700;
      statusLabel = 'PAID';
    } else if (cleanStatus == 'overdue') {
      statusBg = Colors.red.shade50;
      statusText = Colors.red.shade700;
      statusLabel = 'OVERDUE';
    } else if (cleanStatus == 'partially_paid') {
      statusBg = Colors.amber.shade50;
      statusText = Colors.amber.shade800;
      statusLabel = 'PARTIAL';
    } else {
      statusBg = Colors.blue.shade50;
      statusText = Colors.blue.shade700;
      statusLabel = 'SCHEDULED';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    '#${item.installmentNumber}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    dateFormat.format(item.dueDate),
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusText,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Payment: ${currencyFormat.format(item.expectedPayment)}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
              ),
              Text(
                'Rem: ${currencyFormat.format(item.remainingBalance)}',
                style: TextStyle(
                  fontSize: 12,
                  color: item.remainingBalance > 0
                      ? const Color(0xFF64748B)
                      : Colors.green.shade700,
                  fontWeight: item.remainingBalance > 0
                      ? FontWeight.normal
                      : FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Principal: ${currencyFormat.format(item.expectedPrincipal)} • Interest: ${currencyFormat.format(item.expectedInterest)}',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentHistoryCard(
    BuildContext context,
    LoanPaymentsState paymentsState,
    NumberFormat currencyFormat,
    DateFormat dateFormat,
  ) {
    if (paymentsState.isLoading && paymentsState.history == null) {
      return Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final history = paymentsState.history;
    if (history == null || history.items.isEmpty) {
      return Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Padding(
          padding: EdgeInsets.all(20),
          child: Center(
            child: Text(
              'No payment transactions recorded yet.',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Payment History',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${history.totalCount} Payments',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: history.items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = history.items[index];
                return _buildPaymentItemRow(
                    context, item, currencyFormat, dateFormat);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentItemRow(
    BuildContext context,
    BorrowerPaymentListItem item,
    NumberFormat currencyFormat,
    DateFormat dateFormat,
  ) {
    final isReversed = item.status.toLowerCase() == 'reversed';

    return InkWell(
      onTap: () => ReceiptModal.show(context, item.id),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isReversed
                        ? Colors.red.shade50
                        : Colors.green.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isReversed
                        ? Icons.history_rounded
                        : Icons.receipt_long_rounded,
                    color: isReversed
                        ? Colors.red.shade700
                        : Colors.green.shade700,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.receiptNumber,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${dateFormat.format(item.effectiveDate)} • ${item.entryType.toUpperCase()}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Row(
              children: [
                Text(
                  currencyFormat.format(item.amount),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isReversed ? Colors.red.shade700 : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF94A3B8),
                  size: 20,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
