class Borrower {
  final String id;
  final String firstName;
  final String lastName;
  final String nationalId;
  final String phone;
  final String dateOfBirth;
  final String status;
  final String createdAt;
  final String syncStatus;

  bool get isServerVerified => syncStatus == 'synced';

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
    this.syncStatus = 'synced',
  });

  factory Borrower.fromJson(Map<String, dynamic> json) =>
      Borrower.fromMap(json);

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
      syncStatus: (map['sync_status'] ?? map['syncStatus'] ?? 'synced')
          .toString(),
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
      'sync_status': syncStatus,
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
