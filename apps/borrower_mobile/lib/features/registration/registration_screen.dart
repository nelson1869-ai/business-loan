import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:borrower_mobile/features/registration/registration_notifier.dart';

class RegistrationScreen extends ConsumerStatefulWidget {
  const RegistrationScreen({super.key});
  @override
  ConsumerState<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends ConsumerState<RegistrationScreen> {
  final _key = GlobalKey<FormState>();
  final _first = TextEditingController(),
      _middle = TextEditingController(),
      _last = TextEditingController(),
      _suffix = TextEditingController(),
      _phone = TextEditingController(),
      _email = TextEditingController();
  DateTime? _birthDate;
  bool _privacy = false, _terms = false;
  @override
  void dispose() {
    for (final c in [_first, _middle, _last, _suffix, _phone, _email]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final value = await showDatePicker(
        context: context,
        initialDate: DateTime(1990),
        firstDate: DateTime(1900),
        lastDate: DateTime.now().subtract(const Duration(days: 1)));
    if (value != null) setState(() => _birthDate = value);
  }

  Future<void> _submit() async {
    if (!_key.currentState!.validate() ||
        _birthDate == null ||
        !_privacy ||
        !_terms) {
      setState(() {});
      return;
    }
    final ok = await ref.read(registrationProvider.notifier).submit({
      'firstName': _first.text.trim(),
      'middleName': _middle.text.trim().isEmpty ? null : _middle.text.trim(),
      'lastName': _last.text.trim(),
      'suffix': _suffix.text.trim().isEmpty ? null : _suffix.text.trim(),
      'phoneNumber': _phone.text.trim(),
      'dateOfBirth': _birthDate!.toIso8601String().split('T').first,
      'email': _email.text.trim().isEmpty ? null : _email.text.trim(),
      'privacyAccepted': _privacy,
      'termsAccepted': _terms
    });
    if (ok && mounted) context.go('/registration-status');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(registrationProvider);
    return Scaffold(
        appBar: AppBar(title: const Text('Create account')),
        body: Form(
            key: _key,
            child: ListView(padding: const EdgeInsets.all(24), children: [
              const Text('Request borrower portal access',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text(
                  'Your lender will review and link this request. No financial information is available before approval.'),
              const SizedBox(height: 20),
              ...[
                _field(_first, 'First name', required: true),
                _field(_middle, 'Middle name (optional)'),
                _field(_last, 'Last name', required: true),
                _field(_suffix, 'Suffix (optional)'),
                _field(_phone, 'Mobile number', required: true, phone: true),
                _field(_email, 'Email (optional)', email: true)
              ],
              ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_birthDate == null
                      ? 'Date of birth'
                      : _birthDate!.toIso8601String().split('T').first),
                  trailing: const Icon(Icons.calendar_month),
                  onTap: _pickDate),
              if (_birthDate == null)
                const Text('Date of birth is required',
                    style: TextStyle(color: Colors.red)),
              CheckboxListTile(
                  value: _privacy,
                  onChanged: (v) => setState(() => _privacy = v ?? false),
                  title: const Text('I accept the privacy notice'),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero),
              CheckboxListTile(
                  value: _terms,
                  onChanged: (v) => setState(() => _terms = v ?? false),
                  title: const Text('I accept the terms'),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero),
              if ((!_privacy || !_terms))
                const Text('Both acknowledgements are required',
                    style: TextStyle(color: Colors.red)),
              if (state.error != null)
                Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(state.error!,
                        style: const TextStyle(color: Colors.red))),
              FilledButton(
                  onPressed: state.loading ? null : _submit,
                  child: state.loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Submit for review'))
            ])));
  }

  Widget _field(TextEditingController c, String label,
          {bool required = false, bool phone = false, bool email = false}) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextFormField(
              controller: c,
              keyboardType: phone
                  ? TextInputType.phone
                  : email
                      ? TextInputType.emailAddress
                      : null,
              decoration: InputDecoration(
                  labelText: label, border: const OutlineInputBorder()),
              validator: (v) {
                final x = v?.trim() ?? '';
                if (required && x.isEmpty) {
                  return '$label is required';
                }
                if (email &&
                    x.isNotEmpty &&
                    !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(x)) {
                  return 'Enter a valid email';
                }
                return null;
              }));
}
