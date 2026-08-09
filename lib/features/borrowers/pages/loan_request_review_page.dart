import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_error_mapper.dart';
import '../../../core/presentation/design_system/app_state_views.dart';

/// Owner loan-request review item model (mirrors OwnerLoanRequestItemResponse).
class LoanRequestItem {
  final String id;
  final String borrowerId;
  final String borrowerFullName;
  final String borrowerPhoneMasked;
  final String requestedAmount;
  final int requestedTermMonths;
  final String requestedPaymentFrequency;
  final String requestedRepaymentStructure;
  final String? purpose;
  final String status;
  final String? ownerNotes;
  final String createdAt;
  final String? reviewedAt;

  const LoanRequestItem({
    required this.id,
    required this.borrowerId,
    required this.borrowerFullName,
    required this.borrowerPhoneMasked,
    required this.requestedAmount,
    required this.requestedTermMonths,
    required this.requestedPaymentFrequency,
    required this.requestedRepaymentStructure,
    this.purpose,
    required this.status,
    this.ownerNotes,
    required this.createdAt,
    this.reviewedAt,
  });

  factory LoanRequestItem.fromJson(Map<String, dynamic> json) {
    return LoanRequestItem(
      id: json['id'] as String? ?? '',
      borrowerId: json['borrowerId'] as String? ?? '',
      borrowerFullName: json['borrowerFullName'] as String? ?? '',
      borrowerPhoneMasked: json['borrowerPhoneMasked'] as String? ?? '',
      requestedAmount: json['requestedAmount'] as String? ?? '0.00',
      requestedTermMonths: json['requestedTermMonths'] as int? ?? 0,
      requestedPaymentFrequency:
          json['requestedPaymentFrequency'] as String? ?? 'monthly',
      requestedRepaymentStructure:
          json['requestedRepaymentStructure'] as String? ?? 'principal_plus_interest',
      purpose: json['purpose'] as String?,
      status: json['status'] as String? ?? 'submitted',
      ownerNotes: json['ownerNotes'] as String?,
      createdAt: json['createdAt'] as String? ?? '',
      reviewedAt: json['reviewedAt'] as String?,
    );
  }
}

final loanRequestFilterProvider = StateProvider<String>((ref) => 'submitted');

final borrowerLoanRequestsProvider =
    FutureProvider.autoDispose<List<LoanRequestItem>>((ref) async {
  final dio = ref.watch(apiClientProvider);
  final filter = ref.watch(loanRequestFilterProvider);

  final queryParams = <String, dynamic>{};
  if (filter != 'all') queryParams['status'] = filter.toLowerCase();

  final response = await dio.get<List<dynamic>>(
    '/api/v1/borrower-loan-requests',
    queryParameters: queryParams.isEmpty ? null : queryParams,
  );

  return (response.data ?? [])
      .map((row) => LoanRequestItem.fromJson(Map<String, dynamic>.from(row as Map)))
      .toList(growable: false);
});

/// Owner Loan Request Review Page.
class LoanRequestReviewPage extends ConsumerWidget {
  const LoanRequestReviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(borrowerLoanRequestsProvider);
    final currentFilter = ref.watch(loanRequestFilterProvider);
    final theme = Theme.of(context);

    // value → display label; values must match backend status pattern
    const filters = <String, String>{
      'submitted': 'Submitted',
      'pending': 'Pending',
      'approved': 'Approved',
      'declined': 'Declined',
      'all': 'All',
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Loan Request Review'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Requests',
            onPressed: () => ref.invalidate(borrowerLoanRequestsProvider),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Status Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                        color: isSelected
                            ? Colors.white
                            : theme.colorScheme.onSurface,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 12,
                      ),
                      onSelected: (_) {
                        ref
                            .read(loanRequestFilterProvider.notifier)
                            .state = entry.key;
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const Divider(height: 4),

            // Main Requests List
            Expanded(
              child: requestsAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(ApiErrorMapper.message(err)),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () =>
                              ref.invalidate(borrowerLoanRequestsProvider),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (items) {
                  if (items.isEmpty) {
                    return const AppEmptyState(
                      icon: Icons.request_page_outlined,
                      title: 'No Loan Requests Found',
                      description:
                          'No borrower loan requests match the selected criteria.',
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async =>
                        ref.invalidate(borrowerLoanRequestsProvider),
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return _LoanRequestCard(item: item);
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

class _LoanRequestCard extends ConsumerWidget {
  const _LoanRequestCard({required this.item});

  final LoanRequestItem item;

  Color _statusColor(String status) {
    return switch (status.toLowerCase()) {
      'approved' => const Color(0xFF0D9488),
      'declined' => Colors.red.shade700,
      'submitted' => Colors.orange.shade800,
      'pending' => Colors.blue.shade700,
      _ => Colors.grey.shade700,
    };
  }

  String _formatAmount(String amount) {
    try {
      final value = double.parse(amount);
      return value.toStringAsFixed(2);
    } catch (_) {
      return amount;
    }
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
                item.borrowerFullName,
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
                  Text(item.borrowerPhoneMasked, style: theme.textTheme.bodyMedium),
                ],
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  const Icon(Icons.payments_outlined, size: 15, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(
                    '₱${_formatAmount(item.requestedAmount)} · '
                    '${item.requestedTermMonths} mo',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _showReviewDialog(context, ref, item),
      ),
    );
  }

  void _showReviewDialog(BuildContext context, WidgetRef ref, LoanRequestItem item) {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => _LoanRequestReviewModal(item: item),
    );
  }
}

class _LoanRequestReviewModal extends ConsumerStatefulWidget {
  const _LoanRequestReviewModal({required this.item});

  final LoanRequestItem item;

  @override
  ConsumerState<_LoanRequestReviewModal> createState() =>
      _LoanRequestReviewModalState();
}

class _LoanRequestReviewModalState extends ConsumerState<_LoanRequestReviewModal> {
  bool _working = false;

  Future<void> _submitReview(String action) async {
    setState(() => _working = true);
    final dio = ref.read(apiClientProvider);
    try {
      await dio.post<Map<String, dynamic>>(
        '/api/v1/borrower-loan-requests/${widget.item.id}/review',
        data: <String, dynamic>{
          'action': action,
          'ownerNotes': action == 'decline'
              ? 'Declined by owner'
              : 'Approved by owner',
        },
      );
      if (!mounted) return;
      Navigator.pop(context);
      ref.invalidate(borrowerLoanRequestsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            action == 'approve'
                ? 'Loan request approved.'
                : 'Loan request declined.',
          ),
        ),
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
    final canReview = item.status.toLowerCase() == 'submitted' ||
        item.status.toLowerCase() == 'pending';

    return AlertDialog(
      title: Text(item.borrowerFullName),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detailRow('Phone', item.borrowerPhoneMasked),
            _detailRow('Amount', '₱${item.requestedAmount}'),
            _detailRow('Term', '${item.requestedTermMonths} months'),
            _detailRow(
              'Frequency',
              item.requestedPaymentFrequency.replaceAll('_', ' ').toUpperCase(),
            ),
            _detailRow(
              'Structure',
              item.requestedRepaymentStructure.replaceAll('_', ' ').toUpperCase(),
            ),
            if (item.purpose != null && item.purpose!.isNotEmpty)
              _detailRow('Purpose', item.purpose!),
            _detailRow('Submitted', item.createdAt.split('T').first),
            _detailRow('Status', item.status.toUpperCase()),
            if (item.reviewedAt != null)
              _detailRow('Reviewed', item.reviewedAt!.split('T').first),
            if (item.ownerNotes != null && item.ownerNotes!.isNotEmpty)
              _detailRow('Owner Notes', item.ownerNotes!),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _working ? null : () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        if (canReview) ...[
          TextButton(
            onPressed: _working ? null : () => _submitReview('decline'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Decline'),
          ),
          FilledButton.icon(
            onPressed: _working ? null : () => _submitReview('approve'),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0D9488)),
            icon: const Icon(Icons.check_circle_outline, size: 18),
            label: const Text('Approve'),
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
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }
}
