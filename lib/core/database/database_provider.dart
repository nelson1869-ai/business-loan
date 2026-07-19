import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'database_service.dart';

/// Supplies and disposes the shared local database service.
///
/// File: `lib/core/database/database_provider.dart`
///
/// Data Flow Diagram:
/// ```text
///  +--------------------------+     +------------------------+
///  | borrower_repository.dart | --> | database_provider.dart |
///  +--------------------------+     +-----------+------------+
///                                               |
///                                               v
///                                    database_service.dart
/// ```
final databaseServiceProvider = Provider<DatabaseService>((ref) {
  final service = DatabaseService();
  ref.onDispose(() {
    service.close();
  });
  return service;
});
