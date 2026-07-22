import 'package:flutter/material.dart';

class LoanDateField extends StatelessWidget {
  const LoanDateField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.calendar_today_outlined),
        ),
        child: Text(
          value == null
              ? 'Select $label'
              : '${value!.month}/${value!.day}/${value!.year}',
          style: TextStyle(
            fontSize: 16,
            color: value == null
                ? Colors.grey
                : theme.textTheme.bodyLarge?.color,
          ),
        ),
      ),
    );
  }
}
