import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:borrower_mobile/core/api/api_client.dart';
import 'package:borrower_mobile/features/profile/data/profile_local_cache.dart';
import 'package:borrower_mobile/features/profile/data/profile_repository.dart';
import 'package:borrower_mobile/features/profile/models/borrower_device.dart';
import 'package:borrower_mobile/features/profile/models/borrower_profile.dart';
import 'package:borrower_mobile/features/profile/profile_screen.dart';
import 'package:borrower_mobile/features/profile/providers/profile_provider.dart';

class FakeProfileApiClient implements ApiClient {
  final Map<String, dynamic> profileJson;
  final Map<String, dynamic> deviceJson;

  FakeProfileApiClient({
    required this.profileJson,
    required this.deviceJson,
  });

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #get) {
      return Future.value(profileJson);
    }
    if (invocation.memberName == #post) {
      return Future.value(deviceJson);
    }
    return super.noSuchMethod(invocation);
  }
}

class FakeProfileLocalCache implements ProfileLocalCache {
  final Map<String, dynamic> _store = {};

  @override
  Future<BorrowerProfile?> getCachedProfile(String borrowerAccountId) async {
    return _store['prof_$borrowerAccountId'] as BorrowerProfile?;
  }

  @override
  Future<void> saveCachedProfile(
    String borrowerAccountId,
    BorrowerProfile profile,
  ) async {
    _store['prof_$borrowerAccountId'] = profile;
  }

  @override
  Future<DeviceResponse?> getCachedDeviceRegistration(
      String borrowerAccountId) async {
    return _store['dev_$borrowerAccountId'] as DeviceResponse?;
  }

  @override
  Future<void> saveCachedDeviceRegistration(
    String borrowerAccountId,
    DeviceResponse device,
  ) async {
    _store['dev_$borrowerAccountId'] = device;
  }

  @override
  Future<void> clearAllCachedProfile() async {
    _store.clear();
  }
}

void main() {
  final sampleProfileJson = {
    'borrowerAccountId': 'acct-101',
    'borrowerId': 'bor-101',
    'firstName': 'Maria',
    'lastName': 'Santos',
    'phoneNumber': '+639501234567',
    'accountStatus': 'active',
    'createdAt': '2026-01-15T08:00:00.000',
  };

  final sampleDeviceJson = {
    'id': 'dev-101',
    'platform': 'android',
    'isActive': true,
    'lastSeenAt': '2026-08-02T10:00:00.000',
  };

  group('BorrowerProfile Models Unit Tests', () {
    test('BorrowerProfile.fromJson parses name and status', () {
      final profile = BorrowerProfile.fromJson(sampleProfileJson);

      expect(profile.borrowerAccountId, equals('acct-101'));
      expect(profile.fullName, equals('Maria Santos'));
      expect(profile.phoneNumber, equals('+639501234567'));
      expect(profile.accountStatus, equals('active'));
    });

    test('DeviceResponse.fromJson parses device details', () {
      final device = DeviceResponse.fromJson(sampleDeviceJson);

      expect(device.id, equals('dev-101'));
      expect(device.platform, equals('android'));
      expect(device.isActive, isTrue);
    });

    test('toJson cycle preserves data integrity', () {
      final profile = BorrowerProfile.fromJson(sampleProfileJson);
      final encoded = jsonEncode(profile.toJson());
      final decoded = jsonDecode(encoded) as Map<String, dynamic>;
      final restored = BorrowerProfile.fromJson(decoded);

      expect(restored.fullName, equals(profile.fullName));
      expect(restored.phoneNumber, equals(profile.phoneNumber));
    });
  });

  group('ProfileScreen Widget Tests', () {
    testWidgets('renders borrower profile and account info correctly',
        (tester) async {
      final api = FakeProfileApiClient(
        profileJson: sampleProfileJson,
        deviceJson: sampleDeviceJson,
      );
      final cache = FakeProfileLocalCache();
      final repo = ProfileRepository(apiClient: api, localCache: cache);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileNotifierProvider.overrideWith(
              (ref) => ProfileNotifier(
                repository: repo,
                borrowerAccountId: 'acct-101',
              ),
            ),
          ],
          child: const MaterialApp(
            home: ProfileScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('My Profile'), findsOneWidget);
      expect(find.text('Maria Santos'), findsOneWidget);
      expect(find.text('ACTIVE'), findsAtLeast(1));
      expect(find.text('+639501234567'), findsOneWidget);
      expect(find.text('bor-101'), findsOneWidget);
      final logoutButton = find.text('Log Out of Borrower Portal');
      await tester.scrollUntilVisible(
        logoutButton,
        100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(logoutButton, findsOneWidget);
    });
  });
}
