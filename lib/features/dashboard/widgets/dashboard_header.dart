import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/server_health_service.dart';

class DashboardHeader extends ConsumerStatefulWidget {
  const DashboardHeader({super.key});

  @override
  ConsumerState<DashboardHeader> createState() => _DashboardHeaderState();
}

class _DashboardHeaderState extends ConsumerState<DashboardHeader> {
  static const _businessUtcOffset = Duration(hours: 8);
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final serverStatus = ref.watch(serverStatusNotifierProvider);
    final isOnline = serverStatus == ServerStatus.serverReady;
    final theme = Theme.of(context);
    // Lending Nelson operates on Philippine/Singapore business time. Using an
    // explicit UTC offset keeps Android emulators configured as UTC from
    // displaying yesterday's date.
    final now = DateTime.now().toUtc().add(_businessUtcOffset);
    final dayNames = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final monthNames = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final greeting = _greeting(now.hour);

    return Row(
      children: [
        CircleAvatar(
          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
          child: Icon(Icons.person, color: theme.colorScheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$greeting, Business Owner',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${dayNames[now.weekday - 1]}, ${monthNames[now.month - 1]} ${now.day}, ${now.year}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        _StatusBadge(isOnline: isOnline),
      ],
    );
  }

  String _greeting(int hour) {
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.isOnline});

  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isOnline
            ? Colors.green.withValues(alpha: 0.1)
            : Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOnline ? Colors.green : Colors.orange,
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isOnline ? Icons.cloud_done : Icons.cloud_off,
            size: 14,
            color: isOnline ? Colors.green.shade700 : Colors.orange.shade700,
          ),
          const SizedBox(width: 4),
          Text(
            isOnline ? 'Server ready' : 'Server offline',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isOnline ? Colors.green.shade700 : Colors.orange.shade700,
            ),
          ),
        ],
      ),
    );
  }
}
