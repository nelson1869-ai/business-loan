import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_error_mapper.dart';
import '../domain/borrower_model.dart';

/// App access status model returned by GET /api/v1/borrowers/{borrowerId}/app-access
class BorrowerAppAccessStatus {
  final bool hasAccount;
  final String? accountId;
  final String? accountStatus;
  final String? phoneNumber;
  final bool activationPending;
  final String? activationExpiresAt;
  final int trustedDevicesCount;
  final String? lastLoginAt;
  final bool canRegenerateActivationCode;

  const BorrowerAppAccessStatus({
    required this.hasAccount,
    this.accountId,
    this.accountStatus,
    this.phoneNumber,
    required this.activationPending,
    this.activationExpiresAt,
    required this.trustedDevicesCount,
    this.lastLoginAt,
    required this.canRegenerateActivationCode,
  });

  factory BorrowerAppAccessStatus.fromJson(Map<String, dynamic> json) {
    return BorrowerAppAccessStatus(
      hasAccount: json['hasAccount'] as bool? ?? false,
      accountId: json['accountId'] as String?,
      accountStatus: json['accountStatus'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      activationPending: json['activationPending'] as bool? ?? false,
      activationExpiresAt: json['activationExpiresAt'] as String?,
      trustedDevicesCount: json['trustedDevicesCount'] as int? ?? 0,
      lastLoginAt: json['lastLoginAt'] as String?,
      canRegenerateActivationCode:
          json['canRegenerateActivationCode'] as bool? ?? false,
    );
  }
}

final borrowerAppAccessStatusProvider = FutureProvider.autoDispose
    .family<BorrowerAppAccessStatus, String>((ref, borrowerId) async {
  final dio = ref.watch(apiClientProvider);
  final response = await dio.get<Map<String, dynamic>>(
    '/api/v1/borrowers/$borrowerId/app-access',
  );
  return BorrowerAppAccessStatus.fromJson(response.data ?? {});
});

/// Owner App widget displaying Borrower App Access state & management actions.
class BorrowerAppAccessCard extends ConsumerStatefulWidget {
  final Borrower borrower;

  const BorrowerAppAccessCard({super.key, required this.borrower});

  @override
  ConsumerState<BorrowerAppAccessCard> createState() =>
      _BorrowerAppAccessCardState();
}

class _BorrowerAppAccessCardState
    extends ConsumerState<BorrowerAppAccessCard> {
  bool _working = false;

  Future<void> _enableAccess() async {
    setState(() => _working = true);
    try {
      final dio = ref.read(apiClientProvider);
      final response = await dio.post<Map<String, dynamic>>(
        '/api/v1/borrowers/${widget.borrower.id}/enable-app-access',
      );
      final data = response.data ?? {};
      final code = data['activationCode'] as String? ?? '';
      final expires = data['expiresAt'] as String? ?? '';

      ref.invalidate(borrowerAppAccessStatusProvider(widget.borrower.id));

      if (mounted) {
        _showOneTimeCodeDialog(code, expires);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ApiErrorMapper.message(e)),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _regenerateCode(String accountId) async {
    setState(() => _working = true);
    try {
      final dio = ref.read(apiClientProvider);
      final response = await dio.post<Map<String, dynamic>>(
        '/api/v1/borrowers/accounts/$accountId/reset-code',
      );
      final data = response.data ?? {};
      final code = data['resetCode'] as String? ?? '';
      final expires = data['expiresAt'] as String? ?? '';

      ref.invalidate(borrowerAppAccessStatusProvider(widget.borrower.id));

      if (mounted) {
        _showOneTimeCodeDialog(code, expires);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ApiErrorMapper.message(e)),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _accountAction(
      String accountId, String action, String reason) async {
    setState(() => _working = true);
    try {
      final dio = ref.read(apiClientProvider);
      await dio.post(
        '/api/v1/borrower-accounts/$accountId/$action',
        data: {'reason': reason},
      );
      ref.invalidate(borrowerAppAccessStatusProvider(widget.borrower.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Account state updated to $action.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ApiErrorMapper.message(e)),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _showOneTimeCodeDialog(String code, String expiresAt) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.vpn_key, color: Color(0xFF0D9488)),
            SizedBox(width: 8),
            Text('Borrower App Activation Code'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Give this 6-digit code to the borrower. Generating a new code automatically revokes previous codes.',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: SelectableText(
                code,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 8,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Expires: $expiresAt',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            const Text(
              'Note: After closing this dialog, the plaintext code will NOT be shown again.',
              style: TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: Color(0xFFD97706),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Copy Code'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Activation code copied.')),
              );
            },
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D9488),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusAsync =
        ref.watch(borrowerAppAccessStatusProvider(widget.borrower.id));

    return Card(
      margin: EdgeInsets.zero,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: statusAsync.when(
          loading: () => const Center(
            child: SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          error: (err, _) => Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.red),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Error loading app access status: ${ApiErrorMapper.message(err)}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          data: (status) => _buildContent(status),
        ),
      ),
    );
  }

  Widget _buildContent(BorrowerAppAccessStatus status) {
    final theme = Theme.of(context);

    if (!status.hasAccount) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.phonelink_lock, color: Color(0xFF64748B)),
              const SizedBox(width: 8),
              Text(
                'Borrower App Access',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Chip(
                label: const Text('Not Enabled'),
                labelStyle: const TextStyle(fontSize: 11, color: Colors.white),
                backgroundColor: const Color(0xFF64748B),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Grant this borrower self-service access to view loans, schedules, and receipts without duplicating records.',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: _working
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.key, size: 18),
              label: const Text('Enable Borrower App Access'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D9488),
                foregroundColor: Colors.white,
              ),
              onPressed: _working ? null : _enableAccess,
            ),
          ),
        ],
      );
    }

    final st = (status.accountStatus ?? 'approved').toLowerCase();

    if (st == 'approved' || st == 'pending') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.mark_email_read, color: Color(0xFFD97706)),
              const SizedBox(width: 8),
              Text(
                'Borrower App Access',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Chip(
                label: const Text('Awaiting Activation'),
                labelStyle: const TextStyle(fontSize: 11, color: Colors.white),
                backgroundColor: const Color(0xFFD97706),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (status.activationExpiresAt != null)
            Text(
              'Code expires at: ${status.activationExpiresAt}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Generate New Code'),
                  onPressed: _working || status.accountId == null
                      ? null
                      : () => _regenerateCode(status.accountId!),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.block, size: 16, color: Colors.red),
                  label: const Text('Disable Access',
                      style: TextStyle(color: Colors.red)),
                  onPressed: _working || status.accountId == null
                      ? null
                      : () => _accountAction(
                            status.accountId!,
                            'disable',
                            'Disabled by owner from borrower profile',
                          ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    if (st == 'activated') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_user, color: Color(0xFF0D9488)),
              const SizedBox(width: 8),
              Text(
                'Borrower App Access',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Chip(
                label: const Text('Active'),
                labelStyle: const TextStyle(fontSize: 11, color: Colors.white),
                backgroundColor: const Color(0xFF0D9488),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Phone: ${status.phoneNumber ?? widget.borrower.phone}',
              style: const TextStyle(fontSize: 12)),
          Text('Trusted Devices: ${status.trustedDevicesCount}',
              style: const TextStyle(fontSize: 12)),
          if (status.lastLoginAt != null)
            Text('Last Login: ${status.lastLoginAt}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.lock_reset, size: 16),
                label: const Text('Reset PIN'),
                onPressed: _working || status.accountId == null
                    ? null
                    : () => _regenerateCode(status.accountId!),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.pause_circle_outline, size: 16),
                label: const Text('Suspend'),
                onPressed: _working || status.accountId == null
                    ? null
                    : () => _accountAction(
                          status.accountId!,
                          'suspend',
                          'Suspended by owner',
                        ),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.block, size: 16, color: Colors.red),
                label: const Text('Disable', style: TextStyle(color: Colors.red)),
                onPressed: _working || status.accountId == null
                    ? null
                    : () => _accountAction(
                          status.accountId!,
                          'disable',
                          'Disabled by owner',
                        ),
              ),
            ],
          ),
        ],
      );
    }

    // Suspended / Disabled state
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.warning, color: Colors.red),
            const SizedBox(width: 8),
            Text(
              'Borrower App Access',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            Chip(
              label: Text(st == 'suspended' ? 'Suspended' : 'Disabled'),
              labelStyle: const TextStyle(fontSize: 11, color: Colors.white),
              backgroundColor: Colors.red.shade700,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          st == 'suspended'
              ? 'App access is currently suspended.'
              : 'App access is currently disabled.',
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            if (st == 'suspended')
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.play_arrow, size: 16),
                  label: const Text('Reactivate'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D9488),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _working || status.accountId == null
                      ? null
                      : () => _accountAction(
                            status.accountId!,
                            'reactivate',
                            'Reactivated by owner',
                          ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
