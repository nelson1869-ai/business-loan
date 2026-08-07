class Note {
  const Note({
    required this.id,
    required this.borrowerId,
    required this.authorName,
    required this.category,
    required this.content,
    required this.createdAt,
    required this.canDelete,
    this.loanId,
  });

  final String id;
  final String borrowerId;
  final String? loanId;
  final String authorName;
  final String category;
  final String content;
  final DateTime createdAt;
  final bool canDelete;

  factory Note.fromJson(Map<String, dynamic> json) => Note(
    id: json['id'] as String,
    borrowerId: json['borrowerId'] as String,
    loanId: json['loanId'] as String?,
    authorName: json['authorName'] as String,
    category: json['category'] as String,
    content: json['content'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    canDelete: json['canDelete'] as bool? ?? false,
  );
}
