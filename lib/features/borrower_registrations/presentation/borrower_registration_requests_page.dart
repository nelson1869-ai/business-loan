import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

final pendingRegistrationsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final response = await ref
          .watch(apiClientProvider)
          .get<List<dynamic>>('/api/v1/borrower-registration-requests');
      return (response.data ?? const []).cast<Map<String, dynamic>>();
    });

/// Online-only review queue for public borrower portal applications.
class BorrowerRegistrationRequestsPage extends ConsumerWidget {
  const BorrowerRegistrationRequestsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingRegistrationsProvider);
    final count = pending.valueOrNull?.length;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Pending Borrower Registrations${count == null ? '' : ' ($count)'}',
        ),
      ),
      body: pending.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => _LoadError(
          onRetry: () => ref.invalidate(pendingRegistrationsProvider),
        ),
        data: (items) => items.isEmpty
            ? const Center(child: Text('No pending registration requests.'))
            : RefreshIndicator(
                onRefresh: () =>
                    ref.refresh(pendingRegistrationsProvider.future),
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.person_search),
                        ),
                        title: Text('${item['firstName']} ${item['lastName']}'),
                        subtitle: Text(
                          '${item['maskedPhone']} • ${_date(item['submittedAt'])}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) => _ReviewSheet(
                            item: item,
                            onChanged: () =>
                                ref.invalidate(pendingRegistrationsProvider),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }

  static String _date(Object? value) =>
      value?.toString().split('T').first ?? '';
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Unable to load registrations. This action requires a connection.',
        ),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    ),
  );
}

class _ReviewSheet extends ConsumerStatefulWidget {
  const _ReviewSheet({required this.item, required this.onChanged});
  final Map<String, dynamic> item;
  final VoidCallback onChanged;
  @override
  ConsumerState<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends ConsumerState<_ReviewSheet> {
  String? _borrowerId;
  String? _errorMessage;
  bool _loading = false;
  List<Map<String, dynamic>> _borrowers = const [];

  @override
  void initState() {
    super.initState();
    _loadBorrowers();
  }

  Future<void> _loadBorrowers() async {
    try {
      final response = await ref
          .read(apiClientProvider)
          .get<List<dynamic>>(
            '/api/v1/borrowers',
            queryParameters: {'limit': 100},
          );
      if (mounted) {
        setState(
          () => _borrowers = (response.data ?? const [])
              .cast<Map<String, dynamic>>(),
        );
      }
    } on DioException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to load borrower matches.')),
        );
      }
    }
  }

  Future<void> _approve() async {
    Map<String, dynamic>? selected;
    for (final borrower in _borrowers) {
      if (borrower['id'] == _borrowerId) selected = borrower;
    }
    if (selected == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm financial-record link'),
        content: Text(
          'Applicant: ${widget.item['firstName']} ${widget.item['lastName']}\n'
          'Selected borrower: ${selected!['firstName']} ${selected['lastName']}\n'
          'Phone: ${widget.item['maskedPhone']}\n'
          'Date of birth: ${widget.item['dateOfBirth']}\n\n'
          'This link controls access to loans, balances, payments, schedules, and receipts.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Approve and link'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _post('approve', {'borrowerId': _borrowerId});
  }

  Future<void> _createAndApprove() async {
    String? nationalId;
    if (widget.item['hasNationalId'] != true) {
      final controller = TextEditingController();
      nationalId = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Create borrower record'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 100,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'National ID',
              helperText: 'Required for this older registration request',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();
                if (value.length >= 4) Navigator.pop(context, value);
              },
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      controller.dispose();
      if (nationalId == null || !mounted) return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create and approve?'),
        content: Text(
          'Applicant: ${widget.item['firstName']} ${widget.item['lastName']}\n'
          'Phone: ${widget.item['maskedPhone']}\n'
          'National ID: ${widget.item['maskedNationalId'] ?? 'Provided'}\n'
          'Date of birth: ${widget.item['dateOfBirth']}\n\n'
          'A new borrower record will be created and linked to this portal account. '
          'This grants access to that borrower’s financial records. Confirm the identity before continuing.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Create and approve'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _post('create-and-approve', {
        // ignore: use_null_aware_elements
        if (nationalId != null) 'nationalId': nationalId,
      });
    }
  }

  Future<void> _reject() async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject registration'),
        content: TextField(
          controller: controller,
          maxLength: 500,
          decoration: const InputDecoration(
            labelText: 'Borrower-facing reason',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason != null && reason.isNotEmpty) {
      await _post('reject', {'reason': reason});
    }
  }

  Future<void> _post(String action, Map<String, dynamic> data) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      await ref
          .read(apiClientProvider)
          .post<void>(
            '/api/v1/borrower-registration-requests/${widget.item['id']}/$action',
            data: data,
          );
      widget.onChanged();
      if (mounted) {
        Navigator.pop(context);
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                action == 'create-and-approve'
                    ? 'Borrower created and registration approved.'
                    : action == 'approve'
                    ? 'Registration approved and linked.'
                    : 'Registration rejected.',
              ),
            ),
          );
      }
    } on DioException catch (error) {
      if (mounted) {
        final data = error.response?.data;
        final message = data is Map ? data['detail']?.toString() : null;
        setState(
          () => _errorMessage =
              message ??
              'The decision could not be submitted. Check the connection and try again.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _errorMessage =
              'An unexpected error occurred. No borrower was created. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${widget.item['firstName']} ${widget.item['lastName']}',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Text(
            '${widget.item['maskedPhone']} • ID ${widget.item['maskedNationalId'] ?? 'Not provided'} • DOB ${widget.item['dateOfBirth']}',
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _borrowerId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Explicitly select existing borrower',
              border: OutlineInputBorder(),
            ),
            items: _borrowers
                .map(
                  (borrower) => DropdownMenuItem(
                    value: borrower['id'] as String,
                    child: Text(
                      '${borrower['firstName']} ${borrower['lastName']} • ${borrower['phone']}',
                    ),
                  ),
                )
                .toList(),
            onChanged: _loading
                ? null
                : (value) => setState(() => _borrowerId = value),
          ),
          const SizedBox(height: 12),
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _errorMessage!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          FilledButton(
            onPressed: _loading || _borrowerId == null ? null : _approve,
            child: const Text('Link existing borrower'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _loading ? null : _createAndApprove,
            child: const Text('Create borrower and approve'),
          ),
          TextButton(
            onPressed: _loading ? null : _reject,
            child: const Text('Reject request'),
          ),
          if (_loading) const LinearProgressIndicator(),
          if (_loading) ...[
            const SizedBox(height: 8),
            const Text(
              'Submitting decision… Please wait.',
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    ),
  );
}
