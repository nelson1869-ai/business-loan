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
    } catch (error) {
      final message = error.toString().replaceFirst('Exception: ', '');
      state = LoginState(error: message);
      return message;
    }
  }
}

final loginNotifierProvider =
    StateNotifierProvider.autoDispose<LoginNotifier, LoginState>((ref) {
      return LoginNotifier(ref.watch(authRepositoryProvider));
    });
