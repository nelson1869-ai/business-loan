import 'package:flutter/material.dart';

import '../../../core/presentation/design_system/design_system.dart';
import '../domain/borrower_model.dart';

/// Honest unavailable state for guarantor and field-location data.
class BorrowerEmergencyGuarantorCard extends StatelessWidget {
  const BorrowerEmergencyGuarantorCard({super.key, required this.borrower});

  final Borrower borrower;

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      margin: EdgeInsets.zero,
      child: AppEmptyState(
        icon: Icons.contact_phone_outlined,
        title: 'Guarantor and location unavailable',
        description:
            'The connected borrower record does not provide guarantor or '
            'verified field-location data.',
      ),
    );
  }
}
