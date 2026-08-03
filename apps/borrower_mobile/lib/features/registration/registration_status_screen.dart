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
    final approved = s.status == 'approved' || s.status == 'active';
    final icon = s.status == 'rejected'
        ? Icons.cancel_outlined
        : approved
            ? Icons.verified_outlined
            : Icons.hourglass_top;
    return Scaffold(
        appBar: AppBar(title: const Text('Registration status')),
        body: Center(
            child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(icon,
                      size: 72,
                      color: s.status == 'rejected'
                          ? Colors.red
                          : approved
                              ? Colors.green
                              : Colors.blue),
                  const SizedBox(height: 20),
                  Text(_title(s.status),
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  Text(
                      s.error ??
                          s.message ??
                          'Checking your registration status…',
                      textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  if (s.loading)
                    const CircularProgressIndicator()
                  else
                    OutlinedButton.icon(
                        onPressed: () =>
                            ref.read(registrationProvider.notifier).refresh(),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Refresh status')),
                  if (approved) ...[
                    const SizedBox(height: 12),
                    FilledButton(
                        onPressed: () => context.go('/login'),
                        child: const Text('Verify mobile / Login'))
                  ],
                  if (s.status == 'rejected' || s.status == 'expired') ...[
                    const SizedBox(height: 12),
                    TextButton(
                        onPressed: () => context.go('/login'),
                        child: const Text('Back to login'))
                  ]
                ]))));
  }

  String _title(String value) => switch (value) {
        'approved' => 'Approved — verify mobile',
        'active' => 'Account active',
        'rejected' => 'Registration not approved',
        'expired' => 'Registration expired',
        'cancelled' => 'Registration cancelled',
        _ => 'Pending approval'
      };
}
