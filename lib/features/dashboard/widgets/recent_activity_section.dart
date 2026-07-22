import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/formatters.dart';
import '../../loans/data/repositories/remote_payment_repository.dart';
import '../../loans/domain/models/payment.dart';
import '../domain/dashboard_data.dart';

class RecentActivitySection extends ConsumerWidget {
  const RecentActivitySection({super.key, required this.activities});

  final List<DashboardRecentActivity> activities;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            'Recent Activity',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (activities.isEmpty)
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Text(
                  'No recent activity',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
          )
        else
          ...activities.map((item) => _ActivityTile(item: item)),
      ],
    );
  }
}

class _ActivityTile extends ConsumerWidget {
  const _ActivityTile({required this.item});

  final DashboardRecentActivity item;

  String _displayTitle(String name, String borrowerId) {
    final trimmed = name.trim();
    if (trimmed.contains('-') && trimmed.length >= 20) {
      final shortId = borrowerId.length >= 8
          ? borrowerId.substring(0, 8)
          : borrowerId;
      return 'Borrower #$shortId';
    }
    return trimmed;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isReversal = item.entryType == 'Reversal';
    final dateStr = formatRelativeDate(item.effectiveDate);

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        dense: true,
        onTap: () => _showReceipt(context, ref),
        leading: CircleAvatar(
          radius: 16,
          backgroundColor: isReversal
              ? Colors.orange.withValues(alpha: 0.1)
              : Colors.green.withValues(alpha: 0.1),
          child: Icon(
            isReversal ? Icons.undo : Icons.payments_outlined,
            size: 16,
            color: isReversal ? Colors.orange : Colors.green,
          ),
        ),
        title: Text(
          _displayTitle(item.borrowerName, item.borrowerId),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          dateStr,
          style: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
        trailing: Text(
          isReversal ? '-\$${item.amount}' : '+\$${item.amount}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isReversal ? Colors.orange : theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }

  Future<void> _showReceipt(BuildContext context, WidgetRef ref) async {
    LoanPayment? match;
    try {
      final payments = await ref
          .read(remotePaymentRepositoryProvider)
          .history(item.loanId);
      match = payments.cast<LoanPayment?>().firstWhere(
        (p) =>
            p!.amount == item.amount && p.effectiveDate == item.effectiveDate,
        orElse: () => null,
      );
    } catch (_) {}

    if (!context.mounted) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ReceiptDetailsModal(activity: item, payment: match),
    );
  }
}

class _ReceiptDetailsModal extends StatelessWidget {
  const _ReceiptDetailsModal({required this.activity, required this.payment});

  final DashboardRecentActivity activity;
  final LoanPayment? payment;

  String _maskLoanId(String id) {
    if (id.length <= 12) return id;
    return '${id.substring(0, 8)}...${id.substring(id.length - 4)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isReversal = activity.entryType == 'Reversal';
    final dt = DateTime.tryParse(activity.effectiveDate);
    final formattedDate = dt != null
        ? '${dt.month}/${dt.day}/${dt.year}'
        : activity.effectiveDate;
    final formattedTime = dt != null
        ? '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'
        : '--:--';

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isReversal
                          ? Colors.orange.withValues(alpha: 0.12)
                          : Colors.green.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isReversal ? Icons.undo : Icons.payments_outlined,
                      color: isReversal ? Colors.orange : Colors.green,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isReversal ? 'Reversal' : 'Payment',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '$formattedDate at $formattedTime',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _DetailRow(label: 'Borrower', value: activity.borrowerName),
              _DetailRow(label: 'Loan ID', value: _maskLoanId(activity.loanId)),
              const Divider(height: 24),
              _DetailRow(
                label: 'Total Amount',
                value: isReversal
                    ? '-${formatCurrency(activity.amount)}'
                    : '+${formatCurrency(activity.amount)}',
                valueStyle: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isReversal
                      ? theme.colorScheme.error
                      : Colors.green.shade700,
                ),
              ),
              if (payment != null) ...[
                const SizedBox(height: 4),
                _DetailRow(
                  label: 'Applied Principal',
                  value: formatCurrency(payment!.allocation.appliedPrincipal),
                ),
                _DetailRow(
                  label: 'Applied Interest',
                  value: formatCurrency(payment!.allocation.appliedInterest),
                ),
                _DetailRow(
                  label: 'Unapplied Credit',
                  value: formatCurrency(payment!.allocation.unappliedCredit),
                ),
              ],
              if (payment?.note != null &&
                  payment!.note!.trim().isNotEmpty) ...[
                const Divider(height: 24),
                _DetailRow(label: 'Note', value: payment!.note!),
              ],
              const SizedBox(height: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      context.push('/loans/${activity.loanId}/payments');
                    },
                    icon: const Icon(Icons.receipt_long, size: 18),
                    label: const Text('View Loan Payments'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value, this.valueStyle});

  final String label;
  final String value;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style:
                  valueStyle ??
                  TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
