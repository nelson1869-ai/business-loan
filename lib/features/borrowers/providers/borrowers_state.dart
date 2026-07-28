import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_endpoints.dart';
import '../../../core/network/offline_sync_service.dart';
import '../../../core/network/server_health_service.dart';

import '../data/borrower_repository.dart';
import '../data/remote_borrower_repository.dart';
import '../domain/borrower_model.dart';

class BorrowersNotifier extends AsyncNotifier<List<Borrower>> {
  @override
  Future<List<Borrower>> build() async {
    final localRepository = ref.watch(borrowerRepositoryProvider);
    final remoteRepository = ref.watch(remoteBorrowerRepositoryProvider);
    ref.watch(offlineSyncServiceProvider);

    // 1. Fetch local borrowers first for instant rendering
    final localBorrowers = await localRepository.getBorrowers()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // Network refresh must never delay delivery of the SQLite snapshot.
    unawaited(_refreshFromServer(localRepository, remoteRepository));
    return localBorrowers;
  }

  Future<void> _refreshFromServer(
    BorrowerRepository localRepository,
    RemoteBorrowerRepository remoteRepository,
  ) async {
    if (!await _isOnline()) return;
    try {
      final remote = await remoteRepository.getBorrowers();
      await localRepository.syncRemoteBorrowers(remote);
      remote.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      state = AsyncData(remote);
    } catch (_) {}
  }

  Future<void> registerBorrower(Borrower borrower) async {
    final currentList = state.asData?.value ?? const <Borrower>[];

    state = const AsyncLoading<List<Borrower>>().copyWithPrevious(state);

    state = await AsyncValue.guard(() async {
      await _runMutation(
        localAction: (repository) => repository.saveBorrower(borrower),
        endpoint: ApiEndpoints.borrowers,
        method: 'POST',
        payload: borrower.toJson(),
        entityType: 'borrower',
        entityLocalId: borrower.id,
        operationType: 'create',
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
        localAction: (repository) => repository.updateBorrower(borrower),
        endpoint: '${ApiEndpoints.borrowers}/${borrower.id}',
        method: 'PUT',
        payload: borrower.toJson(),
        entityType: 'borrower',
        entityLocalId: borrower.id,
        operationType: 'update',
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

    try {
      await _runMutation(
        localAction: (repository) => repository.deleteBorrower(id),
        endpoint: '${ApiEndpoints.borrowers}/$id',
        method: 'DELETE',
        payload: const <String, dynamic>{},
        entityType: 'borrower',
        entityLocalId: id,
        operationType: 'delete',
      );

      state = AsyncData(currentList.where((item) => item.id != id).toList());
    } catch (error, stackTrace) {
      state = AsyncData(currentList);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> _runMutation({
    required Future<void> Function(BorrowerRepository) localAction,
    required String endpoint,
    required String method,
    required Map<String, dynamic> payload,
    required String entityType,
    required String entityLocalId,
    required String operationType,
  }) async {
    final localRepository = ref.read(borrowerRepositoryProvider);
    final syncService = ref.read(offlineSyncServiceProvider);

    // SQLite and the durable queue are the write boundary. The sync engine,
    // never the foreground action, owns delivery to FastAPI.
    await localAction(localRepository);
    await syncService.enqueue(
      endpoint: endpoint,
      method: method,
      payload: payload,
      entityType: entityType,
      entityLocalId: entityLocalId,
      operationType: operationType,
    );
    unawaited(syncService.drainQueue());
  }

  Future<bool> _isOnline() async {
    return ref.read(serverHealthServiceProvider).isServerReachable();
  }
}

final borrowersNotifierProvider =
    AsyncNotifierProvider<BorrowersNotifier, List<Borrower>>(() {
      return BorrowersNotifier();
    });
