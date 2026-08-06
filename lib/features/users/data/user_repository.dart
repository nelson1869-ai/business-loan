import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../domain/app_user.dart';

class UserRepository {
  const UserRepository(this._dio);

  final Dio _dio;

  Future<List<AppUser>> load() async {
    final response = await _dio.get<List<dynamic>>(ApiEndpoints.users);
    return (response.data ?? const <dynamic>[])
        .map((item) => AppUser.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList(growable: false);
  }

  Future<void> create({
    required String username,
    required String password,
    required String role,
  }) async {
    await _dio.post<void>(
      ApiEndpoints.users,
      data: {'username': username, 'password': password, 'role': role},
    );
  }

  Future<void> updateRole(String userId, String role) async {
    await _dio.patch<void>(ApiEndpoints.userRole(userId), data: {'role': role});
  }

  Future<void> delete(String userId) async {
    await _dio.delete<void>('${ApiEndpoints.users}/$userId');
  }
}

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(ref.watch(apiClientProvider));
});
