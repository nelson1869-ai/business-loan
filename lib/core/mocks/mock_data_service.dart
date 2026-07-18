import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MockDataService {
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

  Future<List<dynamic>> loadBorrowers() async {
    try {
      final data = await rootBundle.loadString('assets/mocks/borrowers.json');
      return jsonDecode(data) as List<dynamic>;
    } catch (e) {
      return [];
    }
  }

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

final mockDataServiceProvider = Provider<MockDataService>((ref) {
  return MockDataService();
});
