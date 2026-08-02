import 'package:flutter/material.dart';

import '../../../core/validation/phone_number.dart';

String? validateName(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return 'Required';
  if (text.length > 100) return 'Must be 100 characters or fewer';
  return null;
}

String? validateNationalId(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return 'Required';
  if (text.length < 4 || text.length > 100) {
    return 'Must be 4\u2013100 characters';
  }
  return null;
}

String? validatePhone(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return 'Required';
  try {
    normalizePhilippineMobileNumber(text);
  } on FormatException {
    return 'Enter a valid Philippine mobile number';
  }
  return null;
}

class FormFieldRow extends StatelessWidget {
  const FormFieldRow({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.validator,
    this.keyboardType,
    this.hintText,
    this.autofillHints,
    this.textCapitalization = TextCapitalization.none,
    this.textInputAction = TextInputAction.next,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final String? hintText;
  final Iterable<String>? autofillHints;
  final TextCapitalization textCapitalization;
  final TextInputAction textInputAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          hintText: hintText,
        ),
        keyboardType: keyboardType,
        validator: validator,
        autofillHints: autofillHints,
        textCapitalization: textCapitalization,
        textInputAction: textInputAction,
      ),
    );
  }
}
