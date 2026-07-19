// Third-party packages
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Core network
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';

/// Handles remote authentication and secure JWT persistence.
class AuthRepository {
  /// Creates an authentication repository.
  AuthRepository(this._dio, this._secureStorage);

  final Dio _dio;
  final FlutterSecureStorage _secureStorage;

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
      throw Exception(_apiErrorMessage(error, 'Unable to sign in'));
    } on FormatException catch (error) {
      throw Exception(error.message);
    }
  }

  /// Removes all locally stored authentication tokens.
  Future<void> logout() async {
    await Future.wait([
      _secureStorage.delete(key: TokenStorageKeys.accessToken),
      _secureStorage.delete(key: TokenStorageKeys.refreshToken),
    ]);
  }

  String _apiErrorMessage(DioException error, String fallback) {
    final data = error.response?.data;
    if (data is Map<String, dynamic> && data['detail'] is String) {
      return data['detail'] as String;
    }
    return error.message ?? fallback;
  }
}

/// Repository used by authentication presentation providers.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(secureStorageProvider),
  );
});
