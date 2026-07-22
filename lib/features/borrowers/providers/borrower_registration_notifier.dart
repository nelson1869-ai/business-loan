import 'package:uuid/uuid.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/borrower_model.dart';
import 'borrowers_state.dart';

class BorrowerRegistrationState {
  final bool isSubmitting;
  final String? error;
  final bool isEditMode;

  const BorrowerRegistrationState({
    this.isSubmitting = false,
    this.error,
    this.isEditMode = false,
  });
}

class BorrowerRegistrationNotifier
    extends StateNotifier<BorrowerRegistrationState> {
  BorrowerRegistrationNotifier({required this.ref})
    : super(const BorrowerRegistrationState());

  final Ref ref;

  Future<String?> submit({
    required Borrower? existing,
    required String firstName,
    required String lastName,
    required String nationalId,
    required String phone,
    required String dateOfBirth,
  }) async {
    final isEditMode = existing != null;
    state = BorrowerRegistrationState(
      isSubmitting: true,
      isEditMode: isEditMode,
    );

    final borrower = Borrower(
      id: existing?.id ?? const Uuid().v4(),
      firstName: firstName.trim(),
      lastName: lastName.trim(),
      nationalId: nationalId.trim(),
      phone: phone.trim(),
      dateOfBirth: dateOfBirth,
      status: existing?.status ?? 'Pending',
      createdAt:
          existing?.createdAt ?? DateTime.now().toUtc().toIso8601String(),
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

    final result = ref.read(borrowersNotifierProvider);
    if (result.hasError) {
      final msg = result.error?.toString() ?? 'Unknown error';
      state = BorrowerRegistrationState(isEditMode: isEditMode, error: msg);
      return msg;
    }

    state = BorrowerRegistrationState(isEditMode: isEditMode);
    return null;
  }
}

final borrowerRegistrationNotifierProvider =
    StateNotifierProvider.autoDispose<
      BorrowerRegistrationNotifier,
      BorrowerRegistrationState
    >((ref) {
      return BorrowerRegistrationNotifier(ref: ref);
    });
