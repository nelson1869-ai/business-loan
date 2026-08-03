import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:borrower_mobile/features/loans/providers/loans_provider.dart';
import 'package:borrower_mobile/features/payments/providers/payments_provider.dart';
import 'package:borrower_mobile/features/payments/receipt_modal.dart';

class PaymentsScreen extends ConsumerWidget {
  const PaymentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loansState = ref.watch(loansListNotifierProvider);
    final currencyFormat =
        NumberFormat.currency(symbol: '₱ ', decimalDigits: 2);
    final dateFormat = DateFormat('MMM dd, yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Payments'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref
              .read(loansListNotifierProvider.notifier)
              .loadLoans(isRefresh: true);
        },
        child: _buildBody(context, ref, loansState, currencyFormat, dateFormat),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    LoansListState state,
    NumberFormat currencyFormat,
    DateFormat dateFormat,
  ) {
    if (state.isLoading && state.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.errorMessage != null && state.items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline,
                    color: Colors.redAccent, size: 48),
                const SizedBox(height: 16),
                const Text('Failed to load payments',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(state.errorMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600])),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => ref
                      .read(loansListNotifierProvider.notifier)
                      .loadLoans(isRefresh: true),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (state.items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Color(0xFFEFF6FF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.receipt_long_rounded,
                    size: 40,
                    color: Color(0xFF2563EB),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'No Payments Recorded Yet',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your official payment receipts and installment breakdown will appear here once loan payments are posted.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: () => ref
                      .read(loansListNotifierProvider.notifier)
                      .loadLoans(isRefresh: true),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Refresh Payments'),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Payment Receipts by Loan',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 12),
        ...state.items.map((loan) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _LoanPaymentsSummaryCard(
              loanId: loan.id,
              loanReference: loan.loanReference,
              currencyFormat: currencyFormat,
              dateFormat: dateFormat,
            ),
          );
        }),
      ],
    );
  }
}

class _LoanPaymentsSummaryCard extends ConsumerWidget {
  final String loanId;
  final String loanReference;
  final NumberFormat currencyFormat;
  final DateFormat dateFormat;

  const _LoanPaymentsSummaryCard({
    required this.loanId,
    required this.loanReference,
    required this.currencyFormat,
    required this.dateFormat,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentsState = ref.watch(loanPaymentsNotifierProvider(loanId));

    if (paymentsState.isLoading && paymentsState.history == null) {
      return Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final history = paymentsState.history;
    final items = history?.items ?? [];

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
                Text(
                  loanReference,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
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
                    '${items.length} Payments',
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
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No transactions recorded for this loan.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final isReversed = item.status.toLowerCase() == 'reversed';

                  return InkWell(
                    onTap: () => ReceiptModal.show(context, item.id),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isReversed
                                    ? Icons.history_rounded
                                    : Icons.receipt_long_rounded,
                                color: isReversed
                                    ? Colors.red.shade700
                                    : Colors.green.shade700,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.receiptNumber,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  Text(
                                    dateFormat.format(item.effectiveDate),
                                    style: const TextStyle(
                                      fontSize: 11,
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
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: isReversed
                                      ? Colors.red.shade700
                                      : const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: Color(0xFF94A3B8),
                                size: 18,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
