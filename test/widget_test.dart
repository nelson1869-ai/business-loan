import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lending_nelson/app/app.dart';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lending_nelson/core/network/offline_sync_service.dart';
import 'package:lending_nelson/core/network/server_health_service.dart';
import 'package:lending_nelson/features/auth/data/auth_repository.dart';

class FakeAuthRepository extends AuthRepository {
  FakeAuthRepository() : super(Dio(), const FlutterSecureStorage());

  @override
  Future<bool> hasStoredSession() async => false;

  @override
  Future<void> login(String username, String password) async {}

  @override
  Future<void> logout() async {}
}

void main() {
  testWidgets('App starts and renders welcome screen', (
    WidgetTester tester,
  ) async {
    // Build our app under ProviderScope and trigger a frame.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          isOnlineProvider.overrideWith((ref) => Stream.value(false)),
          serverHealthServiceProvider.overrideWithValue(
            ServerHealthService(
              Connectivity(),
              isServerReachableOverride: () async => false,
            ),
          ),
        ],
        child: const LendingNelsonApp(),
      ),
    );

    // Verify that the splash screen elements are rendered
    expect(find.text('Lending Nelson'), findsOneWidget);
    expect(find.text('Secure Mobile Lending'), findsOneWidget);
    expect(find.byIcon(Icons.account_balance), findsOneWidget);

    // Wait for the redirect timer to run
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();

    // Verify that it transitioned to the login screen
    expect(find.text('Welcome Back'), findsOneWidget);
  });
}
