import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../loans/presentation/borrower_loans_section.dart';
import '../../loans/presentation/providers/loans_provider.dart';
import '../domain/borrower_model.dart';
import '../providers/borrowers_state.dart';
import '../widgets/borrower_action_buttons.dart';
import '../widgets/borrower_profile_card.dart';
import '../widgets/emergency_contact_card.dart';
import '../widgets/payment_history_section.dart';

class BorrowerDetailPage extends ConsumerWidget {
  const BorrowerDetailPage({
    super.key,
    required this.borrowerId,
    this.initialBorrower,
  });

  final String borrowerId;
  final Borrower? initialBorrower;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/borrowers');
            }
          },
        ),
        title: Text(initialBorrower?.fullName ?? 'Borrower'),
      ),
      body: _BorrowerDetailContent(
        borrowerId: borrowerId,
        initialBorrower: initialBorrower,
      ),
    );
  }
}

class _BorrowerDetailContent extends ConsumerWidget {
  const _BorrowerDetailContent({
    required this.borrowerId,
    this.initialBorrower,
  });

  final String borrowerId;
  final Borrower? initialBorrower;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final borrowersAsync = ref.watch(borrowersNotifierProvider);
    final borrower =
        borrowersAsync.valueOrNull
            ?.where((b) => b.id == borrowerId)
            .firstOrNull ??
        initialBorrower;

    if (borrower == null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading borrower...'),
          ],
        ),
      );
    }

    final loansAsync = ref.watch(borrowerLoansProvider(borrowerId));
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        BorrowerProfileCard(borrower: borrower, loansAsync: loansAsync),
        const SizedBox(height: 20),
        BorrowerActionButtons(borrower: borrower),
        const SizedBox(height: 16),
        EmergencyContactCard(borrower: borrower),
        const SizedBox(height: 24),
        BorrowerLoansSection(borrower: borrower),
        const SizedBox(height: 24),
        PaymentHistorySection(
          borrowerId: borrowerId,
          loansAsync: loansAsync,
          theme: theme,
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}
