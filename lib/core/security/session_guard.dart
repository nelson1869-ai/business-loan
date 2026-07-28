import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_router.dart';
import '../network/api_client.dart';
import 'session_security_service.dart';

/// Locks an authenticated session after inactivity or app backgrounding.
class SessionGuard extends ConsumerStatefulWidget {
  const SessionGuard({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<SessionGuard> createState() => _SessionGuardState();
}

class _SessionGuardState extends ConsumerState<SessionGuard>
    with WidgetsBindingObserver {
  bool _locked = false;
  bool _authenticating = false;
  DateTime? _lastActivityWrite;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref.read(sessionSecurityServiceProvider).recordActivity();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    final security = ref.read(sessionSecurityServiceProvider);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      await security.recordActivity();
      return;
    }
    if (state != AppLifecycleState.resumed) return;
    final enabled = await security.isBiometricEnabled();
    final idle = await security.isSessionIdle();
    if (mounted && enabled && idle) {
      setState(() => _locked = true);
      await _unlock();
    }
  }

  Future<void> _unlock() async {
    if (_authenticating) return;
    setState(() => _authenticating = true);
    final authenticated = await ref
        .read(sessionSecurityServiceProvider)
        .authenticate();
    if (!mounted) return;
    setState(() {
      _authenticating = false;
      _locked = !authenticated;
    });
    if (authenticated) {
      await ref.read(sessionSecurityServiceProvider).recordActivity();
    }
  }

  Future<void> _signInAgain() async {
    final storage = ref.read(secureStorageProvider);
    await Future.wait([
      storage.delete(key: TokenStorageKeys.accessToken),
      storage.delete(key: TokenStorageKeys.refreshToken),
    ]);
    appRouter.go('/login');
    if (mounted) setState(() => _locked = false);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) {
        final now = DateTime.now();
        if (_lastActivityWrite == null ||
            now.difference(_lastActivityWrite!) > const Duration(seconds: 30)) {
          _lastActivityWrite = now;
          ref.read(sessionSecurityServiceProvider).recordActivity();
        }
      },
      child: Stack(
        children: [
          widget.child,
          if (_locked)
            Positioned.fill(
              child: ColoredBox(
                color: Theme.of(context).colorScheme.surface,
                child: SafeArea(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.lock_outline, size: 56),
                            const SizedBox(height: 16),
                            Text(
                              'Session locked',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Authenticate with your device credential or '
                              'sign in with your account password.',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            FilledButton.icon(
                              onPressed: _authenticating ? null : _unlock,
                              icon: const Icon(Icons.fingerprint),
                              label: Text(
                                _authenticating ? 'Authenticating…' : 'Unlock',
                              ),
                            ),
                            TextButton(
                              onPressed: _authenticating ? null : _signInAgain,
                              child: const Text('Sign in with password'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
