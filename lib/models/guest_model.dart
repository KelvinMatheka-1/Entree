enum GuestCheckInStatus { checkedIn, notArrived }

class GuestModel {
  final String id;
  final String passId;
  final String fullName;
  final String email;
  final String tableNumber;
  final String tableName;
  final GuestCheckInStatus status;
  final String? checkInTime;
  final String admission;
  final int guestCount;

  const GuestModel({
    required this.id,
    required this.passId,
    required this.fullName,
    required this.email,
    required this.tableNumber,
    required this.tableName,
    required this.status,
    this.checkInTime,
    this.admission = 'Supper pass',
    this.guestCount = 1,
  });

  factory GuestModel.fromJson(Map<String, dynamic> json) {
    return GuestModel(
      id: json['id']?.toString() ?? '',
      passId: json['passId']?.toString() ?? '',
      fullName: json['fullName']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      tableNumber: json['tableNumber']?.toString() ?? '01',
      tableName: json['tableName']?.toString() ?? 'General',
      status: json['status']?.toString() == 'checkedIn'
          ? GuestCheckInStatus.checkedIn
          : GuestCheckInStatus.notArrived,
      checkInTime: json['checkInTime']?.toString(),
      admission: json['admission']?.toString() ?? 'Standard pass',
      guestCount: (json['guestCount'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'passId': passId,
      'fullName': fullName,
      'email': email,
      'tableNumber': tableNumber,
      'tableName': tableName,
      'status': status == GuestCheckInStatus.checkedIn ? 'checkedIn' : 'notArrived',
      'checkInTime': checkInTime,
      'admission': admission,
      'guestCount': guestCount,
    };
  }

  GuestModel copyWith({
    String? id,
    String? passId,
    String? fullName,
    String? email,
    String? tableNumber,
    String? tableName,
    GuestCheckInStatus? status,
    String? checkInTime,
    String? admission,
    int? guestCount,
  }) {
    return GuestModel(
      id: id ?? this.id,
      passId: passId ?? this.passId,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      tableNumber: tableNumber ?? this.tableNumber,
      tableName: tableName ?? this.tableName,
      status: status ?? this.status,
      checkInTime: checkInTime ?? this.checkInTime,
      admission: admission ?? this.admission,
      guestCount: guestCount ?? this.guestCount,
    );
  }

  String get initials {
    final parts = fullName.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return fullName.substring(0, 2).toUpperCase();
  }

  bool get isCheckedIn => status == GuestCheckInStatus.checkedIn;
}
