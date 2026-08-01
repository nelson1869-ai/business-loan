import 'package:equatable/equatable.dart';

enum AuthStatus { unknown, unauthenticated, authenticating, authenticated }

class AuthState extends Equatable {
  final AuthStatus status;
  final String? borrowerAccountId;
  final String? borrowerId;
  final String? errorMessage;
  final String? pendingPhoneNumber;
  final int resendCooldownSeconds;

  const AuthState({
    required this.status,
    this.borrowerAccountId,
    this.borrowerId,
    this.errorMessage,
    this.pendingPhoneNumber,
    this.resendCooldownSeconds = 0,
  });

  factory AuthState.unknown() => const AuthState(status: AuthStatus.unknown);
  factory AuthState.unauthenticated([String? error]) =>
      AuthState(status: AuthStatus.unauthenticated, errorMessage: error);
  factory AuthState.authenticating() =>
      const AuthState(status: AuthStatus.authenticating);
  factory AuthState.authenticated({
    required String borrowerAccountId,
    required String borrowerId,
  }) =>
      AuthState(
        status: AuthStatus.authenticated,
        borrowerAccountId: borrowerAccountId,
        borrowerId: borrowerId,
      );

  AuthState copyWith({
    AuthStatus? status,
    String? borrowerAccountId,
    String? borrowerId,
    String? errorMessage,
    String? pendingPhoneNumber,
    int? resendCooldownSeconds,
  }) {
    return AuthState(
      status: status ?? this.status,
      borrowerAccountId: borrowerAccountId ?? this.borrowerAccountId,
      borrowerId: borrowerId ?? this.borrowerId,
      errorMessage: errorMessage,
      pendingPhoneNumber: pendingPhoneNumber ?? this.pendingPhoneNumber,
      resendCooldownSeconds:
          resendCooldownSeconds ?? this.resendCooldownSeconds,
    );
  }

  @override
  List<Object?> get props => [
        status,
        borrowerAccountId,
        borrowerId,
        errorMessage,
        pendingPhoneNumber,
        resendCooldownSeconds,
      ];
}
