enum EventStatus { live, upcoming, draft, past }

class EventModel {
  final String id;
  final String name;
  final String venue;
  final String venueAddress;
  final String collection;
  final String description;
  final DateTime date;
  final String startTime;
  final String endTime;
  final String doorsOpenTime;
  final int tables;
  final int seatsPerTable;
  final int totalCapacity;
  final int passesIssued;
  final int checkedIn;
  final EventStatus status;
  final String? imageUrl;

  final bool isPaid;
  final String? priceBadge;
  final List<String>? attendeeAvatars;
  final String? city;

  const EventModel({
    required this.id,
    required this.name,
    required this.venue,
    required this.venueAddress,
    required this.collection,
    required this.description,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.doorsOpenTime,
    required this.tables,
    required this.seatsPerTable,
    required this.totalCapacity,
    required this.passesIssued,
    required this.checkedIn,
    required this.status,
    this.imageUrl,
    this.isPaid = true,
    this.priceBadge,
    this.attendeeAvatars,
    this.city,
  });

  int get available => totalCapacity - passesIssued;
  int get expected => passesIssued - checkedIn;
  double get checkedInPercentage =>
      passesIssued > 0 ? checkedIn / passesIssued : 0;

  String get priceLabel => priceBadge ?? (isPaid ? '\$ Paid' : 'Free');

  String get monthShort {
    const months = [
      'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
      'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'
    ];
    return months[date.month - 1];
  }

  String get dayString => date.day.toString();

  String get cityOrVenue {
    if (city != null && city!.isNotEmpty) return city!;
    if (venueAddress.contains(',')) {
      return venueAddress.split(',').last.trim();
    }
    return venue;
  }

  String get relativeStatusText {
    if (status == EventStatus.live) {
      return 'Going On';
    }
    final now = DateTime.now();
    final diff = date.difference(DateTime(now.year, now.month, now.day));
    if (diff.inDays <= 0) {
      return 'In 25 Min';
    } else if (diff.inDays == 1) {
      return 'Tomorrow';
    } else if (diff.inDays <= 7) {
      return 'In ${diff.inDays} days';
    } else {
      return 'Upcoming';
    }
  }

  String get dateFormatted {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    const days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday'
    ];
    return '${days[date.weekday - 1]}, ${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String get shortDate {
    const months = [
      'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
      'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'
    ];
    return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]}';
  }
}

