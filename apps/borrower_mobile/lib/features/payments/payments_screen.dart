import 'package:flutter/material.dart';
import 'package:borrower_mobile/core/widgets/placeholder_screen.dart';

class PaymentsScreen extends StatelessWidget {
  const PaymentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: 'Payments',
      icon: Icons.payment_outlined,
    );
  }
}
