import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/formatters.dart';
import '../domain/borrower_model.dart';
import '../providers/borrower_registration_notifier.dart';
import '../widgets/borrower_registration_form.dart';

class BorrowerRegistrationPage extends ConsumerStatefulWidget {
  final Borrower? borrower;

  const BorrowerRegistrationPage({super.key, this.borrower});

  @override
  ConsumerState<BorrowerRegistrationPage> createState() =>
      _BorrowerRegistrationPageState();
}

class _BorrowerRegistrationPageState
    extends ConsumerState<BorrowerRegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _nationalIdController = TextEditingController();
  final _phoneController = TextEditingController();
  DateTime? _selectedDateOfBirth;

  @override
  void initState() {
    super.initState();
    final b = widget.borrower;
    if (b != null) {
      _firstNameController.text = b.firstName;
      _lastNameController.text = b.lastName;
      _nationalIdController.text = b.nationalId;
      _phoneController.text = b.phone;
      _selectedDateOfBirth = DateTime.tryParse(b.dateOfBirth);
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _nationalIdController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  bool _isValidAge(DateTime dob) {
    final today = DateTime.now();
    var age = today.year - dob.year;
    if (today.month < dob.month ||
        (today.month == dob.month && today.day < dob.day)) {
      age--;
    }
    return age >= 18;
  }

  Future<void> _submitForm({bool confirmRestore = false}) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedDateOfBirth == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a Date of Birth')),
      );
      return;
    }
    if (!_isValidAge(_selectedDateOfBirth!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Borrower must be at least 18 years old.'),
        ),
      );
      return;
    }

    final result = await ref
        .read(borrowerRegistrationNotifierProvider.notifier)
        .submit(
          existing: widget.borrower,
          firstName: _firstNameController.text,
          lastName: _lastNameController.text,
          nationalId: _nationalIdController.text,
          phone: _phoneController.text,
          dateOfBirth: formatDateOnly(_selectedDateOfBirth!),
          confirmRestore: confirmRestore,
        );

    if (!mounted) return;
    if (result.requiresRestoreConfirmation) {
      final restore = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Restore deleted borrower?'),
          content: const Text(
            'A deleted borrower has the same phone number and national ID. '
            'Restore the existing borrower and preserve their audit history?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Restore Borrower'),
            ),
          ],
        ),
      );
      if (restore == true && mounted) {
        await _submitForm(confirmRestore: true);
      }
      return;
    }
    if (result.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.borrower != null
                ? 'Could not update borrower: ${result.error}'
                : 'Registration rejected: ${result.error}',
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.borrower != null
                ? 'Borrower updated successfully'
                : result.savedOffline
                ? 'Saved locally — identity verification is pending. '
                      'Loans and invitations remain blocked until sync succeeds.'
                : 'Borrower registered successfully',
          ),
        ),
      );
      context.pop();
    }
  }

  Future<void> _selectDateOfBirth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDateOfBirth) {
      setState(() => _selectedDateOfBirth = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/borrowers');
            }
          },
        ),
        title: Text(
          widget.borrower != null ? 'Edit Borrower' : 'Register Borrower',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: BorrowerRegistrationForm(
          formKey: _formKey,
          firstNameCtrl: _firstNameController,
          lastNameCtrl: _lastNameController,
          nationalIdCtrl: _nationalIdController,
          phoneCtrl: _phoneController,
          dateOfBirth: _selectedDateOfBirth,
          onTapDateOfBirth: _selectDateOfBirth,
          onSubmit: _submitForm,
          borrower: widget.borrower,
        ),
      ),
    );
  }
}
