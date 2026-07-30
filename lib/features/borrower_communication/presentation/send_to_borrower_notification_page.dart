import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../loans/data/repositories/local_loan_repository.dart';
import '../../loans/domain/models/loan.dart';
import 'borrower_communication_provider.dart';
import 'send_to_borrower_sheet.dart';

/// Deep-link bridge from an officer reminder into the reusable send sheet.
class SendToBorrowerNotificationPage extends ConsumerStatefulWidget {
  const SendToBorrowerNotificationPage({super.key, required this.loanId});

  final String loanId;

  @override
  ConsumerState<SendToBorrowerNotificationPage> createState() =>
      _SendToBorrowerNotificationPageState();
}

class _SendToBorrowerNotificationPageState
    extends ConsumerState<SendToBorrowerNotificationPage> {
  late final Future<Loan?> _loan = ref
      .read(localLoanRepositoryProvider)
      .getLoan(widget.loanId);
  bool _opened = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment Reminder')),
      body: FutureBuilder<Loan?>(
        future: _loan,
        builder: (_, snapshot) {
          final loan = snapshot.data;
          if (loan != null && !_opened) {
            _opened = true;
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              if (!mounted) return;
              await SendToBorrowerSheet.show(
                this.context,
                BorrowerCommunicationRequest(
                  borrowerId: loan.borrowerId,
                  loan: loan,
                ),
              );
              if (mounted) this.context.go('/loans/${loan.id}');
            });
          }
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (loan == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'This loan is no longer available on this device. '
                  'The reminder can be dismissed.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return const Center(child: Text('Opening borrower reminder…'));
        },
      ),
    );
  }
}
