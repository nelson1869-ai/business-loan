import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_error_mapper.dart';
import '../../../core/presentation/design_system/app_state_views.dart';

/// Single-Owner Borrower Registration Review Item model.
class RegistrationItem {
  final String id;
  final String firstName;
  final String lastName;
  final String phoneNumber;
  final String? address;
  final String dateOfBirth;
  final String? nationalId;
  final String? idPhotoUrl;
  final String? selfieUrl;
  final String status;
  final String? rejectionReason;
  final String submittedAt;

  const RegistrationItem({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.phoneNumber,
    this.address,
    required this.dateOfBirth,
    this.nationalId,
    this.idPhotoUrl,
    this.selfieUrl,
    required this.status,
    this.rejectionReason,
    required this.submittedAt,
  });

  factory RegistrationItem.fromJson(Map<String, dynamic> json) {
    return RegistrationItem(
      id: json['id'] as String,
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      phoneNumber: json['phoneNumber'] as String? ?? '',
      address: json['address'] as String?,
      dateOfBirth: json['dateOfBirth'] as String? ?? '',
      nationalId: json['nationalId'] as String?,
      idPhotoUrl: json['idPhotoUrl'] as String?,
      selfieUrl: json['selfieUrl'] as String?,
      status: json['status'] as String? ?? 'Pending',
      rejectionReason: json['rejectionReason'] as String?,
      submittedAt: json['submittedAt'] as String? ?? '',
    );
  }
}

final registrationFilterProvider = StateProvider<String>((ref) => 'Pending');
final registrationSearchProvider = StateProvider<String>((ref) => '');

final borrowerRegistrationsProvider =
    FutureProvider.autoDispose<List<RegistrationItem>>((ref) async {
  final dio = ref.watch(apiClientProvider);
  final filter = ref.watch(registrationFilterProvider);
  final search = ref.watch(registrationSearchProvider);

  final queryParams = <String, dynamic>{};
  if (filter != 'All') queryParams['status'] = filter;
  if (search.trim().isNotEmpty) queryParams['search'] = search.trim();

  final response = await dio.get<List<dynamic>>(
    '/api/v1/borrowers/registrations',
    queryParameters: queryParams.isEmpty ? null : queryParams,
  );

  return (response.data ?? [])
      .map((row) => RegistrationItem.fromJson(Map<String, dynamic>.from(row as Map)))
      .toList(growable: false);
});

/// Single-Owner Registration Review Page for Owner App.
class RegistrationReviewPage extends ConsumerWidget {
  const RegistrationReviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final registrationsAsync = ref.watch(borrowerRegistrationsProvider);
    final currentFilter = ref.watch(registrationFilterProvider);
    final theme = Theme.of(context);

    final filters = [
      'Pending',
      'Approved',
      'Activated',
      'Rejected',
      'Suspended',
      'Disabled',
      'All',
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Borrower Registration Review'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Applications',
            onPressed: () => ref.invalidate(borrowerRegistrationsProvider),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Field
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search by borrower name, phone, or ID...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                onChanged: (val) {
                  ref.read(registrationSearchProvider.notifier).state = val;
                },
              ),
            ),

            // Status Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: filters.map((status) {
                  final isSelected = currentFilter == status;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(status),
                      selected: isSelected,
                      selectedColor: const Color(0xFF0D9488),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : theme.colorScheme.onSurface,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 12,
                      ),
                      onSelected: (_) {
                        ref.read(registrationFilterProvider.notifier).state = status;
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const Divider(height: 16),

            // Main Registrations List
            Expanded(
              child: registrationsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(ApiErrorMapper.message(err)),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () => ref.invalidate(borrowerRegistrationsProvider),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (items) {
                  if (items.isEmpty) {
                    return AppEmptyState(
                      icon: Icons.person_search_outlined,
                      title: 'No Applications Found',
                      description: 'No borrower registration applications match criteria.',
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async => ref.invalidate(borrowerRegistrationsProvider),
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return _RegistrationCard(item: item);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RegistrationCard extends ConsumerWidget {
  const _RegistrationCard({required this.item});

  final RegistrationItem item;

  Color _statusColor(String status) {
    return switch (status.toUpperCase()) {
      'APPROVED' => const Color(0xFF0D9488),
      'ACTIVATED' => Colors.green.shade700,
      'PENDING' => Colors.orange.shade800,
      'REJECTED' => Colors.red.shade700,
      'SUSPENDED' => Colors.purple.shade700,
      'DISABLED' => Colors.grey.shade700,
      _ => Colors.blue.shade700,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final statusColor = _statusColor(item.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(14),
        title: Row(
          children: [
            Expanded(
              child: Text(
                '${item.firstName} ${item.lastName}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: statusColor, width: 1),
              ),
              child: Text(
                item.status.toUpperCase(),
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.phone_outlined, size: 15, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(item.phoneNumber, style: theme.textTheme.bodyMedium),
                ],
              ),
              if (item.nationalId != null && item.nationalId!.isNotEmpty) ...[
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(Icons.badge_outlined, size: 15, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text('Govt ID: ${item.nationalId}', style: theme.textTheme.bodySmall),
                  ],
                ),
              ],
              if (item.address != null && item.address!.isNotEmpty) ...[
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 15, color: Colors.grey),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        item.address!,
                        style: theme.textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _showReviewDialog(context, ref, item),
      ),
    );
  }

  void _showReviewDialog(BuildContext context, WidgetRef ref, RegistrationItem item) {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => _ApplicantReviewModal(item: item),
    );
  }
}

class _ApplicantReviewModal extends ConsumerStatefulWidget {
  const _ApplicantReviewModal({required this.item});

  final RegistrationItem item;

  @override
  ConsumerState<_ApplicantReviewModal> createState() => __ApplicantReviewModalState();
}

class __ApplicantReviewModalState extends ConsumerState<_ApplicantReviewModal> {
  bool _working = false;

  Future<void> _approve() async {
    setState(() => _working = true);
    final dio = ref.read(apiClientProvider);
    try {
      final response = await dio.post<Map<String, dynamic>>(
        '/api/v1/borrowers/registrations/${widget.item.id}/approve',
      );
      if (!mounted) return;
      Navigator.pop(context);
      ref.invalidate(borrowerRegistrationsProvider);

      final data = response.data ?? {};
      final code = data['activationCode'] as String? ?? '123456';
      final expiresAt = data['expiresAt'] as String? ?? '';

      // Show Owner Single-Owner Activation Code Dialog
      _showActivationCodeDialog(code, expiresAt);
    } catch (error) {
      if (mounted) {
        setState(() => _working = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiErrorMapper.message(error))),
        );
      }
    }
  }

  Future<void> _reject() async {
    final reasonCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Applicant?'),
        content: TextField(
          controller: reasonCtrl,
          decoration: const InputDecoration(
            labelText: 'Reason for rejection',
            hintText: 'e.g. Invalid government ID document',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;
    setState(() => _working = true);
    final dio = ref.read(apiClientProvider);
    try {
      await dio.post<Map<String, dynamic>>(
        '/api/v1/borrowers/registrations/${widget.item.id}/reject',
        queryParameters: {'reason': reasonCtrl.text.trim()},
      );
      if (!mounted) return;
      Navigator.pop(context);
      ref.invalidate(borrowerRegistrationsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registration application rejected.')),
      );
    } catch (error) {
      if (mounted) {
        setState(() => _working = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiErrorMapper.message(error))),
        );
      }
    }
  }

  void _showActivationCodeDialog(String code, String expiresAt) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.vpn_key_outlined, color: Color(0xFF0D9488)),
            SizedBox(width: 10),
            Text('Owner Activation Code'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Borrower registration approved! Give this 6-digit one-time activation code to the borrower personally:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D9488).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF0D9488), width: 2),
                ),
                child: Text(
                  code,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 8,
                    color: Color(0xFF0D9488),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '• Code expires in 24 hours.\n• One-time use for account activation.\n• Borrower enters this code on the Borrower App.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Copy Code'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(content: Text('Activation code copied to clipboard!')),
              );
            },
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0D9488)),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return AlertDialog(
      title: Text('${item.firstName} ${item.lastName}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detailRow('Phone Number', item.phoneNumber),
            _detailRow('Date of Birth', item.dateOfBirth),
            _detailRow('Government ID', item.nationalId ?? 'N/A'),
            _detailRow('Address', item.address ?? 'N/A'),
            _detailRow('Submitted', item.submittedAt),
            _detailRow('Status', item.status.toUpperCase()),
            if (item.rejectionReason != null)
              _detailRow('Rejection Reason', item.rejectionReason!),
            const SizedBox(height: 12),
            if (item.idPhotoUrl != null && item.idPhotoUrl!.isNotEmpty) ...[
              const Text('Government ID Photo:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  item.idPhotoUrl!,
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 80,
                    color: Colors.grey.shade300,
                    child: const Center(child: Text('Image preview unavailable')),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _working ? null : () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        if (item.status.toUpperCase() == 'PENDING') ...[
          TextButton(
            onPressed: _working ? null : _reject,
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Reject'),
          ),
          FilledButton.icon(
            onPressed: _working ? null : _approve,
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0D9488)),
            icon: const Icon(Icons.check_circle_outline, size: 18),
            label: const Text('Approve & Generate Code'),
          ),
        ],
      ],
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
