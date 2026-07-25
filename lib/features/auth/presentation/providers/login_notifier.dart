import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lending_nelson/features/auth/data/auth_repository.dart';

class LoginState {
  final bool isLoading;
  final String? error;

  const LoginState({this.isLoading = false, this.error});
}

class LoginNotifier extends StateNotifier<LoginState> {
  LoginNotifier(this._authRepository) : super(const LoginState());

  final AuthRepository _authRepository;

  Future<String?> login(String username, String password) async {
    state = const LoginState(isLoading: true);
    try {
      await _authRepository.login(username, password);
      state = const LoginState();
      return null;
    } on AuthException catch (error) {
      final message = error.message;
      state = LoginState(error: message);
      return message;
    } catch (_) {
      const message = 'Unable to sign in. Please try again.';
      state = const LoginState(error: message);
      return message;
    }
  }
}

final loginNotifierProvider =
    StateNotifierProvider.autoDispose<LoginNotifier, LoginState>((ref) {
      return LoginNotifier(ref.watch(authRepositoryProvider));
    });
