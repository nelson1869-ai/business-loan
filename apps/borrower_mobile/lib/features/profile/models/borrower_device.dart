import 'package:equatable/equatable.dart';

class DeviceRegisterRequest extends Equatable {
  final String deviceIdentifier;
  final String platform;
  final String? pushToken;

  const DeviceRegisterRequest({
    required this.deviceIdentifier,
    this.platform = 'android',
    this.pushToken,
  });

  Map<String, dynamic> toJson() => {
        'deviceIdentifier': deviceIdentifier,
        'platform': platform,
        if (pushToken != null) 'pushToken': pushToken,
      };

  @override
  List<Object?> get props => [deviceIdentifier, platform, pushToken];
}

class DeviceResponse extends Equatable {
  final String id;
  final String platform;
  final bool isActive;
  final DateTime lastSeenAt;

  const DeviceResponse({
    required this.id,
    required this.platform,
    required this.isActive,
    required this.lastSeenAt,
  });

  factory DeviceResponse.fromJson(Map<String, dynamic> json) {
    return DeviceResponse(
      id: json['id'] as String,
      platform: json['platform'] as String,
      isActive: json['isActive'] as bool,
      lastSeenAt: DateTime.parse(json['lastSeenAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'platform': platform,
        'isActive': isActive,
        'lastSeenAt': lastSeenAt.toIso8601String(),
      };

  @override
  List<Object?> get props => [id, platform, isActive, lastSeenAt];
}
