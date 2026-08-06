import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_error_mapper.dart';
import '../../../../core/security/officer_session.dart';
import '../../../../core/security/security_confirmation_service.dart';
import '../../../../core/widgets/online_required_banner.dart';
import '../../../borrowers/data/borrower_repository.dart';
import '../../../borrowers/domain/borrower_model.dart';
import '../../data/repositories/remote_loan_repository.dart';
import '../../domain/models/loan.dart';
import '../providers/loans_provider.dart';

/// Single-owner controls for loan lifecycle (Approve & Activate, Disburse, etc.).
class LoanWorkflowActions extends ConsumerWidget {
  const LoanWorkflowActions({required this.loan, super.key});

  final Loan loan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Hide entirely for terminal / active states
    if (loan.status == 'Active' ||
        loan.status == 'Paid' ||
        loan.status == 'Closed' ||
        loan.status == 'Cancelled' ||
        loan.status == 'Defaulted') {
      return const SizedBox.shrink();
    }

    final session = ref.watch(officerSessionProvider).valueOrNull;
    final online = ref.watch(backendOnlineProvider);
    final canManage = session?.can('loan.approve') == true ||
        session?.can('loan.create') == true ||
        session?.role == 'admin' ||
        session?.role == 'owner';

    // ── DRAFT LOAN ──────────────────────────────────────────────────────────
    if (loan.status == 'Draft' && loan.approvedAt == null) {
      return _ActionCard(
        statusText: 'Draft Loan — Awaiting Owner Approval',
        children: [
          OutlinedButton.icon(
            onPressed: online && canManage ? () => _cancelDraft(context, ref) : null,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red.shade700,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: const TextStyle(fontSize: 12),
            ),
            icon: const Icon(Icons.cancel_outlined, size: 15),
            label: const Text('Cancel Draft'),
          ),
          FilledButton.icon(
            onPressed: online && canManage
                ? () => _promptApproveAndActivate(context, ref)
                : null,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0D9488),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              textStyle:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            icon: const Icon(Icons.rocket_launch_outlined, size: 17),
            label: const Text('APPROVE & ACTIVATE'),
          ),
        ],
      );
    }

    // ── DRAFT → approved but not disbursed ───────────────────────────────
    if (loan.status == 'Draft' && loan.approvedAt != null && loan.disbursedAt == null) {
      return _ActionCard(
        statusText: 'Approved — ready for disbursement',
        children: [
          FilledButton.icon(
            onPressed: online && canManage
                ? () => _transition(context, ref, 'disburse',
                    title: 'Disburse Funds',
                    label: 'Release Funds')
                : null,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0D9488),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            icon: const Icon(Icons.payments_outlined, size: 17),
            label: const Text('Disburse Funds'),
          ),
        ],
      );
    }

    // ── DRAFT → disbursed but not activated ──────────────────────────────
    if (loan.status == 'Draft' && loan.disbursedAt != null && loan.activatedAt == null) {
      return _ActionCard(
        statusText: 'Disbursed — ready for activation',
        children: [
          FilledButton.icon(
            onPressed: online && canManage
                ? () => _transition(context, ref, 'activate',
                    title: 'Activate Loan',
                    label: 'Activate')
                : null,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            icon: const Icon(Icons.bolt, size: 17),
            label: const Text('Activate Schedule'),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _promptApproveAndActivate(
    BuildContext context,
    WidgetRef ref,
  ) async {
    // Fetch borrower details for rich single-owner confirmation
    Borrower? borrower;
    try {
      borrower = await ref
          .read(borrowerRepositoryProvider)
          .getBorrower(loan.borrowerId);
    } catch (_) {}

    if (!context.mounted) return;

    final borrowerName = borrower != null
        ? '${borrower.firstName} ${borrower.lastName}'
        : 'Borrower ID: ${loan.borrowerId.substring(0, loan.borrowerId.length > 8 ? 8 : loan.borrowerId.length)}';

    final double rate = double.tryParse(loan.monthlyRate) ?? 0.0;
    final String rateStr = (rate * 100).toStringAsFixed(2);
    final double regularPayment =
        double.tryParse(loan.regularPaymentAmount) ?? 0.0;
    final double totalRepayment = regularPayment * loan.numberOfPayments;

    // Show single unified review & PIN security confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _SingleOwnerReviewDialog(
        loan: loan,
        borrowerName: borrowerName,
        monthlyRatePercent: rateStr,
        totalRepayment: totalRepayment.toStringAsFixed(2),
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await ref
          .read(remoteLoanRepositoryProvider)
          .transition(loan.id, 'approve_and_activate');
      ref.invalidate(loanDetailProvider(loan.id));
      ref.invalidate(allLoansProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Loan approved and activated successfully!'),
            backgroundColor: Color(0xFF0D9488),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) _showError(context, error);
    }
  }

  Future<void> _cancelDraft(BuildContext context, WidgetRef ref) async {
    final confirm = await ref
        .read(securityConfirmationServiceProvider)
        .promptAdminConfirmation(
          context,
          title: 'Cancel Draft Loan',
          description:
              'Are you sure you want to cancel this draft loan application?',
          confirmLabel: 'Cancel Loan',
        );
    if (!confirm || !context.mounted) return;

    try {
      await ref.read(remoteLoanRepositoryProvider).transition(loan.id, 'cancel');
      ref.invalidate(loanDetailProvider(loan.id));
      ref.invalidate(allLoansProvider);
    } catch (error) {
      if (context.mounted) _showError(context, error);
    }
  }

  Future<void> _transition(
    BuildContext context,
    WidgetRef ref,
    String action, {
    required String title,
    required String label,
  }) async {
    final confirm = await ref
        .read(securityConfirmationServiceProvider)
        .promptAdminConfirmation(
          context,
          title: title,
          description:
              'Confirm $action for Loan #${loan.id.substring(0, loan.id.length > 8 ? 8 : loan.id.length)} (₱${loan.originalPrincipal})',
          confirmLabel: label,
        );
    if (!confirm || !context.mounted) return;

    try {
      await ref.read(remoteLoanRepositoryProvider).transition(loan.id, action);
      ref.invalidate(loanDetailProvider(loan.id));
      ref.invalidate(allLoansProvider);
    } catch (error) {
      if (context.mounted) _showError(context, error);
    }
  }

  void _showError(BuildContext context, Object error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ApiErrorMapper.message(error))),
    );
  }
}

// ── Single Owner Review & Security PIN Dialog (1 Popup) ──────────────────────

class _SingleOwnerReviewDialog extends ConsumerStatefulWidget {
  const _SingleOwnerReviewDialog({
    required this.loan,
    required this.borrowerName,
    required this.monthlyRatePercent,
    required this.totalRepayment,
  });

  final Loan loan;
  final String borrowerName;
  final String monthlyRatePercent;
  final String totalRepayment;

  @override
  ConsumerState<_SingleOwnerReviewDialog> createState() =>
      __SingleOwnerReviewDialogState();
}

class __SingleOwnerReviewDialogState
    extends ConsumerState<_SingleOwnerReviewDialog> {
  final TextEditingController _pinCtrl = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _pinCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleConfirm() async {
    final pin = _pinCtrl.text.trim();
    if (pin.length < 4) {
      setState(() => _errorMessage = 'Enter 4-digit security PIN (Default: 1234)');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final secService = ref.read(securityConfirmationServiceProvider);
    final isValid = await secService.verifyPin(pin);
    if (!mounted) return;

    if (isValid) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Incorrect PIN (Default: 1234)';
        _pinCtrl.clear();
      });
    }
  }

  Future<void> _handleBiometric() async {
    final secService = ref.read(securityConfirmationServiceProvider);
    final isBioAvailable = await secService.isBiometricAvailable();
    if (!isBioAvailable) {
      setState(() => _errorMessage = 'Biometric authentication is not set up');
      return;
    }

    final success = await secService.authenticateBiometric(
      reason: 'Approve & Activate Loan #${widget.loan.id.substring(0, widget.loan.id.length > 8 ? 8 : widget.loan.id.length)}',
    );
    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF0D9488).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.verified_outlined,
              color: Color(0xFF0D9488),
              size: 22,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Approve & Activate',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Review terms and verify PIN to activate loan:',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            _detailRow('Borrower', widget.borrowerName, isDark, isHighlight: true),
            const Divider(height: 12),
            _detailRow('Principal', '₱${widget.loan.originalPrincipal}', isDark, isHighlight: true),
            _detailRow('Interest Rate', '${widget.monthlyRatePercent}% / month', isDark),
            _detailRow(
              'Loan Term',
              '${widget.loan.termMonths} months (${widget.loan.numberOfPayments} payments)',
              isDark,
            ),
            _detailRow('Installment', '₱${widget.loan.regularPaymentAmount}', isDark),
            _detailRow('Total Repayment', '₱${widget.totalRepayment}', isDark, isHighlight: true),
            _detailRow('First Due Date', widget.loan.firstDueDate, isDark),
            const SizedBox(height: 16),
            TextField(
              controller: _pinCtrl,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 6,
              decoration: InputDecoration(
                labelText: 'Owner Security PIN',
                hintText: 'PIN (Default: 1234)',
                counterText: '',
                errorText: _errorMessage,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.lock_outline, size: 20),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.fingerprint, size: 22),
                  tooltip: 'Biometric Auth',
                  onPressed: _handleBiometric,
                ),
              ),
              onSubmitted: (_) => _handleConfirm(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _isLoading ? null : _handleConfirm,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF0D9488),
          ),
          icon: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.check_circle_outline, size: 18),
          label: const Text('Confirm & Activate'),
        ),
      ],
    );
  }

  Widget _detailRow(
    String label,
    String value,
    bool isDark, {
    bool isHighlight = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isHighlight
                  ? (isDark ? Colors.white : Colors.black87)
                  : (isDark ? Colors.white70 : Colors.black54),
              fontWeight: isHighlight ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isHighlight ? FontWeight.bold : FontWeight.w500,
                color: isHighlight
                    ? const Color(0xFF10B981)
                    : (isDark ? Colors.white : Colors.black87),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared card shell ───────────────────────────────────────────────────────

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.statusText, required this.children});

  final String statusText;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.account_tree_outlined, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    statusText,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: children,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
