import 'package:flutter_riverpod/flutter_riverpod.dart';

// Core Services (Shared across features)
import '../../../../core/mocks/mock_data_service.dart';

// Feature Data Layer (Handles SQLite database transactions)
import '../../data/repositories/borrower_repository.dart';

// Feature Domain Layer (Holds immutable data models)
import '../../domain/models/borrower.dart';

/// Notifier class that manages the list of borrowers asynchronously.
///
/// File: `lib/features/dashboard/presentation/providers/borrowers_provider.dart`
///
/// Data Flow Diagram:
/// ```text
///  +-------------------------------+     +-----------------------------------+
///  |     mock_data_service.dart    |     |      borrower_repository.dart     |
///  |     (Mock JSON Borrowers)     |     |      (Local SQLite Database)      |
///  +---------------+---------------+     +-----------------+-----------------+
///                  |                                       |
///                  | (1) Load Mock                         | (2) Load SQLite
///                  +---------------+       +---------------+
///                                  |       |
///                                  v       v
///                      +-----------+-------+------------+
///                      |        borrowers_provider.dart |
///                      |           (BorrowersNotifier)  |
///                      +-------------------+------------+
///                                          |
///                                          | (3) Exposes State
///                                          v
///                      +-----------+-------+------------+
///                      |      borrowersNotifierProvider |
///                      +-------------------+------------+
///                                          |
///                                          | (4) Listens & Redraws
///                                          v
///                      +-----------+-------+------------+
///                      |    borrower_list_screen.dart   |
///                      |       (BorrowerListScreen)     |
///                      +--------------------------------+
/// ```
class BorrowersNotifier extends AsyncNotifier<List<Borrower>> {
  @override
  Future<List<Borrower>> build() async {
    final repository = ref.watch(borrowerRepositoryProvider);
    final mockService = ref.watch(mockDataServiceProvider);

    // 1. Load mock borrowers from the local JSON asset file
    final mockData = await mockService.loadBorrowers();
    final mockList = mockData
        .map((e) => Borrower.fromJson(e as Map<String, dynamic>))
        .toList();

    // 2. Load locally registered borrowers from the SQLite database
    final dbList = await repository.getBorrowers();

    // 3. Merge both lists, letting local SQLite entries take precedence by ID
    final allBorrowers = <String, Borrower>{};
    for (final borrower in mockList) {
      allBorrowers[borrower.id] = borrower;
    }
    for (final borrower in dbList) {
      allBorrowers[borrower.id] = borrower;
    }

    // 4. Return sorted list showing newest registered borrowers first
    final mergedList = allBorrowers.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return mergedList;
  }

  /// Registers a new borrower, saving them to SQLite, and updates the local state.
  Future<void> registerBorrower(Borrower borrower) async {
    final currentList = state.asData?.value ?? const <Borrower>[];

    // Preserve the current data while exposing the in-progress state to the UI.
    state = const AsyncLoading<List<Borrower>>().copyWithPrevious(state);

    state = await AsyncValue.guard(() async {
      final repository = ref.read(borrowerRepositoryProvider);
      await repository.saveBorrower(borrower);

      final updatedList = [
        borrower,
        ...currentList.where((item) => item.id != borrower.id),
      ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return updatedList;
    });
  }
}

/// Provider exposing the [BorrowersNotifier] state.
final borrowersNotifierProvider =
    AsyncNotifierProvider<BorrowersNotifier, List<Borrower>>(() {
      return BorrowersNotifier();
    });
