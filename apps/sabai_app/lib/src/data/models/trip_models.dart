/// Trips, days and activities (backend: /trips). Dates are ISO `YYYY-MM-DD`; activity times are `HH:MM` or empty.

class Activity {
  const Activity({
    required this.id,
    required this.title,
    this.destinationId = '',
    this.startTime = '',
    this.endTime = '',
  });

  final String id;
  final String title;
  final String destinationId;
  final String startTime;
  final String endTime;

  factory Activity.fromJson(Map<String, dynamic> j) => Activity(
        id: (j['id'] ?? '').toString(),
        title: (j['title'] ?? '').toString(),
        destinationId: (j['destination_id'] ?? '').toString(),
        startTime: clockOf((j['starts_at'] ?? '').toString()),
        endTime: clockOf((j['ends_at'] ?? '').toString()),
      );

  /// `2030-01-10T09:30:00.000000Z` -> `09:30`; anything shorter -> ''.
  static String clockOf(String iso) => iso.length >= 16 && iso[10] == 'T' ? iso.substring(11, 16) : '';
}

class TripDay {
  const TripDay({
    required this.id,
    required this.date,
    required this.dayNumber,
    this.activities = const [],
  });

  final String id;
  final String date;
  final int dayNumber;
  final List<Activity> activities;

  factory TripDay.fromJson(Map<String, dynamic> j) => TripDay(
        id: (j['id'] ?? '').toString(),
        date: (j['date'] ?? '').toString(),
        dayNumber: j['day_number'] is int ? j['day_number'] as int : 0,
        activities: (j['activities'] is List ? j['activities'] as List<dynamic> : const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(Activity.fromJson)
            .toList(),
      );
}

class Trip {
  const Trip({
    required this.id,
    required this.name,
    this.destinationId = '',
    this.startDate = '',
    this.endDate = '',
    this.status = 'DRAFT',
    this.days = const [],
  });

  final String id;
  final String name;
  final String destinationId;
  final String startDate;
  final String endDate;
  final String status;
  final List<TripDay> days;

  int get activityCount => days.fold(0, (n, d) => n + d.activities.length);

  factory Trip.fromJson(Map<String, dynamic> j) => Trip(
        id: (j['id'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        destinationId: (j['destination_id'] ?? '').toString(),
        startDate: (j['start_date'] ?? '').toString(),
        endDate: (j['end_date'] ?? '').toString(),
        status: (j['status'] ?? 'DRAFT').toString(),
        days: (j['days'] is List ? j['days'] as List<dynamic> : const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .map(TripDay.fromJson)
            .toList(),
      );
}
