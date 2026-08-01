import 'package:flutter/material.dart';

class AppTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final bool obscureText;
  final int? maxLength;

  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.prefixIcon,
    this.suffixIcon,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.obscureText = false,
    this.maxLength,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF334155),
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          obscureText: obscureText,
          maxLength: maxLength,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Color(0xFF0F172A),
          ),
          decoration: InputDecoration(
            hintText: hint,
            counterText: '',
            prefixIcon: prefixIcon != null
                ? Icon(
                    prefixIcon,
                    size: 20,
                    color: const Color(0xFF64748B),
                  )
                : null,
            suffixIcon: suffixIcon,
          ),
        ),
      ],
    );
  }
}
