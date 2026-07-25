class AppUser {
  const AppUser({
    required this.id,
    required this.username,
    required this.role,
    required this.createdAt,
  });

  final String id;
  final String username;
  final String role;
  final DateTime createdAt;

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: json['id'] as String,
    username: json['username'] as String,
    role: json['role'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
  );
}
