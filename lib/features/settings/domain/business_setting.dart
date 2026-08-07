class BusinessSetting {
  const BusinessSetting({
    required this.businessName,
    required this.currencyCode,
    required this.receiptFooter,
    required this.updatedAt,
    this.defaultMonthlyEstimateRate,
  });

  final String businessName;
  final String currencyCode;
  final String receiptFooter;
  final DateTime updatedAt;

  /// Decimal string as stored by backend (e.g. "0.10000000" = 10% monthly).
  /// Null means the Owner has not configured a borrower estimate rate.
  final String? defaultMonthlyEstimateRate;

  factory BusinessSetting.fromJson(Map<String, dynamic> json) =>
      BusinessSetting(
        businessName: json['businessName'] as String,
        currencyCode: json['currencyCode'] as String,
        receiptFooter: json['receiptFooter'] as String,
        updatedAt: DateTime.parse(json['updatedAt'] as String).toLocal(),
        defaultMonthlyEstimateRate:
            json['defaultMonthlyEstimateRate'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'businessName': businessName,
        'currencyCode': currencyCode,
        'receiptFooter': receiptFooter,
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        if (defaultMonthlyEstimateRate != null)
          'defaultMonthlyEstimateRate': defaultMonthlyEstimateRate,
      };
}
