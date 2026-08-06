import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

class PaymentSuccessDialog extends StatelessWidget {
  const PaymentSuccessDialog({
    required this.receiptNumber,
    required this.amountReceived,
    required this.remainingBalance,
    required this.onViewReceipt,
    super.key,
  });

  final String receiptNumber;
  final String amountReceived;
  final String remainingBalance;
  final VoidCallback onViewReceipt;

  void _shareReceiptText() {
    final text = '''
OFFICIAL PAYMENT RECEIPT
------------------------
Receipt No: $receiptNumber
Amount Paid: $amountReceived
Remaining Balance: $remainingBalance
Thank you for your payment!
''';
    SharePlus.instance.share(ShareParams(text: text, subject: 'Payment Receipt - $receiptNumber'));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Column(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: Colors.green,
            size: 56,
          ),
          const SizedBox(height: 12),
          Text(
            'Payment Recorded Successfully',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDetailRow(context, 'Receipt Number', receiptNumber, isBold: true),
            const Divider(height: 16),
            _buildDetailRow(context, 'Amount Received', amountReceived, color: Colors.green.shade700),
            const SizedBox(height: 8),
            _buildDetailRow(context, 'Remaining Balance', remainingBalance, isBold: true),
          ],
        ),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      onViewReceipt();
                    },
                    icon: const Icon(Icons.receipt_long, size: 18),
                    label: const Text('View Receipt'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _shareReceiptText,
                    icon: const Icon(Icons.share, size: 18),
                    label: const Text('Share Receipt'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    String label,
    String value, {
    bool isBold = false,
    Color? color,
  }) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: color,
          ),
        ),
      ],
    );
  }
}
