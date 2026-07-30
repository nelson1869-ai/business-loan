import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';

import '../../../core/presentation/design_system/app_bottom_sheet.dart';
import '../../loans/domain/models/loan.dart';
import '../data/borrower_communication_service.dart';
import '../data/borrower_document_service.dart';
import '../data/borrower_due_reminder_scheduler.dart';
import '../domain/borrower_communication_context.dart';
import '../domain/borrower_message_template_service.dart';
import '../domain/phone_number.dart';
import 'borrower_communication_provider.dart';
import 'message_preview_dialog.dart';

enum SendToBorrowerAction {
  paymentReminder,
  loanSummary,
  paymentSchedule,
  paymentReceipt,
  loanStatement,
  copyMessage,
  moreSharingOptions,
}

/// Computes action visibility without touching presentation or platform state.
Set<SendToBorrowerAction> availableSendToBorrowerActions(
  BorrowerCommunicationContext context,
) {
  final actions = <SendToBorrowerAction>{
    SendToBorrowerAction.copyMessage,
    SendToBorrowerAction.moreSharingOptions,
  };
  if (context.loan case final loan?) {
    actions.add(SendToBorrowerAction.loanSummary);
    actions.add(SendToBorrowerAction.loanStatement);
    if (loan.installments.isNotEmpty) {
      actions.add(SendToBorrowerAction.paymentReminder);
      actions.add(SendToBorrowerAction.paymentSchedule);
    }
  }
  if (context.payment != null) {
    actions.add(SendToBorrowerAction.paymentReceipt);
  }
  return actions;
}

class SendToBorrowerSheet extends ConsumerStatefulWidget {
  const SendToBorrowerSheet({super.key, required this.request});

  final BorrowerCommunicationRequest request;

  static Future<void> show(
    BuildContext context,
    BorrowerCommunicationRequest request,
  ) {
    return AppBottomSheet.show<void>(
      context,
      title: 'Send to Borrower',
      child: SendToBorrowerSheet(request: request),
    );
  }

  @override
  ConsumerState<SendToBorrowerSheet> createState() =>
      _SendToBorrowerSheetState();
}

class _SendToBorrowerSheetState extends ConsumerState<SendToBorrowerSheet> {
  bool _working = false;
  final _templates = const BorrowerMessageTemplateService();

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(
      borrowerCommunicationContextProvider(widget.request),
    );
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.72,
      ),
      child: snapshot.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => const Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Borrower information is not available on this device. '
            'Reconnect once to cache it, then try again.',
          ),
        ),
        data: (data) => _content(data),
      ),
    );
  }

  Widget _content(BorrowerCommunicationContext data) {
    final phone = PhilippinePhoneNumber.tryParse(data.borrower.phone);
    final actions = availableSendToBorrowerActions(data);
    final loan = data.loan;
    return ListView(
      shrinkWrap: true,
      children: <Widget>[
        Semantics(
          label: 'Borrower communication context',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(child: Icon(Icons.person_outline)),
            title: Text(data.borrower.fullName),
            subtitle: Text(
              '${phone?.masked ?? 'No usable mobile number'}'
              '${loan == null ? '' : '\nLoan ${loan.status}'}',
            ),
            isThreeLine: loan != null,
          ),
        ),
        if (phone == null)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(Icons.info_outline),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'SMS is unavailable because this borrower has no valid '
                      'Philippine mobile number. Copy and general sharing '
                      'remain available.',
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (loan == null)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'No active loan is stored on this device. Loan reminders, '
                'schedules, statements, and receipts are unavailable.',
              ),
            ),
          ),
        if (_working)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(),
          ),
        if (actions.contains(SendToBorrowerAction.paymentReminder))
          _tile(
            Icons.notifications_active_outlined,
            'Send Payment Reminder',
            'Review the next due or overdue installment',
            () => _preview(data, _templates.paymentReminder(data), phone),
          ),
        if (actions.contains(SendToBorrowerAction.loanSummary))
          _tile(
            Icons.account_balance_wallet_outlined,
            'Send Loan Summary',
            'Current locally stored loan snapshot',
            () => _preview(data, _templates.loanSummary(data), phone),
          ),
        if (actions.contains(SendToBorrowerAction.paymentSchedule))
          _tile(
            Icons.calendar_month_outlined,
            'Share Payment Schedule',
            'Generate the complete schedule as PDF',
            () => _document(data, BorrowerDocumentType.schedule),
          ),
        if (actions.contains(SendToBorrowerAction.paymentReceipt))
          _tile(
            Icons.receipt_long_outlined,
            'Share Payment Receipt',
            'Selected payment and remaining balance',
            () => _document(data, BorrowerDocumentType.receipt),
          ),
        if (actions.contains(SendToBorrowerAction.loanStatement))
          _tile(
            Icons.description_outlined,
            'Share Loan Statement PDF',
            'Loan summary and effective payment history',
            () => _document(data, BorrowerDocumentType.statement),
          ),
        if (loan != null)
          _tile(
            Icons.snooze_outlined,
            'Snooze Officer Reminder',
            'Remind me again in 1 day',
            () => _snooze(loan),
          ),
        _tile(
          Icons.copy_outlined,
          'Copy Message',
          'Review and edit before copying',
          () => _preview(
            data,
            data.payment == null
                ? (data.loan == null
                      ? 'Hello ${data.borrower.firstName},\n\nThank you,\n'
                            'Lending Nelson'
                      : _templates.loanSummary(data))
                : _templates.paymentReceipt(data),
            phone,
          ),
        ),
        _tile(
          Icons.share_outlined,
          'More Sharing Options',
          'Use any compatible application installed on this phone',
          () => _preview(
            data,
            data.payment == null
                ? (data.loan == null
                      ? 'Hello ${data.borrower.firstName},\n\nThank you,\n'
                            'Lending Nelson'
                      : _templates.scheduleSummary(data))
                : _templates.paymentReceipt(data),
            phone,
          ),
        ),
      ],
    );
  }

  Widget _tile(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback action,
  ) {
    return ListTile(
      minTileHeight: 56,
      enabled: !_working,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: _working ? null : action,
    );
  }

  Future<void> _preview(
    BorrowerCommunicationContext data,
    String message,
    PhilippinePhoneNumber? phone,
  ) async {
    final result = await MessagePreviewDialog.show(
      context,
      message,
      smsEnabled: phone != null,
    );
    if (result == null || !mounted || result.message.isEmpty) return;
    setState(() => _working = true);
    try {
      final service = ref.read(borrowerCommunicationServiceProvider);
      if (result.action == MessagePreviewAction.share) {
        await service.shareText(result.message);
      } else if (phone == null) {
        _feedback('Add a valid Philippine mobile number before opening SMS.');
      } else if (!await service.openSmsDraft(phone, result.message)) {
        _feedback('No SMS application could open the prepared message.');
      }
    } catch (_) {
      if (mounted) _feedback('The sharing application could not be opened.');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _document(
    BorrowerCommunicationContext data,
    BorrowerDocumentType type,
  ) async {
    setState(() => _working = true);
    try {
      final file = await ref
          .read(borrowerDocumentServiceProvider)
          .generate(type, data);
      if (!mounted) return;
      await _showDocumentActions(file, type);
    } on BorrowerDocumentException catch (error) {
      if (mounted) _feedback(error.message);
    } catch (_) {
      if (mounted) _feedback('The PDF could not be generated.');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _snooze(Loan loan) async {
    setState(() => _working = true);
    try {
      await ref.read(borrowerDueReminderSchedulerProvider).snooze(loan);
      if (mounted) _feedback('Officer reminder snoozed for 1 day.');
    } catch (_) {
      if (mounted) _feedback('The officer reminder could not be snoozed.');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _showDocumentActions(
    File file,
    BorrowerDocumentType type,
  ) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.visibility_outlined),
              title: const Text('Preview or open PDF'),
              onTap: () => Navigator.pop(sheetContext, 'open'),
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('Share PDF'),
              onTap: () => Navigator.pop(sheetContext, 'share'),
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(sheetContext),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'open') {
      final result = await OpenFilex.open(file.path, type: 'application/pdf');
      if (!mounted) return;
      if (result.type != ResultType.done) {
        _feedback('No application could preview the PDF.');
      }
    } else if (action == 'share') {
      await ref
          .read(borrowerCommunicationServiceProvider)
          .sharePdf(file.path, '${_documentLabel(type)} — Lending Nelson');
    }
  }

  String _documentLabel(BorrowerDocumentType type) => switch (type) {
    BorrowerDocumentType.schedule => 'Payment Schedule',
    BorrowerDocumentType.receipt => 'Payment Receipt',
    BorrowerDocumentType.statement => 'Loan Statement',
  };

  void _feedback(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
