/// Notifications and reviews (backend: /notifications, /reviews).

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.read,
    required this.date,
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final bool read;
  final String date;

  AppNotification copyWith({bool? read}) =>
      AppNotification(id: id, type: type, title: title, body: body, read: read ?? this.read, date: date);

  factory AppNotification.fromJson(Map<String, dynamic> j) {
    final created = (j['created_at'] ?? '').toString();
    return AppNotification(
      id: (j['id'] ?? '').toString(),
      type: (j['type'] ?? 'system').toString(),
      title: (j['title'] ?? '').toString(),
      body: (j['body'] ?? '').toString(),
      read: j['read'] == true,
      date: created.length >= 10 ? created.substring(0, 10) : '',
    );
  }
}

class NotificationsPage {
  const NotificationsPage({this.items = const [], this.unreadCount = 0});
  final List<AppNotification> items;
  final int unreadCount;
}

/// Server-side subject types. The app only offers BOOKING (the user's own booking): the API does not verify that a subject exists.
const String reviewSubjectBooking = 'BOOKING';

class Review {
  const Review({
    required this.id,
    required this.subjectType,
    required this.subjectId,
    required this.rating,
    required this.body,
    required this.date,
    this.tags = const [],
  });

  final String id;
  final String subjectType;
  final String subjectId;
  final double rating;
  final String body;
  final String date;

  /// Tag labels (central tagging system, content type REVIEW).
  final List<String> tags;

  Review withTags(List<String> t) =>
      Review(id: id, subjectType: subjectType, subjectId: subjectId, rating: rating, body: body, date: date, tags: t);

  factory Review.fromJson(Map<String, dynamic> j) {
    final created = (j['created_at'] ?? '').toString();
    final r = j['rating'];
    return Review(
      id: (j['id'] ?? '').toString(),
      subjectType: (j['subject_type'] ?? '').toString(),
      subjectId: (j['subject_id'] ?? '').toString(),
      rating: r is num ? r.toDouble() : 0,
      body: (j['body'] ?? '').toString(),
      date: created.length >= 10 ? created.substring(0, 10) : '',
    );
  }
}
