class AppNotification {
  const AppNotification({
    required this.id,
    required this.category,
    required this.priority,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.isRead,
    this.borrowerId,
    this.loanId,
  });

  final String id;
  final String category;
  final String priority;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;
  final String? borrowerId;
  final String? loanId;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      category: json['category'] as String,
      priority: json['priority'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      isRead: json['readAt'] != null,
      borrowerId: json['borrowerId'] as String?,
      loanId: json['loanId'] as String?,
    );
  }
}
