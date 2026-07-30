import 'dart:math';

class LoanCalculationException implements Exception {
  const LoanCalculationException(this.message);
  final String message;

  @override
  String toString() => 'LoanCalculationException: $message';
}

/// Payment allocation result matching backend PaymentAllocation dataclass.
class LoanPaymentAllocation {
  const LoanPaymentAllocation({
    required this.paymentAmount,
    required this.appliedToInterest,
    required this.appliedToPrincipal,
    required this.unappliedCredit,
    required this.remainingInterest,
    required this.remainingPrincipal,
  });

  final String paymentAmount;
  final String appliedToInterest;
  final String appliedToPrincipal;
  final String unappliedCredit;
  final String remainingInterest;
  final String remainingPrincipal;
}

/// One scheduled installment matching backend Installment dataclass.
class ScheduledInstallment {
  const ScheduledInstallment({
    required this.number,
    required this.paymentAmount,
    required this.interestAmount,
    required this.principalAmount,
    required this.remainingPrincipal,
  });

  final int number;
  final String paymentAmount;
  final String interestAmount;
  final String principalAmount;
  final String remainingPrincipal;
}

/// Date-sensitive interest and payoff quote for the active loan period.
class LoanPayoffQuote {
  const LoanPayoffQuote({
    required this.interestDue,
    required this.payoffAmount,
    required this.elapsedDays,
    required this.scheduledPeriodDays,
    required this.daysEarly,
    required this.overdueDays,
  });

  final String interestDue;
  final String payoffAmount;
  final int elapsedDays;
  final int scheduledPeriodDays;
  final int daysEarly;
  final int overdueDays;
}

/// Pure Dart financial calculation engine with exact cent precision (ROUND_HALF_UP).
class LoanCalculator {
  /// Converts string money format "123.45" to integer cents.
  static int parseCents(String value, String fieldName) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw LoanCalculationException('$fieldName must not be empty');
    }
    final match = RegExp(r'^([0-9]+)(?:\.([0-9]{1,2}))?$').firstMatch(trimmed);
    if (match == null) {
      throw LoanCalculationException('$fieldName must be a valid number');
    }
    final whole = int.tryParse(match.group(1)!);
    if (whole == null || whole > 92233720368547758) {
      throw LoanCalculationException('$fieldName is too large');
    }
    final fraction = (match.group(2) ?? '').padRight(2, '0');
    return whole * 100 + (fraction.isEmpty ? 0 : int.parse(fraction));
  }

  /// Formats integer cents to standard money string "123.45".
  static String formatCents(int cents) {
    final absCents = cents.abs();
    final dollars = absCents ~/ 100;
    final remainder = absCents % 100;
    final sign = cents < 0 ? '-' : '';
    return '$sign$dollars.${remainder.toString().padLeft(2, '0')}';
  }

  /// Round a double value to nearest integer cent using ROUND_HALF_UP logic.
  static int roundHalfUp(double centsFloat) {
    if (centsFloat.isNaN || centsFloat.isInfinite) {
      throw const LoanCalculationException('Invalid calculation value');
    }
    if (centsFloat >= 0) {
      return (centsFloat + 0.5).floor();
    } else {
      return (centsFloat - 0.5).ceil();
    }
  }

  /// Calculate periodic interest in cents for an outstanding principal and rate.
  static int calculatePeriodInterestCents(
    int principalCents,
    double periodicRate,
  ) {
    if (principalCents < 0) {
      throw const LoanCalculationException(
        'outstanding_principal must not be negative',
      );
    }
    if (periodicRate < 0 || !periodicRate.isFinite) {
      throw const LoanCalculationException(
        'periodic_rate must be a finite non-negative rate',
      );
    }
    return roundHalfUp(principalCents * periodicRate);
  }

  /// Calculate period interest string.
  static String calculatePeriodInterest(
    String outstandingPrincipal,
    double periodicRate,
  ) {
    final principalCents = parseCents(
      outstandingPrincipal,
      'outstandingPrincipal',
    );
    final interestCents = calculatePeriodInterestCents(
      principalCents,
      periodicRate,
    );
    return formatCents(interestCents);
  }

  /// Calculate prorated interest for irregular partial periods.
  static String calculateProratedInterest({
    required String outstandingPrincipal,
    required double periodicRate,
    required int elapsedDays,
    required int scheduledPeriodDays,
  }) {
    final principalCents = parseCents(
      outstandingPrincipal,
      'outstandingPrincipal',
    );
    if (periodicRate < 0 || !periodicRate.isFinite) {
      throw const LoanCalculationException(
        'periodicRate must be a non-negative finite rate',
      );
    }
    if (elapsedDays < 0) {
      throw const LoanCalculationException('elapsedDays must not be negative');
    }
    if (scheduledPeriodDays <= 0) {
      throw const LoanCalculationException(
        'scheduledPeriodDays must be positive',
      );
    }

    final dayFraction = elapsedDays / scheduledPeriodDays;
    final interestCents = roundHalfUp(
      principalCents * periodicRate * dayFraction,
    );
    return formatCents(interestCents);
  }

  /// Allocates payment to interest, principal, and credit.
  static LoanPaymentAllocation allocatePayment({
    required String paymentAmount,
    required String interestDue,
    required String outstandingPrincipal,
  }) {
    final pCents = parseCents(paymentAmount, 'paymentAmount');
    final iCents = parseCents(interestDue, 'interestDue');
    final prCents = parseCents(outstandingPrincipal, 'outstandingPrincipal');

    final appliedInterest = min(pCents, iCents);
    final afterInterest = pCents - appliedInterest;
    final appliedPrincipal = min(afterInterest, prCents);
    final unappliedCredit = afterInterest - appliedPrincipal;

    return LoanPaymentAllocation(
      paymentAmount: formatCents(pCents),
      appliedToInterest: formatCents(appliedInterest),
      appliedToPrincipal: formatCents(appliedPrincipal),
      unappliedCredit: formatCents(unappliedCredit),
      remainingInterest: formatCents(iCents - appliedInterest),
      remainingPrincipal: formatCents(prCents - appliedPrincipal),
    );
  }

  /// Quotes accrued interest and full payoff for an effective date.
  ///
  /// This mirrors the backend's straight-line proration for an early, on-time,
  /// or late payment within the active installment period.
  static LoanPayoffQuote quotePayoff({
    required String outstandingPrincipal,
    required double periodicRate,
    required DateTime periodStartDate,
    required DateTime dueDate,
    required DateTime effectiveDate,
  }) {
    final periodStart = DateTime(
      periodStartDate.year,
      periodStartDate.month,
      periodStartDate.day,
    );
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final effective = DateTime(
      effectiveDate.year,
      effectiveDate.month,
      effectiveDate.day,
    );
    final scheduledDays = due.difference(periodStart).inDays;
    if (scheduledDays <= 0) {
      throw const LoanCalculationException(
        'dueDate must follow periodStartDate',
      );
    }
    if (effective.isBefore(periodStart)) {
      throw const LoanCalculationException(
        'effectiveDate must not precede periodStartDate',
      );
    }

    final elapsedDays = effective.difference(periodStart).inDays;
    final interest = calculateProratedInterest(
      outstandingPrincipal: outstandingPrincipal,
      periodicRate: periodicRate,
      elapsedDays: elapsedDays,
      scheduledPeriodDays: scheduledDays,
    );
    final payoffCents =
        parseCents(outstandingPrincipal, 'outstandingPrincipal') +
        parseCents(interest, 'interestDue');

    return LoanPayoffQuote(
      interestDue: interest,
      payoffAmount: formatCents(payoffCents),
      elapsedDays: elapsedDays,
      scheduledPeriodDays: scheduledDays,
      daysEarly: max(due.difference(effective).inDays, 0),
      overdueDays: max(effective.difference(due).inDays, 0),
    );
  }

  /// Builds installment schedule identical to backend build_installment_schedule.
  static List<ScheduledInstallment> buildInstallmentSchedule({
    required String originalPrincipal,
    required double periodicRate,
    required int numberOfPayments,
  }) {
    final principalCents = parseCents(originalPrincipal, 'originalPrincipal');
    if (principalCents <= 0) {
      throw const LoanCalculationException(
        'originalPrincipal must be positive',
      );
    }
    if (periodicRate < 0 || !periodicRate.isFinite) {
      throw const LoanCalculationException(
        'periodicRate must be non-negative and finite',
      );
    }
    if (numberOfPayments <= 0) {
      throw const LoanCalculationException('numberOfPayments must be positive');
    }

    final double exactRegularPaymentCents;
    if (periodicRate == 0) {
      exactRegularPaymentCents = principalCents / numberOfPayments;
    } else {
      final discountFactor = 1.0 - pow(1.0 + periodicRate, -numberOfPayments);
      exactRegularPaymentCents =
          (principalCents * periodicRate) / discountFactor;
    }

    final regularPaymentCents = roundHalfUp(exactRegularPaymentCents);

    var balanceCents = principalCents;
    final installments = <ScheduledInstallment>[];

    for (var number = 1; number <= numberOfPayments; number++) {
      final interestCents = calculatePeriodInterestCents(
        balanceCents,
        periodicRate,
      );
      final isFinalPayment = number == numberOfPayments;

      final paymentCents = isFinalPayment
          ? balanceCents + interestCents
          : regularPaymentCents;

      final principalPaidCents = paymentCents - interestCents;
      if (principalPaidCents <= 0) {
        throw const LoanCalculationException(
          'regular payment must be greater than period interest',
        );
      }

      var remainingCents = balanceCents - principalPaidCents;
      if (isFinalPayment) {
        remainingCents = 0;
      }

      installments.add(
        ScheduledInstallment(
          number: number,
          paymentAmount: formatCents(paymentCents),
          interestAmount: formatCents(interestCents),
          principalAmount: formatCents(principalPaidCents),
          remainingPrincipal: formatCents(remainingCents),
        ),
      );

      balanceCents = remainingCents;
    }

    return installments;
  }
}
