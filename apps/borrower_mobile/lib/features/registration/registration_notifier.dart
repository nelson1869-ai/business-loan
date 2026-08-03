import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:borrower_mobile/core/api/api_client.dart';
import 'package:borrower_mobile/core/api/api_error.dart';
import 'package:borrower_mobile/core/auth/auth_notifier.dart';
import 'package:borrower_mobile/core/storage/registration_status_storage.dart';

class RegistrationState {
  const RegistrationState(
      {this.status = 'idle', this.loading = false, this.message, this.error});
  final String status;
  final bool loading;
  final String? message;
  final String? error;
}

final registrationStatusStorageProvider =
    Provider<RegistrationStatusStorage>((ref) => RegistrationStatusStorage());

final registrationProvider =
    StateNotifierProvider<RegistrationNotifier, RegistrationState>((ref) =>
        RegistrationNotifier(ref.watch(apiClientProvider),
            ref.watch(registrationStatusStorageProvider)));

class RegistrationNotifier extends StateNotifier<RegistrationState> {
  RegistrationNotifier(this._api, this._storage)
      : super(const RegistrationState());
  final ApiClient _api;
  final RegistrationStatusStorage _storage;

  Future<bool> submit(Map<String, dynamic> form) async {
    if (state.loading) return false;
    state = const RegistrationState(loading: true);
    try {
      final response =
          await _api.post('/api/v1/client/auth/register', data: form);
      await _storage.save(response['registrationToken'] as String);
      state = RegistrationState(
          status: 'pending', message: response['message'] as String?);
      return true;
    } on ApiError catch (error) {
      state = RegistrationState(error: error.message);
      return false;
    } catch (_) {
      state = const RegistrationState(
          error:
              'Unable to submit registration. Check your connection and try again.');
      return false;
    }
  }

  Future<void> refresh() async {
    if (state.loading) return;
    final token = await _storage.read();
    if (token == null) return;
    state = RegistrationState(
        status: state.status, loading: true, message: state.message);
    try {
      final response = await _api.post(
          '/api/v1/client/auth/registration-status',
          data: {'registrationToken': token});
      state = RegistrationState(
          status: response['status'] as String? ?? 'unknown',
          message: response['message'] as String?);
    } on ApiError catch (error) {
      state = RegistrationState(status: state.status, error: error.message);
    } catch (_) {
      state = RegistrationState(
          status: state.status, error: 'Status is unavailable while offline.');
    }
  }
}
