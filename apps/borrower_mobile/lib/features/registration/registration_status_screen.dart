import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:borrower_mobile/features/registration/registration_notifier.dart';

class RegistrationStatusScreen extends ConsumerStatefulWidget {
  const RegistrationStatusScreen({super.key});
  @override
  ConsumerState<RegistrationStatusScreen> createState() =>
      _RegistrationStatusScreenState();
}

class _RegistrationStatusScreenState
    extends ConsumerState<RegistrationStatusScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(registrationProvider.notifier).refresh());
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(registrationProvider);
    final isApproved = s.status == 'approved';
    final isActive = s.status == 'active';
    final isDone = isApproved || isActive;

    final icon = s.status == 'rejected'
        ? Icons.cancel_outlined
        : isDone
            ? Icons.verified_outlined
            : Icons.hourglass_top;

    return Scaffold(
      appBar: AppBar(title: const Text('Registration status')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 72,
                color: s.status == 'rejected'
                    ? Colors.red
                    : isDone
                        ? Colors.green
                        : Colors.blue,
              ),
              const SizedBox(height: 20),
              Text(
                _title(s.status),
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                s.error ?? _message(s),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (s.loading)
                const CircularProgressIndicator()
              else
                OutlinedButton.icon(
                  onPressed: () =>
                      ref.read(registrationProvider.notifier).refresh(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh status'),
                ),
              if (isApproved) ...[
                const SizedBox(height: 12),
                FilledButton.icon(
                  icon: const Icon(Icons.vpn_key),
                  label: const Text('Activate Account'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0D9488),
                  ),
                  onPressed: () => context.go('/activation'),
                ),
              ],
              if (isActive) ...[
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('Go to Login'),
                ),
              ],
              if (s.status == 'rejected' ||
                  s.status == 'expired' ||
                  s.status == 'cancelled') ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('Back to login'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _title(String value) => switch (value) {
        'approved' => 'Registration Approved',
        'active' => 'Account Active',
        'rejected' => 'Registration Not Approved',
        'expired' => 'Registration Expired',
        'cancelled' => 'Registration Cancelled',
        _ => 'Pending Approval'
      };

  String _message(RegistrationState s) {
    if (s.message != null && s.message!.isNotEmpty) {
      return s.message!;
    }
    return switch (s.status) {
      'approved' =>
        'Your lender approved your registration. Use your activation code to activate your Borrower App account.',
      'active' => 'Your account is activated and ready for login.',
      'rejected' => 'Your registration application was not approved by the lender.',
      'expired' => 'Your registration status request has expired.',
      'cancelled' => 'Your registration application was cancelled.',
      _ => 'Your registration application is under review by your lender.'
    };
  }
}
