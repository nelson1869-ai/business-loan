class BusinessSetting {
  const BusinessSetting({
    required this.businessName,
    required this.currencyCode,
    required this.receiptFooter,
    required this.updatedAt,
  });

  final String businessName;
  final String currencyCode;
  final String receiptFooter;
  final DateTime updatedAt;

  factory BusinessSetting.fromJson(Map<String, dynamic> json) =>
      BusinessSetting(
        businessName: json['businessName'] as String,
        currencyCode: json['currencyCode'] as String,
        receiptFooter: json['receiptFooter'] as String,
        updatedAt: DateTime.parse(json['updatedAt'] as String).toLocal(),
      );

  Map<String, dynamic> toJson() => {
    'businessName': businessName,
    'currencyCode': currencyCode,
    'receiptFooter': receiptFooter,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };
}
