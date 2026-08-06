import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:borrower_mobile/features/payments/models/borrower_payment.dart';
import 'package:borrower_mobile/features/payments/providers/payments_provider.dart';

class ReceiptModal extends ConsumerStatefulWidget {
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
  ConsumerState<ReceiptModal> createState() => _ReceiptModalState();
}

class _ReceiptModalState extends ConsumerState<ReceiptModal> {
  bool _isRequestingAi = false;
  String? _aiExplanationText;

  Future<void> _fetchAiExplanation() async {
    setState(() {
      _isRequestingAi = true;
    });
    try {
      final repository = ref.read(paymentRepositoryProvider);
      final explanation = await repository.fetchAiExplanation(widget.paymentId);
      if (mounted) {
        setState(() {
          _aiExplanationText = explanation;
          _isRequestingAi = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRequestingAi = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load AI explanation: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(paymentReceiptNotifierProvider(widget.paymentId));
    final currencyFormat = NumberFormat.currency(symbol: '₱ ', decimalDigits: 2);
    final dateFormat = DateFormat('MMM dd, yyyy');

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
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
          const SizedBox(height: 12),
          Expanded(
            child: state.isLoading && state.receipt == null
                ? const Center(child: CircularProgressIndicator())
                : state.errorMessage != null && state.receipt == null
                    ? Center(
                        child: Text(
                          state.errorMessage!,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      )
                    : state.receipt != null
                        ? _build8Sections(
                            context,
                            state.receipt!,
                            currencyFormat,
                            dateFormat,
                          )
                        : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _build8Sections(
    BuildContext context,
    BorrowerReceiptDetail receipt,
    NumberFormat currencyFormat,
    DateFormat dateFormat,
  ) {
    final isReversed = receipt.status.toLowerCase() == 'reversed';
    final aiText = _aiExplanationText ?? receipt.aiExplanation;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section 1: Payment Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Official Payment Receipt',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF64748B),
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
                    color: isReversed ? Colors.red.shade700 : Colors.green.shade700,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Total Amount Received Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                const Text(
                  'Amount Received',
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
                  'Payment Date: ${dateFormat.format(receipt.paymentDate)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Section 2: Loan Summary
          _buildSectionHeader('Loan Reference & Summary'),
          const SizedBox(height: 8),
          _buildRow('Loan Ref', receipt.loanReference),
          _buildRow('Loan ID', receipt.loanId.substring(0, receipt.loanId.length > 8 ? 8 : receipt.loanId.length)),
          const Divider(height: 20),

          // Section 3: Deterministic Payment Allocation Breakdown
          _buildSectionHeader('Payment Allocation Breakdown'),
          const SizedBox(height: 8),
          _buildRow('Principal Applied', currencyFormat.format(receipt.principalPaid)),
          _buildRow('Interest Applied', currencyFormat.format(receipt.interestPaid)),
          _buildRow('Penalty Applied', currencyFormat.format(receipt.penaltyPaid)),
          _buildRow('Fees Applied', currencyFormat.format(receipt.feesPaid)),
          _buildRow('Unapplied Credit', currencyFormat.format(receipt.unappliedCredit)),
          const Divider(height: 20),

          // Section 4: Balance Impact
          _buildSectionHeader('Balance Impact'),
          const SizedBox(height: 8),
          _buildRow('Balance Before Payment', currencyFormat.format(receipt.balanceBeforePayment)),
          _buildRow('Principal Paid', currencyFormat.format(receipt.principalPaid)),
          _buildRow(
            'Remaining Balance',
            currencyFormat.format(receipt.remainingBalance),
            isBold: true,
          ),
          const Divider(height: 20),

          // Section 5: Next Scheduled Payment
          _buildSectionHeader('Next Scheduled Payment'),
          const SizedBox(height: 8),
          if (receipt.nextDueDate != null) ...[
            _buildRow('Next Due Date', dateFormat.format(receipt.nextDueDate!)),
            _buildRow(
              'Next Amount Due',
              receipt.nextPaymentAmount != null
                  ? currencyFormat.format(receipt.nextPaymentAmount)
                  : 'N/A',
            ),
          ] else ...[
            const Text(
              'No upcoming payments scheduled.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
          const Divider(height: 20),

          // Section 6: Plain-Language Financial Explanation
          _buildSectionHeader('Financial Explanation'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              receipt.deterministicExplanation ??
                  'Payment of ${currencyFormat.format(receipt.amountReceived)} was allocated to principal and interest according to terms.',
              style: TextStyle(fontSize: 13, color: Colors.blue.shade900, height: 1.4),
            ),
          ),
          const SizedBox(height: 8),
          if (aiText != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.auto_awesome, size: 16, color: Colors.purple.shade700),
                      const SizedBox(width: 6),
                      Text(
                        'AI Explanation',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple.shade900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    aiText,
                    style: TextStyle(fontSize: 13, color: Colors.purple.shade900, height: 1.4),
                  ),
                ],
              ),
            ),
          ] else ...[
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _isRequestingAi ? null : _fetchAiExplanation,
                icon: _isRequestingAi
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome, size: 16),
                label: const Text('Explain with AI'),
              ),
            ),
          ],
          const Divider(height: 20),

          // Section 7: Verification Section
          _buildSectionHeader('Public Receipt Verification'),
          const SizedBox(height: 8),
          if (receipt.verificationToken != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Verification Token:',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  SelectableText(
                    receipt.verificationToken!,
                    style: const TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),

          // Section 8: Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Downloading PDF Receipt...')),
                    );
                  },
                  icon: const Icon(Icons.picture_as_pdf, size: 18),
                  label: const Text('Save PDF'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: Color(0xFF1E293B),
      ),
    );
  }

  Widget _buildRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
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
      ),
    );
  }
}
