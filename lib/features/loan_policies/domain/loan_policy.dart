/// Immutable versioned loan-product policy returned by the backend.
class LoanPolicy {
  const LoanPolicy({
    required this.id,
    required this.name,
    required this.version,
    required this.status,
    required this.currency,
    required this.minimumRate,
    required this.maximumRate,
    required this.interestMethod,
    required this.ratePeriod,
    required this.effectiveDate,
    required this.changeReason,
    required this.createdByUserId,
    required this.approvedByUserId,
    required this.createdAt,
  });

  final String id;
  final String name;
  final int version;
  final String status;
  final String currency;
  final String minimumRate;
  final String maximumRate;
  final String interestMethod;
  final String ratePeriod;
  final String effectiveDate;
  final String changeReason;
  final String createdByUserId;
  final String? approvedByUserId;
  final DateTime createdAt;

  factory LoanPolicy.fromJson(Map<String, dynamic> json) => LoanPolicy(
    id: json['id'] as String,
    name: json['policyName'] as String,
    version: json['versionNumber'] as int,
    status: json['status'] as String,
    currency: json['currency'] as String,
    minimumRate: json['minimumRate'].toString(),
    maximumRate: json['maximumRate'].toString(),
    interestMethod: json['interestMethod'] as String,
    ratePeriod: json['ratePeriod'] as String,
    effectiveDate: json['effectiveDate'] as String,
    changeReason: json['changeReason'] as String,
    createdByUserId: json['createdByUserId'] as String,
    approvedByUserId: json['approvedByUserId'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
  );
}
