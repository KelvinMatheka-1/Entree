class UserProfileModel {
  final String id;
  final String fullName;
  final String email;
  final String role;
  final String organization;
  final String phone;
  final String avatarUrl;
  final String? bio;
  final String scannerSpeed;
  final bool hapticFeedback;
  final String? updatedAt;

  const UserProfileModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.organization,
    required this.phone,
    this.avatarUrl = '',
    this.bio,
    this.scannerSpeed = 'High sensitivity',
    this.hapticFeedback = true,
    this.updatedAt,
  });

  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return 'EM';
    if (parts.length == 1) return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    return UserProfileModel(
      id: json['id']?.toString() ?? 'default-user',
      fullName: json['fullName']?.toString() ?? json['full_name']?.toString() ?? 'Kelvin Matheka',
      email: json['email']?.toString() ?? 'kelvin@entree.app',
      role: json['role']?.toString() ?? 'Event Owner',
      organization: json['organization']?.toString() ?? 'Entrée',
      phone: json['phone']?.toString() ?? '+254 700 000 000',
      avatarUrl: json['avatarUrl']?.toString() ?? json['avatar_url']?.toString() ?? '',
      bio: json['bio']?.toString(),
      scannerSpeed: json['scannerSpeed']?.toString() ?? json['scanner_speed']?.toString() ?? 'High sensitivity',
      hapticFeedback: json['hapticFeedback'] == true || json['haptic_feedback'] == true || json['haptic_feedback'] == 1,
      updatedAt: json['updatedAt']?.toString() ?? json['updated_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'email': email,
      'role': role,
      'organization': organization,
      'phone': phone,
      'avatarUrl': avatarUrl,
      'bio': bio,
      'scannerSpeed': scannerSpeed,
      'hapticFeedback': hapticFeedback,
      'updatedAt': updatedAt,
    };
  }

  UserProfileModel copyWith({
    String? id,
    String? fullName,
    String? email,
    String? role,
    String? organization,
    String? phone,
    String? avatarUrl,
    String? bio,
    String? scannerSpeed,
    bool? hapticFeedback,
    String? updatedAt,
  }) {
    return UserProfileModel(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      role: role ?? this.role,
      organization: organization ?? this.organization,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      scannerSpeed: scannerSpeed ?? this.scannerSpeed,
      hapticFeedback: hapticFeedback ?? this.hapticFeedback,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class ProfileStats {
  final int totalEvents;
  final int totalCapacity;
  final int totalCheckedIn;
  final int totalPasses;
  final String checkInRate;
  final int pendingSyncs;

  const ProfileStats({
    required this.totalEvents,
    required this.totalCapacity,
    required this.totalCheckedIn,
    required this.totalPasses,
    required this.checkInRate,
    required this.pendingSyncs,
  });

  factory ProfileStats.fromJson(Map<String, dynamic> json) {
    return ProfileStats(
      totalEvents: int.tryParse(json['totalEvents']?.toString() ?? '0') ?? 0,
      totalCapacity: int.tryParse(json['totalCapacity']?.toString() ?? '0') ?? 0,
      totalCheckedIn: int.tryParse(json['totalCheckedIn']?.toString() ?? '0') ?? 0,
      totalPasses: int.tryParse(json['totalPasses']?.toString() ?? '0') ?? 0,
      checkInRate: json['checkInRate']?.toString() ?? '0.0%',
      pendingSyncs: int.tryParse(json['pendingSyncs']?.toString() ?? '0') ?? 0,
    );
  }
}

class UpstreamStatus {
  final bool configured;
  final String mode;
  final String target;
  final String frontend;

  const UpstreamStatus({
    required this.configured,
    required this.mode,
    required this.target,
    required this.frontend,
  });

  factory UpstreamStatus.fromJson(Map<String, dynamic> json) {
    return UpstreamStatus(
      configured: json['configured'] == true,
      mode: json['mode']?.toString() ?? 'local',
      target: json['target']?.toString() ?? 'https://checkin-backend.machinenova.com',
      frontend: json['frontend']?.toString() ?? 'https://checkin.machinenova.com',
    );
  }
}

class FullProfileData {
  final UserProfileModel profile;
  final ProfileStats stats;
  final UpstreamStatus upstream;

  const FullProfileData({
    required this.profile,
    required this.stats,
    required this.upstream,
  });

  factory FullProfileData.fromJson(Map<String, dynamic> json) {
    return FullProfileData(
      profile: UserProfileModel.fromJson(json['profile'] as Map<String, dynamic>? ?? {}),
      stats: ProfileStats.fromJson(json['stats'] as Map<String, dynamic>? ?? {}),
      upstream: UpstreamStatus.fromJson(json['upstream'] as Map<String, dynamic>? ?? {}),
    );
  }

  FullProfileData copyWith({
    UserProfileModel? profile,
    ProfileStats? stats,
    UpstreamStatus? upstream,
  }) {
    return FullProfileData(
      profile: profile ?? this.profile,
      stats: stats ?? this.stats,
      upstream: upstream ?? this.upstream,
    );
  }
}
