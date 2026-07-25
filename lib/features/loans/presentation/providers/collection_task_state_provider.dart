import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../dashboard/domain/dashboard_data.dart';
import '../../data/repositories/collection_task_repository.dart';
import '../../../../core/notifications/local_notification_service.dart';

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
      final items = await ref.watch(collectionTaskRepositoryProvider).list();
      return items.map(CollectionFollowUp.fromJson).toList();
    });

final completedCollectionTasksProvider =
    FutureProvider.autoDispose<Set<String>>((ref) async {
      return ref
          .watch(collectionTaskRepositoryProvider)
          .completedInstallments();
    });

Future<void> completeCollectionTask(
  WidgetRef ref,
  String loanId,
  int installmentNumber,
) async {
  await ref
      .read(collectionTaskRepositoryProvider)
      .completeInstallment(loanId, installmentNumber);
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
  await ref.read(collectionTaskRepositoryProvider).create({
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
  });
  final reminderAt = taskType == 'PromiseToPay' && promiseDate != null
      ? DateTime(promiseDate.year, promiseDate.month, promiseDate.day, 8)
      : dueAt;
  await ref
      .read(localNotificationServiceProvider)
      .schedule(
        id: _stableReminderId(
          '${item.loanId}:${item.installmentNumber}:$taskType',
        ),
        title: taskType == 'PromiseToPay'
            ? 'Promise-to-pay reminder'
            : 'Collection follow-up',
        body: 'An assigned lending task requires attention.',
        at: reminderAt,
        navigationPath: '/collections/today',
        category: taskType == 'PromiseToPay'
            ? ReminderCategory.promises
            : ReminderCategory.collections,
      );
  ref.invalidate(collectionFollowUpsProvider);
}

int _stableReminderId(String value) {
  return value.codeUnits.fold<int>(17, (hash, code) {
    return ((hash * 31) + code) & 0x7fffffff;
  });
}

Future<void> completeScheduledFollowUp(WidgetRef ref, String taskId) async {
  await ref.read(collectionTaskRepositoryProvider).completeScheduled(taskId);
  ref.invalidate(collectionFollowUpsProvider);
  ref.invalidate(completedCollectionTasksProvider);
}
