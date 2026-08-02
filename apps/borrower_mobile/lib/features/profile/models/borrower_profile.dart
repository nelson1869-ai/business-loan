import 'package:equatable/equatable.dart';

class BorrowerProfile extends Equatable {
  final String borrowerAccountId;
  final String borrowerId;
  final String firstName;
  final String lastName;
  final String phoneNumber;
  final String accountStatus;
  final DateTime createdAt;
  final bool isFromCache;

  const BorrowerProfile({
    required this.borrowerAccountId,
    required this.borrowerId,
    required this.firstName,
    required this.lastName,
    required this.phoneNumber,
    required this.accountStatus,
    required this.createdAt,
    this.isFromCache = false,
  });

  String get fullName => '$firstName $lastName'.trim();

  factory BorrowerProfile.fromJson(
    Map<String, dynamic> json, {
    bool isFromCache = false,
  }) {
    return BorrowerProfile(
      borrowerAccountId: json['borrowerAccountId'] as String,
      borrowerId: json['borrowerId'] as String,
      firstName: json['firstName'] as String,
      lastName: json['lastName'] as String,
      phoneNumber: json['phoneNumber'] as String,
      accountStatus: json['accountStatus'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      isFromCache: isFromCache,
    );
  }

  Map<String, dynamic> toJson() => {
        'borrowerAccountId': borrowerAccountId,
        'borrowerId': borrowerId,
        'firstName': firstName,
        'lastName': lastName,
        'phoneNumber': phoneNumber,
        'accountStatus': accountStatus,
        'createdAt': createdAt.toIso8601String(),
      };

  @override
  List<Object?> get props => [
        borrowerAccountId,
        borrowerId,
        firstName,
        lastName,
        phoneNumber,
        accountStatus,
        createdAt,
        isFromCache,
      ];
}
