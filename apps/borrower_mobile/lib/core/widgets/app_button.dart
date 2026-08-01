import 'package:flutter/material.dart';

class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;

  const AppButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onPressed == null || isLoading;

    return Container(
      height: 54,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDisabled
            ? []
            : [
                BoxShadow(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: EdgeInsets.zero,
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: isDisabled
                ? const LinearGradient(
                    colors: [Color(0xFF94A3B8), Color(0xFF64748B)],
                  )
                : const LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            constraints: const BoxConstraints(minWidth: 88, minHeight: 54),
            alignment: Alignment.center,
            child: isLoading
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        text,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
                      if (icon != null) ...[
                        const SizedBox(width: 8),
                        Icon(
                          icon,
                          size: 20,
                          color: Colors.white,
                        ),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
