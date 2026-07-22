import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_endpoints.dart';
import '../../../core/network/offline_sync_service.dart';

import '../data/borrower_repository.dart';
import '../data/remote_borrower_repository.dart';
import '../domain/borrower_model.dart';

class BorrowersNotifier extends AsyncNotifier<List<Borrower>> {
  @override
  Future<List<Borrower>> build() async {
    final localRepository = ref.watch(borrowerRepositoryProvider);
    final remoteRepository = ref.watch(remoteBorrowerRepositoryProvider);
    ref.watch(offlineSyncServiceProvider);

    if (await _isOnline()) {
      try {
        final remote = await remoteRepository.getBorrowers();
        for (final borrower in remote) {
          await localRepository.saveBorrower(borrower);
        }
        return remote..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      } catch (_) {}
    }

    final borrowers = await localRepository.getBorrowers()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return borrowers;
  }

  Future<void> registerBorrower(Borrower borrower) async {
    final currentList = state.asData?.value ?? const <Borrower>[];

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

  Future<void> updateBorrower(Borrower borrower) async {
    final currentList = state.asData?.value ?? const <Borrower>[];

    state = const AsyncLoading<List<Borrower>>().copyWithPrevious(state);

    state = await AsyncValue.guard(() async {
      await _runMutation(
        remoteAction: (repository) async {
          try {
            await repository.updateBorrower(borrower);
          } on RemoteBorrowerException catch (error) {
            if (error.statusCode != 404) rethrow;
            await repository.saveBorrower(borrower);
          }
        },
        localAction: (repository) => repository.updateBorrower(borrower),
        endpoint: '${ApiEndpoints.borrowers}/${borrower.id}',
        method: 'PUT',
        payload: borrower.toJson(),
      );

      final updatedList = currentList.map((item) {
        return item.id == borrower.id ? borrower : item;
      }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return updatedList;
    });
  }

  Future<void> deleteBorrower(String id) async {
    final currentList = state.asData?.value ?? const <Borrower>[];

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

final borrowersNotifierProvider =
    AsyncNotifierProvider<BorrowersNotifier, List<Borrower>>(() {
      return BorrowersNotifier();
    });
