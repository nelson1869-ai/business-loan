import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

// Feature Domain Layer
import '../domain/models/borrower.dart';
import '../../loans/presentation/borrower_loans_section.dart';

// Presentation Layer Providers
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
  /// Optional pre-existing borrower.
  ///
  /// - `null`     → Add Mode  (blank form)
  /// - `non-null` → Edit Mode (form pre-filled with [borrower] data)
  final Borrower? borrower;

  const BorrowerRegistrationScreen({super.key, this.borrower});

  @override
  ConsumerState<BorrowerRegistrationScreen> createState() =>
      _BorrowerRegistrationScreenState();
}

class _BorrowerRegistrationScreenState
    extends ConsumerState<BorrowerRegistrationScreen> {
  // ==================== State & Controllers ====================
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _nationalIdController = TextEditingController();
  final _phoneController = TextEditingController();

  DateTime? _selectedDateOfBirth;

  // ==================== Lifecycle Methods ====================
  @override
  void initState() {
    super.initState();
    // Pre-fill form fields when editing an existing borrower
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

  // ==================== Business Logic & Helpers ====================
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

  /// Fills out the form fields with random, realistic borrower data for development testing.
  void _autoFillRandomData() {
    final firstNames = [
      'James',
      'Mary',
      'John',
      'Patricia',
      'Robert',
      'Jennifer',
      'Michael',
      'Linda',
      'William',
      'Elizabeth',
      'David',
      'Barbara',
    ];
    final lastNames = [
      'Smith',
      'Johnson',
      'Williams',
      'Brown',
      'Jones',
      'Miller',
      'Davis',
      'Garcia',
      'Rodriguez',
      'Wilson',
      'Martinez',
      'Anderson',
    ];

    final random = Random();
    final firstName = firstNames[random.nextInt(firstNames.length)];
    final lastName = lastNames[random.nextInt(lastNames.length)];

    // Generate a random 8-digit national ID
    final nationalId = (10000000 + random.nextInt(90000000)).toString();

    // Generate a random Kenyan phone number format (+2547xx xxx xxx)
    final phone = '+2547${(10000000 + random.nextInt(90000000)).toString()}';

    // Generate a random date of birth corresponding to a valid age (between 18 and 65 years old)
    final ageInDays = (18 * 365) + random.nextInt((65 - 18) * 365);
    final dob = DateTime.now().subtract(Duration(days: ageInDays));

    setState(() {
      _firstNameController.text = firstName;
      _lastNameController.text = lastName;
      _nationalIdController.text = nationalId;
      _phoneController.text = phone;
      _selectedDateOfBirth = dob;
    });
  }

  bool _isSubmitting = false;

  String? _validateName(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Required';
    if (text.length > 100) return 'Must be 100 characters or fewer';
    return null;
  }

  String? _validateNationalId(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Required';
    if (text.length < 4) return 'Must contain at least 4 characters';
    if (text.length > 100) return 'Must be 100 characters or fewer';
    return null;
  }

  String? _validatePhone(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Required';
    if (text.length < 7) return 'Must contain at least 7 characters';
    if (text.length > 32) return 'Must be 32 characters or fewer';
    return null;
  }

  String _formatDateOnly(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

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

      final isEditMode = widget.borrower != null;

      // In Edit Mode: preserve the original id and createdAt so the existing
      // SQLite row is updated rather than inserting a duplicate.
      // In Add Mode: generate a fresh UUID and set createdAt to now.
      final borrower = Borrower(
        id: isEditMode ? widget.borrower!.id : const Uuid().v4(),
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        nationalId: _nationalIdController.text.trim(),
        phone: _phoneController.text.trim(),
        dateOfBirth: _formatDateOnly(_selectedDateOfBirth!),
        status: widget.borrower?.status ?? 'Pending',
        createdAt: isEditMode
            ? widget.borrower!.createdAt
            : DateTime.now().toUtc().toIso8601String(),
      );

      if (isEditMode) {
        await ref
            .read(borrowersNotifierProvider.notifier)
            .updateBorrower(borrower);
      } else {
        await ref
            .read(borrowersNotifierProvider.notifier)
            .registerBorrower(borrower);
      }

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      final result = ref.read(borrowersNotifierProvider);
      if (result.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEditMode
                  ? 'Could not update borrower: ${result.error}'
                  : 'Could not register borrower: ${result.error}',
            ),
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEditMode
                ? 'Borrower updated successfully'
                : 'Borrower registered successfully',
          ),
        ),
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

  // ==================== UI Construction ====================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Show 'Edit Borrower' when in Edit Mode, otherwise 'Register Borrower'
        title: Text(
          widget.borrower != null ? 'Edit Borrower' : 'Register Borrower',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.casino_outlined),
            onPressed: _autoFillRandomData,
            tooltip: 'Auto Fill (Dev)',
          ),
        ],
      ),
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
                validator: _validateName,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _lastNameController,
                decoration: const InputDecoration(
                  labelText: 'Last Name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: _validateName,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nationalIdController,
                decoration: const InputDecoration(
                  labelText: 'National ID',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                keyboardType: TextInputType.number,
                validator: _validateNationalId,
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
                validator: _validatePhone,
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
              if (widget.borrower case final borrower?) ...[
                BorrowerLoansSection(borrower: borrower),
                const SizedBox(height: 24),
              ],
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submitForm,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        widget.borrower == null
                            ? 'Register Borrower'
                            : 'Save Changes',
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
