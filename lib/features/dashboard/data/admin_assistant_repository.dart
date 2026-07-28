import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/security/encryption_service.dart';
import 'local_admin_assistant_service.dart';

class AdminAssistantRecord {
  const AdminAssistantRecord({
    required this.borrowerId,
    required this.borrowerName,
    required this.loanId,
    required this.amountDue,
    required this.dueDate,
    required this.status,
    this.recordType = 'installment',
    this.amountPaid,
    this.effectiveDate,
  });

  final String borrowerId;
  final String borrowerName;
  final String loanId;
  final String amountDue;
  final String? dueDate;
  final String status;
  final String recordType;
  final String? amountPaid;
  final String? effectiveDate;

  factory AdminAssistantRecord.fromJson(Map<String, dynamic> json) =>
      AdminAssistantRecord(
        borrowerId: json['borrowerId']?.toString() ?? '',
        borrowerName: json['borrowerName']?.toString() ?? 'Borrower',
        loanId: json['loanId']?.toString() ?? '',
        amountDue: json['amountDue']?.toString() ?? '0.00',
        dueDate: json['dueDate']?.toString(),
        status: json['status']?.toString() ?? '',
        recordType: json['recordType']?.toString() ?? 'installment',
        amountPaid: json['amountPaid']?.toString(),
        effectiveDate: json['effectiveDate']?.toString(),
      );
}

class BorrowerClarificationOption {
  const BorrowerClarificationOption({
    required this.borrowerId,
    required this.displayName,
    required this.maskedReference,
  });

  final String borrowerId;
  final String displayName;
  final String maskedReference;

  factory BorrowerClarificationOption.fromJson(Map<String, dynamic> json) =>
      BorrowerClarificationOption(
        borrowerId: json['borrowerId']?.toString() ?? '',
        displayName: json['displayName']?.toString() ?? 'Borrower',
        maskedReference: json['maskedReference']?.toString() ?? '',
      );
}

class AdminAssistantReply {
  const AdminAssistantReply({
    required this.answer,
    required this.records,
    required this.asOf,
    required this.source,
    required this.disclaimer,
    this.answerSource = 'local',
    this.aiUsed = false,
    this.aiStatus = 'skipped',
    this.lastSyncedAt,
    this.clarification = const [],
    this.totalMatchingCount = 0,
    this.hasMore = false,
    this.currency = 'PHP',
    this.matchedRoute = '',
    this.intentConfidence = 0,
    this.metrics = const {},
    this.intent = '',
    this.nextOffset,
  });

  final String answer;
  final List<AdminAssistantRecord> records;
  final String asOf;
  final String source;
  final String disclaimer;
  final String answerSource;
  final bool aiUsed;
  final String aiStatus;
  final DateTime? lastSyncedAt;
  final List<BorrowerClarificationOption> clarification;
  final int totalMatchingCount;
  final bool hasMore;
  final String currency;
  final String matchedRoute;
  final int intentConfidence;
  final Map<String, String> metrics;
  final String intent;
  final int? nextOffset;

  AdminAssistantReply mergePage(AdminAssistantReply page) {
    return AdminAssistantReply(
      answer: answer,
      records: [...records, ...page.records],
      asOf: page.asOf,
      source: page.source,
      disclaimer: page.disclaimer,
      answerSource: page.answerSource,
      aiUsed: page.aiUsed,
      aiStatus: page.aiStatus,
      lastSyncedAt: page.lastSyncedAt ?? lastSyncedAt,
      clarification: clarification,
      totalMatchingCount: page.totalMatchingCount,
      hasMore: page.hasMore,
      currency: page.currency,
      matchedRoute: page.matchedRoute,
      intentConfidence: page.intentConfidence,
      metrics: page.metrics,
      intent: page.intent,
      nextOffset: page.nextOffset,
    );
  }

  factory AdminAssistantReply.fromJson(Map<String, dynamic> json) {
    final answer = json['answer']?.toString().trim() ?? '';
    if (answer.isEmpty) {
      throw const FormatException('Assistant response was empty');
    }
    final rawRecords = json['records'];
    return AdminAssistantReply(
      answer: answer,
      records: rawRecords is List<dynamic>
          ? rawRecords
                .whereType<Map<dynamic, dynamic>>()
                .map(
                  (item) => AdminAssistantRecord.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList(growable: false)
          : const [],
      asOf: json['asOf']?.toString() ?? '',
      source: json['source']?.toString() ?? 'Verified database records',
      disclaimer:
          json['disclaimer']?.toString() ??
          'Read-only assistant. Verify operational actions.',
      answerSource: json['answerSource']?.toString() ?? 'local',
      aiUsed: json['aiUsed'] == true,
      aiStatus: json['aiStatus']?.toString() ?? 'skipped',
      totalMatchingCount: json['totalMatchingCount'] as int? ?? 0,
      hasMore: json['hasMore'] == true,
      currency: json['currency']?.toString() ?? 'PHP',
      matchedRoute: json['matchedRoute']?.toString() ?? '',
      intentConfidence: (json['intentConfidence'] as num?)?.round() ?? 0,
      metrics: switch (json['metrics']) {
        final Map<dynamic, dynamic> values => values.map(
          (key, value) => MapEntry(key.toString(), value.toString()),
        ),
        _ => const {},
      },
      intent: json['intent']?.toString() ?? '',
      nextOffset: (json['nextOffset'] as num?)?.toInt(),
      clarification: switch (json['clarification']) {
        {'options': final List<dynamic> options} =>
          options
              .whereType<Map<dynamic, dynamic>>()
              .map(
                (item) => BorrowerClarificationOption.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(growable: false),
        _ => const [],
      },
    );
  }
}

class AdminAssistantRepository {
  const AdminAssistantRepository(this._dio, this._local);

  final Dio _dio;
  final LocalAdminAssistantService _local;

  Future<AdminAssistantReply> ask(
    String message, {
    String? selectedBorrowerId,
    int offset = 0,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.adminAssistantQuestions,
        data: <String, dynamic>{
          'message': message,
          // ignore: use_null_aware_elements
          if (selectedBorrowerId != null)
            'selectedBorrowerId': selectedBorrowerId,
          if (offset > 0) 'offset': offset,
        },
        options: Options(receiveTimeout: const Duration(seconds: 30)),
      );
      final data = response.data;
      if (data == null) throw const FormatException('Empty assistant response');
      return AdminAssistantReply.fromJson(data);
    } on DioException catch (error) {
      final statusCode = error.response?.statusCode;
      if (statusCode != null && statusCode < 500) rethrow;
      debugPrint(
        'admin_assistant_offline_fallback '
        'transport=${error.type.name}',
      );
      return _local.answer(
        message,
        selectedBorrowerId: selectedBorrowerId,
        offset: offset,
      );
    }
  }
}

final adminAssistantRepositoryProvider = Provider<AdminAssistantRepository>((
  ref,
) {
  return AdminAssistantRepository(
    ref.watch(apiClientProvider),
    LocalAdminAssistantService(
      ref.watch(databaseServiceProvider),
      ref.watch(encryptionServiceProvider),
    ),
  );
});
