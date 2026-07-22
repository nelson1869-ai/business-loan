import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/formatters.dart';
import '../domain/models/installment.dart';
import '../domain/models/loan.dart';
import 'providers/loans_provider.dart';

/// Displays backend-owned loan totals and the persisted installment schedule.
class LoanDetailScreen extends ConsumerWidget {
  const LoanDetailScreen({super.key, required this.loanId, this.initialLoan});

  final String loanId;
  final Loan? initialLoan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(loanDetailProvider(loanId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Loan Details'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Share schedule',
            icon: const Icon(Icons.share_outlined),
            onPressed: () => _shareSchedule(context, ref),
          ),
          IconButton(
            tooltip: 'Refresh loan',
            onPressed: () => ref.invalidate(loanDetailProvider(loanId)),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: detail.when(
        loading: () => initialLoan == null
            ? const Center(child: CircularProgressIndicator())
            : _LoanContent(
                loan: initialLoan!,
                onRecordPayment: () => context.push('/loans/$loanId/payments'),
              ),
        error: (Object error, StackTrace stackTrace) => initialLoan == null
            ? Center(child: Text('Could not load loan: $error'))
            : _LoanContent(
                loan: initialLoan!,
                onRecordPayment: () => context.push('/loans/$loanId/payments'),
              ),
        data: (Loan loan) => _LoanContent(
          loan: loan,
          onRecordPayment: () => context.push('/loans/$loanId/payments'),
        ),
      ),
    );
  }

  Future<void> _shareSchedule(BuildContext context, WidgetRef ref) async {
    final loan = ref.read(loanDetailProvider(loanId)).valueOrNull;
    if (loan == null) return;

    final buf = StringBuffer()
      ..writeln('📋 Repayment Schedule — ${loan.status}')
      ..writeln('━━━━━━━━━━━━━━━━━━━━━━━')
      ..writeln('Principal: ${formatCurrency(loan.originalPrincipal)}')
      ..writeln('Outstanding: ${formatCurrency(loan.outstandingPrincipal)}')
      ..writeln('Rate: ${formatInterestRate(loan.monthlyRate)} / mo')
      ..writeln('First due: ${formatDateShort(loan.firstDueDate)}')
      ..writeln('Final due: ${formatDateShort(loan.finalDueDate)}')
      ..writeln('');

    if (loan.installments.isNotEmpty) {
      buf.writeln('Installments:');
      for (final inst in loan.installments) {
        buf.writeln(
          '  #${inst.installmentNumber} — ${formatDateShort(inst.dueDate)} — '
          '${formatCurrency(inst.expectedPayment)} — ${inst.status}',
        );
      }
    }

    final text = buf.toString();

    if (!context.mounted) return;
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ShareSheet(loan: loan, text: text),
    );
  }
}

class _ShareSheet extends StatelessWidget {
  const _ShareSheet({required this.loan, required this.text});

  final Loan loan;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final encoded = Uri.encodeComponent(text);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
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
          Text(
            'Share Schedule',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _ShareOption(
                  icon: Icons.chat,
                  label: 'WhatsApp',
                  color: const Color(0xFF25D366),
                  onTap: () {
                    Navigator.of(context).pop();
                    _launch('https://wa.me/?text=$encoded');
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ShareOption(
                  icon: Icons.sms_outlined,
                  label: 'SMS',
                  color: Colors.blue,
                  onTap: () {
                    Navigator.of(context).pop();
                    _launch('sms:?body=$encoded');
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _ShareOption extends StatelessWidget {
  const _ShareOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: color.withValues(alpha: 0.4)),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _LoanContent extends StatelessWidget {
  const _LoanContent({required this.loan, required this.onRecordPayment});

  final Loan loan;
  final VoidCallback onRecordPayment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = double.tryParse(loan.originalPrincipal) ?? 0;
    final outstanding = double.tryParse(loan.outstandingPrincipal) ?? 0;
    final paid = total - outstanding;
    final percentPaidOff = total > 0 ? (paid / total * 100) : 0.0;

    final nextDue = _findNextDue();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: [
                    Text(loan.status, style: theme.textTheme.titleLarge),
                    const Spacer(),
                    Text(
                      '${percentPaidOff.round()}% Paid Off',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: percentPaidOff / 100,
                    minHeight: 8,
                    backgroundColor: theme.colorScheme.error.withValues(
                      alpha: 0.15,
                    ),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      percentPaidOff >= 100
                          ? Colors.green
                          : theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${formatCurrency(paid.toStringAsFixed(2))} Paid · '
                  '${formatCurrency(outstanding.toStringAsFixed(2))} Remaining',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 12),
                _SummaryRow(
                  label: 'Original principal',
                  value: formatCurrency(loan.originalPrincipal),
                ),
                _SummaryRow(
                  label: 'Outstanding principal',
                  value: formatCurrency(loan.outstandingPrincipal),
                ),
                _SummaryRow(
                  label: 'Monthly rate',
                  value: '${formatInterestRate(loan.monthlyRate)} / mo',
                ),
                _SummaryRow(
                  label: 'Payment frequency',
                  value: loan.paymentsPerMonth == 1
                      ? 'Once a month'
                      : '${loan.paymentsPerMonth} times a month',
                ),
                _SummaryRow(
                  label: 'First due date',
                  value: formatDateShort(loan.firstDueDate),
                ),
                _SummaryRow(
                  label: 'Final due date',
                  value: formatDateShort(loan.finalDueDate),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (nextDue != null)
          _NextDueCard(
            installment: nextDue,
            canPay: loan.status == 'Active' || loan.status == 'Overdue',
            onRecordPayment: onRecordPayment,
          ),
        const SizedBox(height: 16),
        Text('Installment Schedule', style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        if (loan.installments.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No installment schedule was returned.'),
            ),
          )
        else
          ...loan.installments.map(
            (Installment installment) => Card(
              child: ExpansionTile(
                title: Text(
                  'Payment ${installment.installmentNumber} · '
                  '${formatCurrency(installment.expectedPayment)}',
                ),
                subtitle: Text(
                  '${formatDateShort(installment.dueDate)} · ${installment.status}',
                ),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _SummaryRow(
                    label: 'Interest',
                    value: formatCurrency(installment.expectedInterest),
                  ),
                  _SummaryRow(
                    label: 'Principal',
                    value: formatCurrency(installment.expectedPrincipal),
                  ),
                  _SummaryRow(
                    label: 'Remaining principal',
                    value: formatCurrency(
                      installment.expectedRemainingPrincipal,
                    ),
                  ),
                  _SummaryRow(
                    label: 'Paid',
                    value: formatCurrency(installment.paidAmount),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Installment? _findNextDue() {
    Installment? candidate;
    for (final inst in loan.installments) {
      final paidAmt = double.tryParse(inst.paidAmount) ?? 0;
      final expectedAmt = double.tryParse(inst.expectedPayment) ?? 0;
      if (paidAmt < expectedAmt || inst.status != 'Paid') {
        if (candidate == null ||
            inst.installmentNumber < candidate.installmentNumber) {
          candidate = inst;
        }
      }
    }
    return candidate;
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _NextDueCard extends StatelessWidget {
  const _NextDueCard({
    required this.installment,
    required this.canPay,
    required this.onRecordPayment,
  });

  final Installment installment;
  final bool canPay;
  final VoidCallback onRecordPayment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final expected = double.tryParse(installment.expectedPayment) ?? 0;
    final paid = double.tryParse(installment.paidAmount) ?? 0;
    final remaining = expected - paid;
    final isOverdue = installment.status == 'Overdue';

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isOverdue
              ? Colors.red.withValues(alpha: 0.4)
              : theme.colorScheme.primary.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isOverdue
              ? Colors.red.withValues(alpha: 0.04)
              : theme.colorScheme.primary.withValues(alpha: 0.04),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isOverdue
                      ? Icons.warning_amber_rounded
                      : Icons.event_note_outlined,
                  size: 18,
                  color: isOverdue ? Colors.red : theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  isOverdue ? 'Overdue Payment' : 'Next Payment Due',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isOverdue ? Colors.red : theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formatDateShort(installment.dueDate),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Payment #${installment.installmentNumber}',
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatCurrency(remaining.toStringAsFixed(2)),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isOverdue
                            ? Colors.red
                            : theme.colorScheme.primary,
                      ),
                    ),
                    Text(
                      'Expected Due',
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (isOverdue) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 16,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Payment Overdue — Immediate Collection Recommended',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade300,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: canPay ? onRecordPayment : null,
              icon: const Icon(Icons.add_card, size: 18),
              label: Text(isOverdue ? 'Pay Overdue Now' : 'Record Payment'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(40),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
