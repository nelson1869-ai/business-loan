import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_error_mapper.dart';
import '../../../core/presentation/design_system/app_state_views.dart';

class PossibleBorrowerMatch {
  final String borrowerId;
  final String fullName;
  final String maskedPhone;
  final String maskedNationalId;
  final int existingLoansCount;
  final int activeLoansCount;
  final String currentBalance;
  final String matchReason;

  const PossibleBorrowerMatch({
    required this.borrowerId,
    required this.fullName,
    required this.maskedPhone,
    required this.maskedNationalId,
    required this.existingLoansCount,
    required this.activeLoansCount,
    required this.currentBalance,
    required this.matchReason,
  });

  factory PossibleBorrowerMatch.fromJson(Map<String, dynamic> json) {
    return PossibleBorrowerMatch(
      borrowerId: json['borrowerId'] as String? ?? '',
      fullName: json['fullName'] as String? ?? '',
      maskedPhone: json['maskedPhone'] as String? ?? '',
      maskedNationalId: json['maskedNationalId'] as String? ?? '',
      existingLoansCount: json['existingLoansCount'] as int? ?? 0,
      activeLoansCount: json['activeLoansCount'] as int? ?? 0,
      currentBalance: json['currentBalance'] as String? ?? '0.00',
      matchReason: json['matchReason'] as String? ?? '',
    );
  }
}

/// Single-Owner Borrower Registration Review Item model.
class RegistrationItem {
  final String id;
  final String firstName;
  final String? middleName;
  final String lastName;
  final String? suffix;
  final String maskedPhone;
  final String maskedNationalId;
  final bool hasNationalId;
  final String dateOfBirth;
  final String? email;
  final String status;
  final String submittedAt;
  final String? linkedBorrowerId;
  final List<PossibleBorrowerMatch> possibleMatches;

  const RegistrationItem({
    required this.id,
    required this.firstName,
    this.middleName,
    required this.lastName,
    this.suffix,
    required this.maskedPhone,
    required this.maskedNationalId,
    required this.hasNationalId,
    required this.dateOfBirth,
    this.email,
    required this.status,
    required this.submittedAt,
    this.linkedBorrowerId,
    this.possibleMatches = const [],
  });

  factory RegistrationItem.fromJson(Map<String, dynamic> json) {
    final matchesRaw = json['possibleMatches'] as List<dynamic>? ?? [];
    return RegistrationItem(
      id: json['id'] as String,
      firstName: json['firstName'] as String? ?? '',
      middleName: json['middleName'] as String?,
      lastName: json['lastName'] as String? ?? '',
      suffix: json['suffix'] as String?,
      maskedPhone: json['maskedPhone'] as String? ?? '',
      maskedNationalId: json['maskedNationalId'] as String? ?? '',
      hasNationalId: json['hasNationalId'] as bool? ?? false,
      dateOfBirth: json['dateOfBirth'] as String? ?? '',
      email: json['email'] as String?,
      status: json['status'] as String? ?? 'pending',
      submittedAt: json['submittedAt'] as String? ?? '',
      linkedBorrowerId: json['linkedBorrowerId'] as String?,
      possibleMatches: matchesRaw
          .map((m) => PossibleBorrowerMatch.fromJson(Map<String, dynamic>.from(m as Map)))
          .toList(),
    );
  }
}

final registrationFilterProvider = StateProvider<String>((ref) => 'pending');
final registrationSearchProvider = StateProvider<String>((ref) => '');

final borrowerRegistrationsProvider =
    FutureProvider.autoDispose<List<RegistrationItem>>((ref) async {
  final dio = ref.watch(apiClientProvider);
  final filter = ref.watch(registrationFilterProvider);
  final search = ref.watch(registrationSearchProvider);

  final queryParams = <String, dynamic>{};
  if (filter != 'all') queryParams['status'] = filter.toLowerCase();
  if (search.trim().isNotEmpty) queryParams['search'] = search.trim();

  final response = await dio.get<List<dynamic>>(
    '/api/v1/borrower-registration-requests',
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

    // value → display label; values must match backend pattern
    // ^(pending|approved|rejected|cancelled|expired)$
    const filters = <String, String>{
      'pending': 'Pending',
      'approved': 'Approved',
      'rejected': 'Rejected',
      'cancelled': 'Cancelled',
      'expired': 'Expired',
      'all': 'All',
    };

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
                children: filters.entries.map((entry) {
                  final isSelected = currentFilter == entry.key;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(entry.value),
                      selected: isSelected,
                      selectedColor: const Color(0xFF0D9488),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : theme.colorScheme.onSurface,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 12,
                      ),
                      onSelected: (_) {
                        ref.read(registrationFilterProvider.notifier).state = entry.key;
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
                  Text(item.maskedPhone, style: theme.textTheme.bodyMedium),
                ],
              ),
              if (item.hasNationalId) ...[
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(Icons.badge_outlined, size: 15, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text('Govt ID: ${item.maskedNationalId}', style: theme.textTheme.bodySmall),
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
        '/api/v1/borrower-registration-requests/${widget.item.id}/create-and-approve',
        data: <String, dynamic>{}, // national_id already captured during registration
      );
      if (!mounted) return;
      Navigator.pop(context);
      ref.invalidate(borrowerRegistrationsProvider);

      final data = response.data ?? {};
      final accountStatus = data['accountStatus'] as String? ?? '';
      final activationCode = data['activationCode'] as String?;
      final expiresAt = data['expiresAt'] as String?;
      // Show result with activation code
      _showApprovalResultDialog(
        accountStatus,
        activationCode: activationCode,
        expiresAt: expiresAt,
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
      await dio.post<void>(
        '/api/v1/borrower-registration-requests/${widget.item.id}/reject',
        data: {'reason': reasonCtrl.text.trim()},
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

  void _showApprovalResultDialog(
    String accountStatus, {
    String? activationCode,
    String? expiresAt,
  }) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: Color(0xFF0D9488)),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Registration Approved',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'The registration application has been approved.',
              style: TextStyle(fontSize: 13),
            ),
            if (activationCode != null && activationCode.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Text(
                'Borrower App Activation Code:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Center(
                  child: SelectableText(
                    activationCode,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 6,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
              ),
              if (expiresAt != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Expires: $expiresAt',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ],
              const SizedBox(height: 8),
              const Text(
                'Give this code to the borrower. Plaintext code will NOT be shown again after closing.',
                style: TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: Color(0xFFD97706),
                ),
              ),
            ],
            if (accountStatus.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Account status: ${accountStatus.toUpperCase()}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ],
        ),
        actions: [
          if (activationCode != null && activationCode.isNotEmpty)
            TextButton.icon(
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Copy Code'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: activationCode));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Activation code copied to clipboard.')),
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

  Future<void> _approveAndLink(String borrowerId) async {
    setState(() => _working = true);
    final dio = ref.read(apiClientProvider);
    try {
      final response = await dio.post<Map<String, dynamic>>(
        '/api/v1/borrower-registration-requests/${widget.item.id}/approve',
        data: <String, dynamic>{'borrowerId': borrowerId},
      );
      if (!mounted) return;
      Navigator.pop(context);
      ref.invalidate(borrowerRegistrationsProvider);

      final data = response.data ?? {};
      final accountStatus = data['accountStatus'] as String? ?? '';
      final activationCode = data['activationCode'] as String?;
      final expiresAt = data['expiresAt'] as String?;
      _showApprovalResultDialog(
        accountStatus,
        activationCode: activationCode,
        expiresAt: expiresAt,
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
            _detailRow('Phone', item.maskedPhone),
            _detailRow('Date of Birth', item.dateOfBirth),
            _detailRow('Government ID', item.maskedNationalId),
            if (item.email != null) _detailRow('Email', item.email!),
            _detailRow('Submitted', item.submittedAt.split('T').first),
            _detailRow('Status', item.status.toUpperCase()),
            if (item.linkedBorrowerId != null)
              _detailRow('Linked Borrower', item.linkedBorrowerId!),

            if (item.possibleMatches.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.shade400),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.warning_amber_rounded,
                            size: 18, color: Colors.amber),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Possible Existing Borrower Match',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Color(0xFF78350F),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Select an existing borrower below to link this app access request without creating a duplicate record:',
                      style: TextStyle(fontSize: 11, color: Color(0xFF92400E)),
                    ),
                    const SizedBox(height: 8),
                    ...item.possibleMatches.map((m) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.amber.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${m.fullName} (${m.matchReason})',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              Text('Phone: ${m.maskedPhone}',
                                  style: const TextStyle(fontSize: 11)),
                              Text('Loans: ${m.existingLoansCount} (${m.activeLoansCount} active) | Bal: ₱${m.currentBalance}',
                                  style: const TextStyle(fontSize: 11)),
                              const SizedBox(height: 6),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.link, size: 14),
                                  label: const Text('Link to Existing Borrower',
                                      style: TextStyle(fontSize: 11)),
                                  onPressed: _working
                                      ? null
                                      : () => _approveAndLink(m.borrowerId),
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],
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
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0D9488)),
            icon: const Icon(Icons.check_circle_outline, size: 18),
            label: const Text('Create New Borrower'),
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
