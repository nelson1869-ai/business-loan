import 'package:flutter/material.dart';

/// Standardized Search Bar component across all search fields.
class AppSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;

  const AppSearchBar({
    super.key,
    required this.controller,
    this.hintText = 'Search...',
    this.onChanged,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return SearchBar(
      controller: controller,
      hintText: hintText,
      leading: const Icon(Icons.search, size: 20),
      trailing: [
        if (controller.text.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.clear, size: 18),
            onPressed: () {
              controller.clear();
              if (onClear != null) onClear!();
              if (onChanged != null) onChanged!('');
            },
          ),
      ],
      onChanged: onChanged,
      elevation: const WidgetStatePropertyAll(1),
    );
  }
}
