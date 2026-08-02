import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:borrower_mobile/features/payments/models/borrower_payment.dart';
import 'package:borrower_mobile/features/payments/providers/payments_provider.dart';

class ReceiptModal extends ConsumerWidget {
  final String paymentId;

  const ReceiptModal({
    super.key,
    required this.paymentId,
  });

  static void show(BuildContext context, String paymentId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ReceiptModal(paymentId: paymentId),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(paymentReceiptNotifierProvider(paymentId));
    final currencyFormat =
        NumberFormat.currency(symbol: '₱ ', decimalDigits: 2);
    final dateFormat = DateFormat('MMM dd, yyyy');

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (state.isLoading && state.receipt == null)
              const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (state.errorMessage != null && state.receipt == null)
              SizedBox(
                height: 200,
                child: Center(
                  child: Text(
                    state.errorMessage!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),
              )
            else if (state.receipt != null)
              _buildReceiptContent(
                context,
                state.receipt!,
                currencyFormat,
                dateFormat,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptContent(
    BuildContext context,
    BorrowerReceiptDetail receipt,
    NumberFormat currencyFormat,
    DateFormat dateFormat,
  ) {
    final isReversed = receipt.status.toLowerCase() == 'reversed';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Official Receipt',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF64748B),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  receipt.receiptNumber,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isReversed ? Colors.red.shade50 : Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                receipt.status.toUpperCase(),
                style: TextStyle(
                  color:
                      isReversed ? Colors.red.shade700 : Colors.green.shade700,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Total Paid Amount Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              const Text(
                'Amount Paid',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 4),
              Text(
                currencyFormat.format(receipt.amountReceived),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Date: ${dateFormat.format(receipt.paymentDate)} • ${receipt.loanReference}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),
        const Text(
          'Allocation Breakdown',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 12),

        _buildAllocationRow(
            'Principal Applied', currencyFormat.format(receipt.principalPaid)),
        const Divider(height: 16),
        _buildAllocationRow(
            'Interest Applied', currencyFormat.format(receipt.interestPaid)),
        const Divider(height: 16),
        _buildAllocationRow(
            'Penalty Applied', currencyFormat.format(receipt.penaltyPaid)),
        const Divider(height: 16),
        _buildAllocationRow('Unapplied Credit',
            currencyFormat.format(receipt.unappliedCredit)),
        const Divider(height: 16),
        _buildAllocationRow(
          'Remaining Principal Balance',
          currencyFormat.format(receipt.remainingBalance),
          isBold: true,
        ),

        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Close Receipt'),
          ),
        ),
      ],
    );
  }

  Widget _buildAllocationRow(String label, String value, {bool isBold = false}) {
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
            fontSize: 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }
}
