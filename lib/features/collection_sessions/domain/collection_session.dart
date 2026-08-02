/// Backend-authoritative cash collection session.
class CollectionSession {
  const CollectionSession({
    required this.id,
    required this.collectorUserId,
    required this.openingCash,
    required this.expectedCash,
    required this.actualCash,
    required this.cashVariance,
    required this.varianceReason,
    required this.depositAmount,
    required this.depositReference,
    required this.status,
    required this.reviewerUserId,
    required this.createdAt,
  });

  final String id;
  final String collectorUserId;
  final String openingCash;
  final String expectedCash;
  final String actualCash;
  final String cashVariance;
  final String? varianceReason;
  final String depositAmount;
  final String? depositReference;
  final String status;
  final String? reviewerUserId;
  final DateTime createdAt;

  factory CollectionSession.fromJson(Map<String, dynamic> json) =>
      CollectionSession(
        id: json['id'] as String,
        collectorUserId: json['collectorUserId'] as String,
        openingCash: json['openingCash'].toString(),
        expectedCash: json['expectedCash'].toString(),
        actualCash: json['actualCash'].toString(),
        cashVariance: json['cashVariance'].toString(),
        varianceReason: json['varianceReason'] as String?,
        depositAmount: json['depositAmount'].toString(),
        depositReference: json['depositReference'] as String?,
        status: json['status'] as String,
        reviewerUserId: json['reviewerUserId'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      );
}
