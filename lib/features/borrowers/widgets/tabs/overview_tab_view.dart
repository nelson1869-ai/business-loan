import 'package:flutter/material.dart';
import '../../domain/borrower_model.dart';
import '../borrower_app_access_card.dart';
import '../pii_masked_text.dart';

/// Overview Tab View presenting personal, employment, emergency, and guarantor details.
class OverviewTabView extends StatelessWidget {
  final Borrower borrower;
  final List<Widget> leading;

  const OverviewTabView({
    super.key,
    required this.borrower,
    this.leading = const [],
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ...leading,
        if (leading.isNotEmpty) const SizedBox(height: 16),
        BorrowerAppAccessCard(borrower: borrower),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Personal Information',
          icon: Icons.person_outline,
          children: [
            _InfoRow(label: 'Full Name', value: borrower.fullName),
            _InfoRow(label: 'Date of Birth', value: borrower.dateOfBirth),
            const _InfoRow(label: 'Gender', value: 'Not provided'),
            const _InfoRow(label: 'Civil Status', value: 'Not provided'),
            PIIMaskedText(
              icon: Icons.badge_outlined,
              label: 'National ID',
              value: borrower.nationalId,
            ),
          ],
        ),
        const SizedBox(height: 16),
        const _SectionCard(
          title: 'Employment & Income',
          icon: Icons.work_outline,
          children: [
            _InfoRow(label: 'Occupation', value: 'Not provided'),
            _InfoRow(label: 'Employer', value: 'Not provided'),
            _InfoRow(label: 'Estimated Income', value: 'Not provided'),
          ],
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Emergency Contact',
          icon: Icons.contact_phone_outlined,
          children: [
            const _InfoRow(label: 'Contact Name', value: 'Not provided'),
            const _InfoRow(label: 'Relationship', value: 'Not provided'),
            PIIMaskedText(
              icon: Icons.phone_outlined,
              label: 'Phone',
              value: borrower.phone,
              isPhone: true,
            ),
          ],
        ),
        const SizedBox(height: 16),
        const _SectionCard(
          title: 'Guarantor Information',
          icon: Icons.verified_user_outlined,
          children: [
            _InfoRow(label: 'Guarantor Name', value: 'Not provided'),
            _InfoRow(label: 'Guarantor Phone', value: 'Not provided'),
            _InfoRow(label: 'Address', value: 'Not provided'),
          ],
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
