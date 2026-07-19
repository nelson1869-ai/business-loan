import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A service that loads mock data from local JSON asset files.
///
/// Used for offline development and testing.
///
/// File: `lib/core/mocks/mock_data_service.dart`
///
/// Data Flow Diagram:
/// ```text
///  +---------------------+     +------------------------+
///  | assets/mocks/*.json | --> | mock_data_service.dart |
///  +---------------------+     +-----------+------------+
///                                            |
///                                            v
///                                 borrowers_provider.dart
/// ```
class MockDataService {
  /// Loads mock loan products from `assets/mocks/loan_products.json`.
  ///
  /// Returns a [List] of raw dynamic loan product data, or an empty list if loading fails.
  Future<List<dynamic>> loadLoanProducts() async {
    try {
      final data = await rootBundle.loadString(
        'assets/mocks/loan_products.json',
      );
      return jsonDecode(data) as List<dynamic>;
    } catch (e) {
      return [];
    }
  }

  /// Loads mock borrowers from `assets/mocks/borrowers.json`.
  ///
  /// Returns a [List] of raw dynamic borrower data, or an empty list if loading fails.
  Future<List<dynamic>> loadBorrowers() async {
    try {
      final data = await rootBundle.loadString('assets/mocks/borrowers.json');
      return jsonDecode(data) as List<dynamic>;
    } catch (e) {
      return [];
    }
  }

  /// Loads the mock user profile from `assets/mocks/user_profile.json`.
  ///
  /// Returns a [Map] of dynamic user profile properties, or `null` if loading fails.
  Future<Map<String, dynamic>?> loadUserProfile() async {
    try {
      final data = await rootBundle.loadString(
        'assets/mocks/user_profile.json',
      );
      return jsonDecode(data) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }
}

/// Provider exposing a singleton instance of [MockDataService].
final mockDataServiceProvider = Provider<MockDataService>((ref) {
  return MockDataService();
});
