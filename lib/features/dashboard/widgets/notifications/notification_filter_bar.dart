import 'package:flutter/material.dart';
import 'package:lending_nelson/core/presentation/design_system/design_system.dart';

/// Horizontal filter bar for Notification Categories.
class NotificationFilterBar extends StatelessWidget {
  final String selectedFilter;
  final ValueChanged<String> onFilterChanged;

  const NotificationFilterBar({
    super.key,
    required this.selectedFilter,
    required this.onFilterChanged,
  });

  static const filters = [
    'All',
    'Unread',
    'Today',
    'Collections',
    'Borrowers',
    'Loans',
    'System',
    'High Priority',
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((filter) {
          final isSelected = selectedFilter == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: AppFilterChip(
              label: filter,
              isSelected: isSelected,
              onSelected: () => onFilterChanged(filter),
            ),
          );
        }).toList(),
      ),
    );
  }
}
