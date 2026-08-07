import 'dart:convert';

class BorrowerNotificationItem {
  final String id;
  final String borrowerId;
  final String title;
  final String message;
  final String notificationType;
  final String? metadataJson;
  final bool isRead;
  final DateTime createdAt;

  const BorrowerNotificationItem({
    required this.id,
    required this.borrowerId,
    required this.title,
    required this.message,
    required this.notificationType,
    this.metadataJson,
    required this.isRead,
    required this.createdAt,
  });

  Map<String, dynamic> get metadata {
    if (metadataJson == null || metadataJson!.isEmpty) {
      return {};
    }
    try {
      final decoded = json.decode(metadataJson!);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {}
    return {};
  }

  String? get entityType => metadata['entityType'] as String?;
  String? get entityId => metadata['entityId'] as String?;
  String? get receiptId =>
      (metadata['receiptId'] ?? metadata['receipt_id']) as String?;
  String? get paymentId =>
      (metadata['paymentId'] ?? metadata['payment_id']) as String?;
  String? get loanId => (metadata['loanId'] ?? metadata['loan_id']) as String?;
  String? get requestId =>
      (metadata['requestId'] ?? metadata['request_id']) as String?;

  factory BorrowerNotificationItem.fromJson(Map<String, dynamic> jsonMap) {
    return BorrowerNotificationItem(
      id: jsonMap['id'] as String? ?? '',
      borrowerId: jsonMap['borrowerId'] as String? ?? jsonMap['borrower_id'] as String? ?? '',
      title: jsonMap['title'] as String? ?? '',
      message: jsonMap['message'] as String? ?? '',
      notificationType:
          jsonMap['notificationType'] as String? ?? jsonMap['notification_type'] as String? ?? 'general',
      metadataJson: jsonMap['metadataJson'] as String? ?? jsonMap['metadata_json'] as String?,
      isRead: jsonMap['isRead'] as bool? ?? jsonMap['is_read'] as bool? ?? false,
      createdAt: jsonMap['createdAt'] != null
          ? DateTime.parse(jsonMap['createdAt'] as String)
          : jsonMap['created_at'] != null
              ? DateTime.parse(jsonMap['created_at'] as String)
              : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'borrowerId': borrowerId,
      'title': title,
      'message': message,
      'notificationType': notificationType,
      'metadataJson': metadataJson,
      'isRead': isRead,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  BorrowerNotificationItem copyWith({
    String? id,
    String? borrowerId,
    String? title,
    String? message,
    String? notificationType,
    String? metadataJson,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return BorrowerNotificationItem(
      id: id ?? this.id,
      borrowerId: borrowerId ?? this.borrowerId,
      title: title ?? this.title,
      message: message ?? this.message,
      notificationType: notificationType ?? this.notificationType,
      metadataJson: metadataJson ?? this.metadataJson,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
