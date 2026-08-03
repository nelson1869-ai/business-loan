import 'package:flutter/material.dart';

/// Formats a [DateTime] as an ISO-8601 date string (`YYYY-MM-DD`).
String formatDateOnly(DateTime value) {
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

/// Parses an ISO date string and returns `M/D/Y` format.
/// Returns [iso] unchanged if parsing fails.
String formatDateShort(String iso) {
  final dt = DateTime.tryParse(iso);
  if (dt == null) return iso;
  return '${dt.month}/${dt.day}/${dt.year}';
}

/// Parses an ISO date string and returns a human-readable relative label
/// (e.g. `Today`, `Yesterday`, `3d ago`, or `M/D`).
/// Handles date-only strings cleanly without producing negative values.
/// Returns [iso] unchanged if parsing fails.
String formatRelativeDate(String iso) {
  final dt = DateTime.tryParse(iso);
  if (dt == null) return iso;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final date = DateTime(dt.year, dt.month, dt.day);
  final diff = date.difference(today);
  if (diff.inDays == 0) return 'Today';
  if (diff.inDays == -1) return 'Yesterday';
  if (diff.inDays == 1) return 'Tomorrow';
  if (diff.inDays < 0 && diff.inDays >= -6) return '${-diff.inDays}d ago';
  if (diff.inDays > 0 && diff.inDays <= 7) return 'In ${diff.inDays}d';
  return '${dt.month}/${dt.day}';
}

/// Converts a human percentage (e.g. `10`) to an exact fractional decimal
/// string (e.g. `0.10`) without binary floating-point error.
String percentageToDecimalRate(String percentage) {
  final parts = percentage.split('.');
  final fractionalDigits = parts.length == 2 ? parts[1].length : 0;
  final digits = percentage.replaceAll('.', '');
  final numerator = BigInt.parse(digits);
  final scale = fractionalDigits + 2;
  final padded = numerator.toString().padLeft(scale + 1, '0');
  final splitAt = padded.length - scale;
  final whole = padded.substring(0, splitAt);
  var fraction = padded.substring(splitAt).replaceFirst(RegExp(r'0+$'), '');
  if (fraction.isEmpty) fraction = '0';
  return '$whole.$fraction';
}

/// Converts a decimal rate string (e.g. `0.10000000`) to a human percentage
/// display (e.g. `10%`).
String formatInterestRate(String rate) {
  final value = double.tryParse(rate);
  if (value == null) return rate;
  final percent = value <= 1.0 ? (value * 100).round() : value.round();
  return '$percent%';
}

/// Formats a decimal string to a currency string with `₱` prefix and
/// thousand-separator commas (e.g. `"1000.00"` → `"₱1,000.00"`).
/// Returns `₱$amount` as-is if parsing fails.
String formatCurrency(String amount) {
  final match = RegExp(r'^(-?)(\d+)(?:\.(\d+))?$').firstMatch(amount.trim());
  if (match == null) return '₱$amount';
  final isNegative = match.group(1) == '-';
  final intPart = match.group(2)!;
  final rawFraction = match.group(3) ?? '';
  final fraction = rawFraction.padRight(2, '0').substring(0, 2);
  final formatted = StringBuffer();
  for (var i = 0; i < intPart.length; i++) {
    if (i > 0 && (intPart.length - i) % 3 == 0) {
      formatted.write(',');
    }
    formatted.write(intPart[i]);
  }
  final prefix = isNegative ? '-₱' : '₱';
  return '$prefix${formatted.toString()}.$fraction';
}

/// A reusable label–value row used in payment cards and history tiles.
class InfoRow extends StatelessWidget {
  const InfoRow(this.label, this.value, {super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
