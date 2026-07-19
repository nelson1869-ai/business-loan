import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../domain/models/borrower.dart';
import 'providers/borrowers_provider.dart';

/// Validates borrower details and submits a new borrower for local storage.
///
/// File: `lib/features/dashboard/presentation/borrower_registration_screen.dart`
///
/// Data Flow Diagram:
/// ```text
///  +---------------------------+     +-----------------------------------+
///  | borrower_list_screen.dart | --> | borrower_registration_screen.dart |
///  +---------------------------+     +----------------+------------------+
///                                                     |
///                                                     v
///                                          borrowers_provider.dart
/// ```
class BorrowerRegistrationScreen extends ConsumerStatefulWidget {
  const BorrowerRegistrationScreen({super.key});

  @override
  ConsumerState<BorrowerRegistrationScreen> createState() =>
      _BorrowerRegistrationScreenState();
}

class _BorrowerRegistrationScreenState
    extends ConsumerState<BorrowerRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _nationalIdController = TextEditingController();
  final _phoneController = TextEditingController();

  DateTime? _selectedDateOfBirth;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _nationalIdController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // Age validation rule: Must be >= 18 years old
  bool _isValidAge(DateTime dob) {
    final today = DateTime.now();
    var age = today.year - dob.year;
    if (today.month < dob.month ||
        (today.month == dob.month && today.day < dob.day)) {
      age--;
    }
    return age >= 18;
  }

  bool _isSubmitting = false;

  Future<void> _submitForm() async {
    final formState = _formKey.currentState;
    if (formState != null && formState.validate()) {
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

      setState(() => _isSubmitting = true);

      final borrower = Borrower(
        id: const Uuid().v4(),
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        nationalId: _nationalIdController.text.trim(),
        phone: _phoneController.text.trim(),
        dateOfBirth: _selectedDateOfBirth!.toIso8601String(),
        status: 'Pending',
        createdAt: DateTime.now().toUtc().toIso8601String(),
      );

      await ref
          .read(borrowersNotifierProvider.notifier)
          .registerBorrower(borrower);

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      final result = ref.read(borrowersNotifierProvider);
      if (result.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not register borrower: ${result.error}'),
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Borrower registered successfully')),
      );
      context.pop();
    }
  }

  Future<void> _selectDateOfBirth(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDateOfBirth) {
      setState(() {
        _selectedDateOfBirth = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register Borrower')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _firstNameController,
                decoration: const InputDecoration(
                  labelText: 'First Name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (val) =>
                    val == null || val.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _lastNameController,
                decoration: const InputDecoration(
                  labelText: 'Last Name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (val) =>
                    val == null || val.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nationalIdController,
                decoration: const InputDecoration(
                  labelText: 'National ID',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                keyboardType: TextInputType.number,
                validator: (val) =>
                    val == null || val.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  hintText: '+254...',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                keyboardType: TextInputType.phone,
                validator: (val) =>
                    val == null || val.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              // Date of Birth selection styled like an InputDecoration box
              InkWell(
                onTap: () => _selectDateOfBirth(context),
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date of Birth',
                    prefixIcon: Icon(Icons.calendar_today_outlined),
                  ),
                  child: Text(
                    _selectedDateOfBirth == null
                        ? 'Select Date of Birth'
                        : _selectedDateOfBirth!.toLocal().toString().split(
                            ' ',
                          )[0],
                    style: TextStyle(
                      fontSize: 16,
                      color: _selectedDateOfBirth == null
                          ? Colors.grey
                          : Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submitForm,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Register'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
