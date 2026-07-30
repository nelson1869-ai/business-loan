import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/notifications/local_notification_service.dart';
import '../../loans/data/repositories/local_loan_repository.dart';
import '../../loans/domain/models/installment.dart';
import '../../loans/domain/models/loan.dart';

enum OfficerDueReminderStage { approaching, dueToday, overdue }

/// Schedules privacy-safe officer alerts from locally persisted schedules.
class BorrowerDueReminderScheduler {
  const BorrowerDueReminderScheduler(
    this._loans,
    this._notifications, {
    this.now,
  });

  final LocalLoanRepository _loans;
  final LocalNotificationService _notifications;
  final DateTime Function()? now;

  /// Refreshes reminders without requiring network access or changing sync data.
  Future<void> refresh() async {
    final current = now?.call() ?? DateTime.now();
    final loans = await _loans.getLoans();
    for (final loan in loans) {
      final nextInstallment = loan.installments
          .where(_isOpenInstallment)
          .firstOrNull;
      for (final installment in loan.installments) {
        await _cancelAll(loan, installment);
        if (!_isOpenLoan(loan) || installment.id != nextInstallment?.id) {
          continue;
        }
        final dueDate = DateTime.tryParse(installment.dueDate);
        if (dueDate == null) continue;
        final daysUntilDue = _dateOnly(
          dueDate,
        ).difference(_dateOnly(current)).inDays;
        if (daysUntilDue < 0) {
          await _scheduleStage(
            loan,
            installment,
            OfficerDueReminderStage.overdue,
            current.add(const Duration(seconds: 5)),
            current,
          );
          continue;
        }
        if (daysUntilDue > 0) {
          await _scheduleStage(
            loan,
            installment,
            OfficerDueReminderStage.approaching,
            daysUntilDue <= 3
                ? current.add(const Duration(seconds: 5))
                : _atNine(dueDate.subtract(const Duration(days: 3))),
            current,
          );
        }
        await _scheduleStage(
          loan,
          installment,
          OfficerDueReminderStage.dueToday,
          daysUntilDue == 0
              ? current.add(const Duration(seconds: 10))
              : _atNine(dueDate),
          current,
        );
        await _scheduleStage(
          loan,
          installment,
          OfficerDueReminderStage.overdue,
          _atNine(dueDate.add(const Duration(days: 1))),
          current,
        );
      }
    }
  }

  /// Schedules a one-day follow-up selected explicitly by the officer.
  Future<void> snooze(Loan loan) async {
    final current = now?.call() ?? DateTime.now();
    await _notifications.schedule(
      id: _stableId('${loan.id}:manual-snooze'),
      title: 'Payment follow-up reminder',
      body: 'A borrower follow-up is ready for your review.',
      at: current.add(const Duration(days: 1)),
      navigationPath: '/loans/${loan.id}/send',
      category: ReminderCategory.payments,
    );
  }

  Future<void> _scheduleStage(
    Loan loan,
    Installment installment,
    OfficerDueReminderStage stage,
    DateTime at,
    DateTime current,
  ) async {
    if (!at.isAfter(current)) return;
    final (title, body, category) = switch (stage) {
      OfficerDueReminderStage.approaching => (
        'Payment approaching',
        'A scheduled payment is due in 3 days. Review the borrower reminder.',
        ReminderCategory.payments,
      ),
      OfficerDueReminderStage.dueToday => (
        'Payment due today',
        'A scheduled payment is due today. Review before contacting the borrower.',
        ReminderCategory.payments,
      ),
      OfficerDueReminderStage.overdue => (
        'Payment follow-up',
        'A scheduled payment is overdue. Review the account before contacting the borrower.',
        ReminderCategory.overdue,
      ),
    };
    await _notifications.schedule(
      id: _id(loan, installment, stage),
      title: title,
      body: body,
      at: at,
      navigationPath: '/loans/${loan.id}/send',
      category: category,
    );
  }

  Future<void> _cancelAll(Loan loan, Installment installment) async {
    for (final stage in OfficerDueReminderStage.values) {
      await _notifications.cancel(_id(loan, installment, stage));
    }
  }

  int _id(Loan loan, Installment installment, OfficerDueReminderStage stage) =>
      _stableId('${loan.id}:${installment.id}:${stage.name}');

  int _stableId(String value) {
    var hash = 0x811c9dc5;
    for (final codeUnit in value.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }

  DateTime _atNine(DateTime date) =>
      DateTime(date.year, date.month, date.day, 9);
  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);
  bool _isOpenLoan(Loan loan) =>
      loan.status == 'Active' || loan.status == 'Overdue';
  bool _isOpenInstallment(Installment installment) =>
      installment.status != 'Paid' && installment.status != 'Cancelled';
}

final borrowerDueReminderSchedulerProvider =
    Provider<BorrowerDueReminderScheduler>((ref) {
      return BorrowerDueReminderScheduler(
        ref.watch(localLoanRepositoryProvider),
        ref.watch(localNotificationServiceProvider),
      );
    });
