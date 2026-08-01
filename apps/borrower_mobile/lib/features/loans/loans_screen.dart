import 'package:flutter/material.dart';
import 'package:borrower_mobile/core/widgets/placeholder_screen.dart';

class LoansScreen extends StatelessWidget {
  const LoansScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: 'My Loans',
      icon: Icons.account_balance_wallet_outlined,
    );
  }
}
