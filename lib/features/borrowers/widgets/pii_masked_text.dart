import 'package:flutter/material.dart';

/// A reusable widget that displays PII (Phone or National ID) masked by default,
/// with an interactive eye toggle icon button to show/hide full value on demand.
class PIIMaskedText extends StatefulWidget {
  const PIIMaskedText({
    super.key,
    required this.value,
    required this.icon,
    required this.label,
    this.isPhone = false,
  });

  final String value;
  final IconData icon;
  final String label;
  final bool isPhone;

  @override
  State<PIIMaskedText> createState() => _PIIMaskedTextState();
}

class _PIIMaskedTextState extends State<PIIMaskedText> {
  bool _isUnmasked = false;

  String _maskValue(String raw) {
    if (raw.length <= 4) return '****';
    if (widget.isPhone) {
      return '${raw.substring(0, 4)}****${raw.substring(raw.length - 3)}';
    }
    return '${'*' * (raw.length - 4)}${raw.substring(raw.length - 4)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayValue = _isUnmasked ? widget.value : _maskValue(widget.value);

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Icon(
            widget.icon,
            size: 14,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '${widget.label}: $displayValue',
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
          IconButton(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            padding: EdgeInsets.zero,
            iconSize: 20,
            icon: Icon(
              _isUnmasked
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            tooltip: _isUnmasked ? 'Mask PII' : 'Show full PII',
            onPressed: () => setState(() => _isUnmasked = !_isUnmasked),
          ),
        ],
      ),
    );
  }
}
