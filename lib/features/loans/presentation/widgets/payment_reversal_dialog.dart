import 'package:flutter/material.dart';

import '../../../../core/utils/formatters.dart';

class PaymentReversalDialog extends StatefulWidget {
  const PaymentReversalDialog({super.key, required this.paymentDate});

  final DateTime paymentDate;

  @override
  State<PaymentReversalDialog> createState() => _PaymentReversalDialogState();
}

class _PaymentReversalDialogState extends State<PaymentReversalDialog> {
  final _reasonController = TextEditingController();
  late DateTime _reversalDate;
  String? _reasonError;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _reversalDate = today.isBefore(widget.paymentDate)
        ? widget.paymentDate
        : today;
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _reversalDate,
      firstDate: widget.paymentDate,
      lastDate: DateTime(2200),
    );
    if (picked != null && mounted) {
      setState(() => _reversalDate = picked);
    }
  }

  void _submit() {
    final reason = _reasonController.text.trim();
    if (reason.length < 3) {
      setState(() => _reasonError = 'Enter at least 3 characters');
      return;
    }
    Navigator.pop(context, (reason, _reversalDate));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reverse payment?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'The original record remains in history. '
              'Reversal restores its balance changes.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _reasonController,
              autofocus: true,
              maxLength: 500,
              decoration: InputDecoration(
                labelText: 'Reason for reversal',
                helperText: 'Required: at least 3 characters',
                errorText: _reasonError,
              ),
              onChanged: (_) {
                if (_reasonError != null) {
                  setState(() => _reasonError = null);
                }
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Financial reversal date'),
              subtitle: Text(formatDateOnly(_reversalDate)),
              trailing: const Icon(Icons.edit_calendar),
              onTap: _pickDate,
            ),
            const Text(
              'The recorded date and time are saved automatically for the audit history.',
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Reverse Payment')),
      ],
    );
  }
}
