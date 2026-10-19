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

  factory EventModel.fromJson(Map<String, dynamic> json) {
    EventStatus parseStatus(String? s) {
      switch (s?.toLowerCase()) {
        case 'live':
          return EventStatus.live;
        case 'upcoming':
          return EventStatus.upcoming;
        case 'draft':
          return EventStatus.draft;
        case 'past':
          return EventStatus.past;
        default:
          return EventStatus.upcoming;
      }
    }

    return EventModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      venue: json['venue']?.toString() ?? 'Main Venue',
      venueAddress: json['venueAddress']?.toString() ?? '',
      collection: json['collection']?.toString() ?? 'GENERAL EVENT',
      description: json['description']?.toString() ?? '',
      date: json['date'] != null
          ? DateTime.tryParse(json['date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      startTime: json['startTime']?.toString() ?? '18:00',
      endTime: json['endTime']?.toString() ?? '22:00',
      doorsOpenTime: json['doorsOpenTime']?.toString() ?? '17:30',
      tables: (json['tables'] as num?)?.toInt() ?? 10,
      seatsPerTable: (json['seatsPerTable'] as num?)?.toInt() ?? 10,
      totalCapacity: (json['totalCapacity'] as num?)?.toInt() ?? 100,
      passesIssued: (json['passesIssued'] as num?)?.toInt() ?? 0,
      checkedIn: (json['checkedIn'] as num?)?.toInt() ?? 0,
      status: parseStatus(json['status']?.toString()),
      imageUrl: json['imageUrl']?.toString(),
      isPaid: json['isPaid'] is bool
          ? json['isPaid']
          : (json['isPaid'] == 1 || json['isPaid'] == 'true'),
      priceBadge: json['priceBadge']?.toString(),
      attendeeAvatars: json['attendeeAvatars'] != null
          ? List<String>.from(json['attendeeAvatars'])
          : null,
      city: json['city']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'venue': venue,
      'venueAddress': venueAddress,
      'collection': collection,
      'description': description,
      'date': '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      'startTime': startTime,
      'endTime': endTime,
      'doorsOpenTime': doorsOpenTime,
      'tables': tables,
      'seatsPerTable': seatsPerTable,
      'totalCapacity': totalCapacity,
      'passesIssued': passesIssued,
      'checkedIn': checkedIn,
      'status': status.name,
      'imageUrl': imageUrl,
      'isPaid': isPaid,
      'priceBadge': priceBadge,
      'attendeeAvatars': attendeeAvatars,
      'city': city,
    };
  }

  EventModel copyWith({
    String? id,
    String? name,
    String? venue,
    String? venueAddress,
    String? collection,
    String? description,
    DateTime? date,
    String? startTime,
    String? endTime,
    String? doorsOpenTime,
    int? tables,
    int? seatsPerTable,
    int? totalCapacity,
    int? passesIssued,
    int? checkedIn,
    EventStatus? status,
    String? imageUrl,
    bool? isPaid,
    String? priceBadge,
    List<String>? attendeeAvatars,
    String? city,
  }) {
    return EventModel(
      id: id ?? this.id,
      name: name ?? this.name,
      venue: venue ?? this.venue,
      venueAddress: venueAddress ?? this.venueAddress,
      collection: collection ?? this.collection,
      description: description ?? this.description,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      doorsOpenTime: doorsOpenTime ?? this.doorsOpenTime,
      tables: tables ?? this.tables,
      seatsPerTable: seatsPerTable ?? this.seatsPerTable,
      totalCapacity: totalCapacity ?? this.totalCapacity,
      passesIssued: passesIssued ?? this.passesIssued,
      checkedIn: checkedIn ?? this.checkedIn,
      status: status ?? this.status,
      imageUrl: imageUrl ?? this.imageUrl,
      isPaid: isPaid ?? this.isPaid,
      priceBadge: priceBadge ?? this.priceBadge,
      attendeeAvatars: attendeeAvatars ?? this.attendeeAvatars,
      city: city ?? this.city,
    );
  }

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

