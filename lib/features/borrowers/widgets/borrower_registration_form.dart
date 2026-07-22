import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../loans/presentation/borrower_loans_section.dart';
import '../domain/borrower_model.dart';
import '../providers/borrower_registration_notifier.dart';
import 'borrower_form_fields.dart';

class BorrowerRegistrationForm extends ConsumerWidget {
  const BorrowerRegistrationForm({
    super.key,
    required this.formKey,
    required this.firstNameCtrl,
    required this.lastNameCtrl,
    required this.nationalIdCtrl,
    required this.phoneCtrl,
    required this.dateOfBirth,
    required this.onTapDateOfBirth,
    required this.onSubmit,
    required this.borrower,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController firstNameCtrl;
  final TextEditingController lastNameCtrl;
  final TextEditingController nationalIdCtrl;
  final TextEditingController phoneCtrl;
  final DateTime? dateOfBirth;
  final VoidCallback onTapDateOfBirth;
  final VoidCallback onSubmit;
  final Borrower? borrower;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSubmitting = ref
        .watch(borrowerRegistrationNotifierProvider)
        .isSubmitting;
    final isEditMode = borrower != null;

    return Form(
      key: formKey,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FormFieldRow(
              controller: firstNameCtrl,
              label: 'First Name *',
              icon: Icons.person_outline,
              validator: validateName,
              autofillHints: const [AutofillHints.givenName],
              textCapitalization: TextCapitalization.words,
            ),
            FormFieldRow(
              controller: lastNameCtrl,
              label: 'Last Name *',
              icon: Icons.person_outline,
              validator: validateName,
              autofillHints: const [AutofillHints.familyName],
              textCapitalization: TextCapitalization.words,
            ),
            FormFieldRow(
              controller: nationalIdCtrl,
              label: 'National ID *',
              icon: Icons.badge_outlined,
              keyboardType: TextInputType.number,
              validator: validateNationalId,
            ),
            FormFieldRow(
              controller: phoneCtrl,
              label: 'Phone Number *',
              icon: Icons.phone_outlined,
              hintText: '+254...',
              keyboardType: TextInputType.phone,
              validator: validatePhone,
              autofillHints: const [AutofillHints.telephoneNumber],
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: InkWell(
                onTap: onTapDateOfBirth,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date of Birth',
                    prefixIcon: Icon(Icons.calendar_today_outlined),
                  ),
                  child: Text(
                    dateOfBirth == null
                        ? 'Select Date of Birth'
                        : dateOfBirth!.toLocal().toString().split(' ')[0],
                    style: TextStyle(
                      fontSize: 16,
                      color: dateOfBirth == null
                          ? Colors.grey
                          : Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                ),
              ),
            ),
            if (borrower case final b?) ...[
              BorrowerLoansSection(borrower: b),
              const SizedBox(height: 24),
            ],
            ElevatedButton(
              onPressed: isSubmitting ? null : onSubmit,
              child: isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(isEditMode ? 'Save Changes' : 'Register Borrower'),
            ),
          ],
        ),
      ),
    );
  }
}
