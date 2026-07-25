// Third-party packages
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Core network
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_error_mapper.dart';

/// A user-safe authentication failure.
class AuthException implements Exception {
  const AuthException(this.message);

  final String message;
}

/// Handles remote authentication and secure JWT persistence.
class AuthRepository {
  /// Creates an authentication repository.
  AuthRepository(this._dio, this._secureStorage);

  final Dio _dio;
  final FlutterSecureStorage _secureStorage;

  /// Returns whether this device has a refresh token for session restoration.
  Future<bool> hasStoredSession() async {
    try {
      final refreshToken = await _secureStorage.read(
        key: TokenStorageKeys.refreshToken,
      );
      return refreshToken != null && refreshToken.isNotEmpty;
    } on Exception {
      return false;
    }
  }

  /// Authenticates a user and stores the returned token pair securely.
  Future<void> login(String username, String password) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.token,
        data: {'username': username, 'password': password},
      );
      final accessToken = response.data?['access_token'] as String?;
      final refreshToken = response.data?['refresh_token'] as String?;
      if (accessToken == null || refreshToken == null) {
        throw const FormatException('Authentication response omitted tokens');
      }
      await Future.wait([
        _secureStorage.write(
          key: TokenStorageKeys.accessToken,
          value: accessToken,
        ),
        _secureStorage.write(
          key: TokenStorageKeys.refreshToken,
          value: refreshToken,
        ),
      ]);
    } on DioException catch (error) {
      throw AuthException(ApiErrorMapper.message(error));
    } on FormatException {
      throw const AuthException(
        'The server returned an invalid sign-in response.',
      );
    }
  }

  /// Removes all locally stored authentication tokens.
  Future<void> logout() async {
    await Future.wait([
      _secureStorage.delete(key: TokenStorageKeys.accessToken),
      _secureStorage.delete(key: TokenStorageKeys.refreshToken),
    ]);
  }
}

/// Repository used by authentication presentation providers.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(secureStorageProvider),
  );
});
