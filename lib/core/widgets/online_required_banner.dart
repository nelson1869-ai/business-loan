import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/server_health_service.dart';

/// Visible guard for workflows intentionally unsupported offline.
class OnlineRequiredBanner extends ConsumerWidget {
  const OnlineRequiredBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online =
        ref.watch(serverStatusNotifierProvider) == ServerStatus.serverReady;
    if (online) return const SizedBox.shrink();
    return MaterialBanner(
      content: const Text(
        'Internet connection required. This financial control is not queued offline.',
      ),
      leading: const Icon(Icons.cloud_off_outlined),
      actions: [
        TextButton(
          onPressed: () =>
              ref.read(serverStatusNotifierProvider.notifier).refreshStatus(),
          child: const Text('Retry'),
        ),
      ],
    );
  }
}

/// Whether the backend is currently reachable for online-only actions.
final backendOnlineProvider = Provider<bool>((ref) {
  return ref.watch(serverStatusNotifierProvider) == ServerStatus.serverReady;
});
