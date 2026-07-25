class Borrower {
  final String id;
  final String firstName;
  final String lastName;
  final String nationalId;
  final String phone;
  final String dateOfBirth;
  final String status;
  final String createdAt;

  String get fullName => '$firstName $lastName'.trim();

  const Borrower({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.nationalId,
    required this.phone,
    required this.dateOfBirth,
    required this.status,
    required this.createdAt,
  });

  factory Borrower.fromJson(Map<String, dynamic> json) {
    return Borrower(
      id: (json['id'] ?? '').toString(),
      firstName: (json['firstName'] ?? json['first_name'] ?? '').toString(),
      lastName: (json['lastName'] ?? json['last_name'] ?? '').toString(),
      nationalId: (json['nationalId'] ?? json['national_id'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      dateOfBirth: (json['dateOfBirth'] ?? json['date_of_birth'] ?? '')
          .toString(),
      status: (json['status'] ?? 'Active').toString(),
      createdAt: (json['createdAt'] ?? json['created_at'] ?? '').toString(),
    );
  }

  factory Borrower.fromMap(Map<String, dynamic> map) {
    return Borrower(
      id: (map['id'] ?? '').toString(),
      firstName: (map['first_name'] ?? map['firstName'] ?? '').toString(),
      lastName: (map['last_name'] ?? map['lastName'] ?? '').toString(),
      nationalId: (map['national_id'] ?? map['nationalId'] ?? '').toString(),
      phone: (map['phone'] ?? '').toString(),
      dateOfBirth: (map['date_of_birth'] ?? map['dateOfBirth'] ?? '')
          .toString(),
      status: (map['status'] ?? 'Active').toString(),
      createdAt: (map['created_at'] ?? map['createdAt'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'first_name': firstName,
      'last_name': lastName,
      'national_id': nationalId,
      'phone': phone,
      'date_of_birth': dateOfBirth,
      'status': status,
      'created_at': createdAt,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'firstName': firstName,
      'lastName': lastName,
      'nationalId': nationalId,
      'phone': phone,
      'dateOfBirth': dateOfBirth,
      'status': status,
      'createdAt': createdAt,
    };
  }
}
