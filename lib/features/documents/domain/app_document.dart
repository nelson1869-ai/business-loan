class AppDocument {
  const AppDocument({
    required this.id,
    required this.borrowerId,
    required this.uploadedByUserId,
    required this.title,
    required this.fileName,
    required this.contentType,
    required this.sizeBytes,
    required this.createdAt,
    required this.canDelete,
    this.loanId,
  });

  final String id;
  final String borrowerId;
  final String? loanId;
  final String uploadedByUserId;
  final String title;
  final String fileName;
  final String contentType;
  final int sizeBytes;
  final DateTime createdAt;
  final bool canDelete;

  factory AppDocument.fromJson(Map<String, dynamic> json) => AppDocument(
    id: json['id'] as String,
    borrowerId: json['borrowerId'] as String,
    loanId: json['loanId'] as String?,
    uploadedByUserId: json['uploadedByUserId'] as String,
    title: json['title'] as String,
    fileName: json['fileName'] as String,
    contentType: json['contentType'] as String,
    sizeBytes: json['sizeBytes'] as int,
    createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
    canDelete: json['canDelete'] as bool,
  );
}
