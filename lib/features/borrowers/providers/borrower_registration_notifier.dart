import 'package:uuid/uuid.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/validation/phone_number.dart';
import '../../../core/network/server_health_service.dart';
import '../data/remote_borrower_repository.dart';
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

class BorrowerSubmissionResult {
  const BorrowerSubmissionResult({
    this.error,
    this.requiresRestoreConfirmation = false,
    this.savedOffline = false,
  });

  final String? error;
  final bool requiresRestoreConfirmation;
  final bool savedOffline;
}

class BorrowerRegistrationNotifier
    extends StateNotifier<BorrowerRegistrationState> {
  BorrowerRegistrationNotifier({required this.ref})
    : super(const BorrowerRegistrationState());

  final Ref ref;

  Future<BorrowerSubmissionResult> submit({
    required Borrower? existing,
    required String firstName,
    required String lastName,
    required String nationalId,
    required String phone,
    required String dateOfBirth,
    bool confirmRestore = false,
  }) async {
    final isEditMode = existing != null;
    state = BorrowerRegistrationState(
      isSubmitting: true,
      isEditMode: isEditMode,
    );

    final normalizedPhone = normalizePhilippineMobileNumber(phone);
    var savedOffline = !isEditMode;
    if (!isEditMode) {
      final online = await ref
          .read(serverHealthServiceProvider)
          .isServerReachable();
      if (online) {
        try {
          final decision = await ref
              .read(remoteBorrowerRepositoryProvider)
              .checkIdentity(
                firstName: firstName.trim(),
                lastName: lastName.trim(),
                nationalId: nationalId.trim(),
                phone: normalizedPhone,
                dateOfBirth: dateOfBirth,
              );
          if (decision.outcome == 'restore' && !confirmRestore) {
            state = const BorrowerRegistrationState();
            return BorrowerSubmissionResult(
              error: decision.message,
              requiresRestoreConfirmation: true,
            );
          }
          if (decision.outcome == 'conflict' ||
              decision.outcome == 'existing') {
            state = BorrowerRegistrationState(error: decision.message);
            return BorrowerSubmissionResult(error: decision.message);
          }
        } on RemoteBorrowerException catch (error) {
          if (!error.isRetryable) {
            state = BorrowerRegistrationState(error: error.message);
            return BorrowerSubmissionResult(error: error.message);
          }
          savedOffline = true;
        }
      } else {
        savedOffline = true;
      }
    }

    final borrower = Borrower(
      id: existing?.id ?? const Uuid().v4(),
      firstName: firstName.trim(),
      lastName: lastName.trim(),
      nationalId: nationalId.trim(),
      phone: normalizedPhone,
      dateOfBirth: dateOfBirth,
      status: existing?.status ?? 'Active',
      createdAt:
          existing?.createdAt ?? DateTime.now().toUtc().toIso8601String(),
      syncStatus: existing?.syncStatus ?? 'pending',
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
      return BorrowerSubmissionResult(error: msg);
    }

    state = BorrowerRegistrationState(isEditMode: isEditMode);
    return BorrowerSubmissionResult(savedOffline: savedOffline);
  }
}

final borrowerRegistrationNotifierProvider =
    StateNotifierProvider.autoDispose<
      BorrowerRegistrationNotifier,
      BorrowerRegistrationState
    >((ref) {
      return BorrowerRegistrationNotifier(ref: ref);
    });
