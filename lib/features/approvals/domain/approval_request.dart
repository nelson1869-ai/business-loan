/// One maker-checker request returned by the backend.
class ApprovalRequest {
  const ApprovalRequest({
    required this.id,
    required this.action,
    required this.entityType,
    required this.entityId,
    required this.makerUserId,
    required this.checkerUserId,
    required this.status,
    required this.requestReason,
    required this.decisionReason,
    required this.createdAt,
    required this.decidedAt,
  });

  final String id;
  final String action;
  final String entityType;
  final String entityId;
  final String makerUserId;
  final String? checkerUserId;
  final String status;
  final String requestReason;
  final String? decisionReason;
  final DateTime createdAt;
  final DateTime? decidedAt;

  factory ApprovalRequest.fromJson(Map<String, dynamic> json) =>
      ApprovalRequest(
        id: json['id'] as String,
        action: json['action'] as String,
        entityType: json['entityType'] as String,
        entityId: json['entityId'] as String,
        makerUserId: json['makerUserId'] as String,
        checkerUserId: json['checkerUserId'] as String?,
        status: json['status'] as String,
        requestReason: json['requestReason'] as String,
        decisionReason: json['decisionReason'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
        decidedAt: json['decidedAt'] == null
            ? null
            : DateTime.parse(json['decidedAt'] as String).toLocal(),
      );
}
