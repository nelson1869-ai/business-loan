import 'package:flutter/material.dart';
import 'package:lending_nelson/core/presentation/design_system/design_system.dart';

/// Filter chips bar for Collection Tasks.
class CollectionFilterBar extends StatelessWidget {
  final String selectedFilter;
  final ValueChanged<String> onFilterChanged;

  const CollectionFilterBar({
    super.key,
    required this.selectedFilter,
    required this.onFilterChanged,
  });

  static const filters = [
    'All',
    'Today',
    'Overdue',
    'Promise To Pay',
    'Visit',
    'Call',
    'Message',
    'Completed',
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
