import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../dashboard/domain/dashboard_data.dart';

class CollectionFollowUp {
  const CollectionFollowUp({
    required this.id,
    required this.borrowerId,
    required this.loanId,
    required this.taskType,
    required this.priority,
    required this.status,
    required this.dueAt,
    this.description,
    this.installmentNumber,
    this.promisedAmount,
    this.promiseDate,
    this.promiseStatus,
  });

  final String id;
  final String borrowerId;
  final String loanId;
  final int? installmentNumber;
  final String taskType;
  final String priority;
  final String? description;
  final String status;
  final DateTime dueAt;
  final String? promisedAmount;
  final DateTime? promiseDate;
  final String? promiseStatus;

  factory CollectionFollowUp.fromJson(Map<String, dynamic> json) {
    return CollectionFollowUp(
      id: json['id'] as String,
      borrowerId: json['borrowerId'] as String,
      loanId: json['loanId'] as String,
      installmentNumber: (json['installmentNumber'] as num?)?.toInt(),
      taskType: json['taskType'] as String,
      priority: json['priority'] as String,
      description: json['description'] as String?,
      status: json['status'] as String,
      dueAt: DateTime.parse(json['dueAt'] as String),
      promisedAmount: json['promisedAmount']?.toString(),
      promiseDate: json['promiseDate'] == null
          ? null
          : DateTime.parse(json['promiseDate'] as String),
      promiseStatus: json['promiseStatus'] as String?,
    );
  }
}

final collectionFollowUpsProvider =
    FutureProvider.autoDispose<List<CollectionFollowUp>>((ref) async {
      final dio = ref.watch(apiClientProvider);
      final response = await dio.get<List<dynamic>>('/api/v1/collection-tasks');
      return (response.data ?? const [])
          .cast<Map<String, dynamic>>()
          .map(CollectionFollowUp.fromJson)
          .toList();
    });

final completedCollectionTasksProvider =
    FutureProvider.autoDispose<Set<String>>((ref) async {
      final dio = ref.watch(apiClientProvider);
      final response = await dio.get<List<dynamic>>(
        ApiEndpoints.completedCollectionTasks,
      );
      return (response.data ?? const []).map((value) => '$value').toSet();
    });

Future<void> completeCollectionTask(
  WidgetRef ref,
  String loanId,
  int installmentNumber,
) async {
  final dio = ref.read(apiClientProvider);
  await dio.post<void>(
    ApiEndpoints.completeCollectionTask(loanId, installmentNumber),
  );
  ref.invalidate(completedCollectionTasksProvider);
}

Future<void> createCollectionFollowUp(
  WidgetRef ref, {
  required DashboardDueItem item,
  required String taskType,
  required String priority,
  required DateTime dueAt,
  String? description,
  String? promisedAmount,
  DateTime? promiseDate,
}) async {
  await ref
      .read(apiClientProvider)
      .post<void>(
        '/api/v1/collection-tasks',
        data: {
          'borrowerId': item.borrowerId,
          'loanId': item.loanId,
          'installmentNumber': item.installmentNumber,
          'taskType': taskType,
          'priority': priority,
          'description': description?.trim(),
          'dueAt': dueAt.toUtc().toIso8601String(),
          if (taskType == 'PromiseToPay') 'promisedAmount': promisedAmount,
          if (taskType == 'PromiseToPay')
            'promiseDate': promiseDate?.toIso8601String().substring(0, 10),
        },
      );
  ref.invalidate(collectionFollowUpsProvider);
}

Future<void> completeScheduledFollowUp(WidgetRef ref, String taskId) async {
  await ref
      .read(apiClientProvider)
      .post<void>(
        '/api/v1/collection-tasks/$taskId/complete',
        data: const <String, dynamic>{},
      );
  ref.invalidate(collectionFollowUpsProvider);
  ref.invalidate(completedCollectionTasksProvider);
}
