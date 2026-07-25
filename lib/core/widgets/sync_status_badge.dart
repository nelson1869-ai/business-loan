import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/offline_sync_service.dart';
import '../network/server_health_service.dart';

/// Interactive/visual badge indicating device offline state and sync queue health.
class SyncStatusBadge extends ConsumerWidget {
  const SyncStatusBadge({super.key, this.showLabel = true, this.onTap});

  final bool showLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serverStatus = ref.watch(serverStatusNotifierProvider);
    final queueState = ref.watch(offlineSyncQueueNotifierProvider);

    final bool isOffline = serverStatus != ServerStatus.serverReady;
    final int pending = queueState.pendingCount;
    final int conflicts = queueState.conflictCount;
    final int failures =
        queueState.permanentlyFailedCount + queueState.retryableFailedCount;

    Color badgeColor;
    IconData badgeIcon;
    String label;

    if (conflicts > 0) {
      badgeColor = Colors.orange.shade700;
      badgeIcon = Icons.warning_amber_rounded;
      label = '$conflicts Conflict${conflicts > 1 ? 's' : ''}';
    } else if (failures > 0) {
      badgeColor = Colors.red.shade600;
      badgeIcon = Icons.error_outline;
      label = '$failures Sync Error${failures > 1 ? 's' : ''}';
    } else if (pending > 0) {
      badgeColor = Colors.amber.shade800;
      badgeIcon = Icons.cloud_upload_outlined;
      label = '$pending Pending Sync';
    } else if (isOffline) {
      badgeColor = Colors.blueGrey;
      badgeIcon = Icons.cloud_off;
      label = 'Offline Mode';
    } else {
      badgeColor = Colors.green.shade700;
      badgeIcon = Icons.cloud_done;
      label = 'Synced';
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: badgeColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: badgeColor.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(badgeIcon, size: 16, color: badgeColor),
            if (showLabel) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: badgeColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
