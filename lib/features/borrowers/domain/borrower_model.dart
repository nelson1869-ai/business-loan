class Borrower {
  final String id;
  final String firstName;
  final String lastName;
  final String nationalId;
  final String phone;
  final String dateOfBirth;
  final String status;
  final String createdAt;

  String get fullName => '$firstName $lastName';

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
      id: json['id'] as String,
      firstName: json['firstName'] as String,
      lastName: json['lastName'] as String,
      nationalId: json['nationalId'] as String,
      phone: json['phone'] as String,
      dateOfBirth: json['dateOfBirth'] as String,
      status: json['status'] as String,
      createdAt: json['createdAt'] as String,
    );
  }

  factory Borrower.fromMap(Map<String, dynamic> map) {
    return Borrower(
      id: map['id'] as String,
      firstName: map['first_name'] as String,
      lastName: map['last_name'] as String,
      nationalId: map['national_id'] as String,
      phone: map['phone'] as String,
      dateOfBirth: map['date_of_birth'] as String,
      status: map['status'] as String,
      createdAt: map['created_at'] as String,
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
