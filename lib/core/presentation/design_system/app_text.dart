import 'package:flutter/material.dart';
import '../../utils/formatters.dart';

/// Formatted Money/Currency text displaying amounts cleanly with color coding.
class AppMoneyText extends StatelessWidget {
  final dynamic amount;
  final TextStyle? style;
  final Color? color;
  final bool isBold;

  const AppMoneyText({
    super.key,
    required this.amount,
    this.style,
    this.color,
    this.isBold = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strValue = amount?.toString() ?? '0.00';
    final formatted = formatCurrency(strValue);

    return Text(
      formatted,
      style: (style ?? theme.textTheme.titleMedium)?.copyWith(
        fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
        color: color,
      ),
    );
  }
}
