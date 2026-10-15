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

  String get initials {
    final parts = fullName.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return fullName.substring(0, 2).toUpperCase();
  }

  bool get isCheckedIn => status == GuestCheckInStatus.checkedIn;
}
