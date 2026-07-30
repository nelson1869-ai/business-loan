import '../../../core/utils/formatters.dart';
import '../../loans/domain/models/installment.dart';
import 'borrower_communication_context.dart';

/// Pure borrower-safe message templates backed by persisted domain snapshots.
class BorrowerMessageTemplateService {
  const BorrowerMessageTemplateService();

  String paymentReminder(
    BorrowerCommunicationContext context, {
    DateTime? now,
  }) {
    final loan = context.loan;
    final installment = loan == null
        ? null
        : _nextInstallment(loan.installments);
    if (loan == null || installment == null) return '';
    final due = DateTime.tryParse(installment.dueDate);
    final overdue =
        due != null && due.isBefore(_dateOnly(now ?? DateTime.now()));
    final amount = formatCurrency(installment.expectedPayment);
    final balance = formatCurrency(loan.outstandingPrincipal);
    if (overdue) {
      return 'Hello ${_firstName(context)},\n\n'
          'Your payment of $amount, due on ${formatDateShort(installment.dueDate)}, '
          'is currently overdue.\n\n'
          'Outstanding amount: $amount.\n'
          'Remaining loan balance: $balance.\n\n'
          'Please contact us if you have already paid or need assistance.\n\n'
          'Thank you,\nLending Nelson';
    }
    return 'Hello ${_firstName(context)},\n\n'
        'This is a reminder that your payment of $amount is due on '
        '${formatDateShort(installment.dueDate)}.\n\n'
        'Remaining loan balance: $balance.\n\n'
        'Please disregard this reminder if payment has already been made.\n\n'
        'Thank you,\nLending Nelson';
  }

  String loanSummary(BorrowerCommunicationContext context) {
    final loan = context.loan;
    if (loan == null) return '';
    final next = _nextInstallment(loan.installments);
    final rows = <String>[
      'Loan amount: ${formatCurrency(loan.originalPrincipal)}',
      'Remaining balance: ${formatCurrency(loan.outstandingPrincipal)}',
      if (next != null) 'Next payment: ${formatCurrency(next.expectedPayment)}',
      if (next != null) 'Due date: ${formatDateShort(next.dueDate)}',
    ];
    return 'Hello ${_firstName(context)},\n\n'
        'Here is your current loan summary:\n\n'
        '${rows.join('\n')}\n\nThank you,\nLending Nelson';
  }

  String paymentReceipt(BorrowerCommunicationContext context) {
    final payment = context.payment;
    if (payment == null) return '';
    return 'Payment received.\n\n'
        'Borrower: ${context.borrower.fullName}\n'
        'Amount paid: ${formatCurrency(payment.amount)}\n'
        'Payment date: ${formatDateShort(payment.effectiveDate)}\n'
        'Reference number: ${payment.requestId}\n'
        'Remaining balance: ${formatCurrency(payment.allocation.principalAfter)}'
        '\n\nThank you,\nLending Nelson';
  }

  String scheduleSummary(
    BorrowerCommunicationContext context, {
    int limit = 5,
  }) {
    final loan = context.loan;
    if (loan == null) return '';
    final relevant = loan.installments
        .where((item) => item.status != 'Paid' && item.status != 'Cancelled')
        .take(limit)
        .map(
          (item) =>
              '#${item.installmentNumber}: ${formatDateShort(item.dueDate)} — '
              '${formatCurrency(item.expectedPayment)} (${item.status})',
        )
        .toList();
    if (relevant.isEmpty) return '';
    return 'Hello ${_firstName(context)},\n\n'
        'Your payment schedule is:\n\n${relevant.join('\n')}\n\n'
        'Remaining balance: ${formatCurrency(loan.outstandingPrincipal)}\n\n'
        'Thank you,\nLending Nelson';
  }

  Installment? _nextInstallment(List<Installment> installments) {
    for (final item in installments) {
      if (item.status != 'Paid' && item.status != 'Cancelled') return item;
    }
    return null;
  }

  String _firstName(BorrowerCommunicationContext context) {
    final value = context.borrower.firstName.trim();
    return value.isEmpty ? 'Borrower' : value;
  }

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
