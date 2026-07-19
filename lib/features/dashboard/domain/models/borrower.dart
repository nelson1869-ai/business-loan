/// Domain model class representing a Borrower in the lending system.
///
/// Holds Personally Identifiable Information (PII) such as names, phone, and
/// national ID, as well as metadata like status and creation timestamp.
///
/// File: `lib/features/dashboard/domain/models/borrower.dart`
///
/// Data Flow Diagram:
/// ```text
///  +--------------------------+     +---------------+     +---------------------------+
///  | borrower_repository.dart | <-> | borrower.dart | <-> | borrowers_provider.dart   |
///  +--------------------------+     +---------------+     +---------------------------+
/// ```
class Borrower {
  /// The unique identifier of the borrower.
  final String id;

  /// The borrower's first name.
  final String firstName;

  /// The borrower's last name.
  final String lastName;

  /// The borrower's national identity card number (encrypted at rest in DB).
  final String nationalId;

  /// The borrower's phone number (encrypted at rest in DB).
  final String phone;

  /// The borrower's date of birth in ISO-8601 format.
  final String dateOfBirth;

  /// The current status of the borrower (e.g., 'Pending', 'Synced').
  final String status;

  /// The timestamp when the borrower was registered in ISO-8601 format.
  final String createdAt;

  /// The concatenated full name of the borrower, combining [firstName] and [lastName].
  String get fullName => '$firstName $lastName';

  /// Creates a new [Borrower] instance.
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

  /// Factory constructor to parse a [Borrower] from a JSON map (camelCase keys).
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

  /// Factory constructor to parse a [Borrower] from a database map (snake_case keys).
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

  /// Converts the [Borrower] instance into a database map using snake_case keys.
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

  /// Converts the [Borrower] instance into a JSON map using camelCase keys.
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
