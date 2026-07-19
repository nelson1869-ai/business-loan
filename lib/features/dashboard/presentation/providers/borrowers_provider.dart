// ============================================================================
// Architectural Data Flow Diagram:
//
//      +-------------------------------------------------------+
//      |                  borrower_list_screen.dart             |
//      |      (Taps Edit/Delete -> dispatches state actions)   |
//      +---------------------------+---------------------------+
//                                  |
//                                  v
//      +---------------------------+---------------------------+
//      |                  borrowers_provider.dart              |
//      |                   (BorrowersNotifier)                 |
//      |      - updateBorrower(borrower)                       |
//      |      - deleteBorrower(id)                             |
//      +---------------------------+---------------------------+
//                                  |
//                                  v (calls repository mutations)
//      +---------------------------+---------------------------+
//      |                 borrower_repository.dart              |
//      +-------------------------------------------------------+
// ============================================================================

// Third-Party Packages
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Core Services (Shared across features)
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/offline_sync_service.dart';

// Feature Data Layer (Handles local and remote transactions)
import '../../data/repositories/borrower_repository.dart';
import '../../data/repositories/remote_borrower_repository.dart';

// Feature Domain Layer (Holds immutable data models)
import '../../domain/models/borrower.dart';

/// Notifier class that manages the list of borrowers asynchronously.
class BorrowersNotifier extends AsyncNotifier<List<Borrower>> {
  @override
  Future<List<Borrower>> build() async {
    final repository = ref.watch(borrowerRepositoryProvider);
    ref.watch(offlineSyncServiceProvider);

    final borrowers = await repository.getBorrowers()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return borrowers;
  }

  /// Registers a borrower remotely when online or queues the local write offline.
  Future<void> registerBorrower(Borrower borrower) async {
    final currentList = state.asData?.value ?? const <Borrower>[];

    // Preserve the current data while exposing the in-progress state to the UI.
    state = const AsyncLoading<List<Borrower>>().copyWithPrevious(state);

    state = await AsyncValue.guard(() async {
      await _runMutation(
        remoteAction: (repository) => repository.saveBorrower(borrower),
        localAction: (repository) => repository.saveBorrower(borrower),
        endpoint: ApiEndpoints.borrowers,
        method: 'POST',
        payload: borrower.toJson(),
      );

      final updatedList = [
        borrower,
        ...currentList.where((item) => item.id != borrower.id),
      ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return updatedList;
    });
  }

  /// Updates a borrower remotely when online or queues the local update offline.
  Future<void> updateBorrower(Borrower borrower) async {
    final currentList = state.asData?.value ?? const <Borrower>[];

    // Preserve the current data while exposing the in-progress state to the UI.
    state = const AsyncLoading<List<Borrower>>().copyWithPrevious(state);

    state = await AsyncValue.guard(() async {
      await _runMutation(
        remoteAction: (repository) async {
          try {
            await repository.updateBorrower(borrower);
          } on RemoteBorrowerException catch (error) {
            // Older app versions stored borrowers only in SQLite. When one of
            // those records is edited for the first time, migrate it to the
            // backend while preserving its existing ID and creation date.
            if (error.statusCode != 404) rethrow;
            await repository.saveBorrower(borrower);
          }
        },
        localAction: (repository) => repository.updateBorrower(borrower),
        endpoint: '${ApiEndpoints.borrowers}/${borrower.id}',
        method: 'PUT',
        payload: borrower.toJson(),
      );

      // Reconstruct the list by replacing the old borrower instance with the updated one
      final updatedList = currentList.map((item) {
        return item.id == borrower.id ? borrower : item;
      }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return updatedList;
    });
  }

  /// Deletes a borrower remotely when online or queues the local delete offline.
  Future<void> deleteBorrower(String id) async {
    final currentList = state.asData?.value ?? const <Borrower>[];

    // Preserve the current data while exposing the in-progress state to the UI.
    state = const AsyncLoading<List<Borrower>>().copyWithPrevious(state);

    state = await AsyncValue.guard(() async {
      await _runMutation(
        remoteAction: (repository) => repository.deleteBorrower(id),
        localAction: (repository) => repository.deleteBorrower(id),
        endpoint: '${ApiEndpoints.borrowers}/$id',
        method: 'DELETE',
        payload: const <String, dynamic>{},
        acceptNotFound: true,
      );

      // Remove the deleted borrower from the local memory state
      final updatedList = currentList.where((item) => item.id != id).toList();

      return updatedList;
    });
  }

  Future<void> _runMutation({
    required Future<void> Function(RemoteBorrowerRepository) remoteAction,
    required Future<void> Function(BorrowerRepository) localAction,
    required String endpoint,
    required String method,
    required Map<String, dynamic> payload,
    bool acceptNotFound = false,
  }) async {
    final localRepository = ref.read(borrowerRepositoryProvider);
    final remoteRepository = ref.read(remoteBorrowerRepositoryProvider);
    final syncService = ref.read(offlineSyncServiceProvider);

    if (!await _isOnline()) {
      await localAction(localRepository);
      await syncService.enqueue(
        endpoint: endpoint,
        method: method,
        payload: payload,
      );
      return;
    }

    try {
      await remoteAction(remoteRepository);
      await localAction(localRepository);
    } on RemoteBorrowerException catch (error) {
      if (acceptNotFound && error.statusCode == 404) {
        await localAction(localRepository);
        return;
      }
      if (!error.isRetryable) rethrow;
      await localAction(localRepository);
      await syncService.enqueue(
        endpoint: endpoint,
        method: method,
        payload: payload,
      );
    }
  }

  Future<bool> _isOnline() async {
    final results = await ref.read(connectivityProvider).checkConnectivity();
    return results.any((result) => result != ConnectivityResult.none);
  }
}

/// Provider exposing the [BorrowersNotifier] state.
final borrowersNotifierProvider =
    AsyncNotifierProvider<BorrowersNotifier, List<Borrower>>(() {
      return BorrowersNotifier();
    });
