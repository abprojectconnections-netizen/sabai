List<String> _strings(Object? v) => v is List ? v.map((e) => e.toString()).toList() : const [];

int _int(Object? v) => v is num ? v.toInt() : 0;

Map<String, int> _intMap(Object? v) =>
    v is Map ? {for (final e in v.entries) e.key.toString(): _int(e.value)} : const <String, int>{};

/// An account as shown to administrators (GET /admin/users). The server never sends a password hash or phone number.
class AdminUser {
  const AdminUser({
    required this.id,
    required this.email,
    required this.status,
    this.roles = const [],
    this.createdAt = '',
    this.lastLoginAt,
    this.displayName,
    this.pendingRoles = const [],
  });

  final String id;
  final String email;
  final String status;
  final List<String> roles;
  final String createdAt;
  final String? lastLoginAt;
  final String? displayName;

  /// Roles that were requested for this account and are still waiting for a second person to approve (detail only).
  final List<String> pendingRoles;

  bool get suspended => status == 'SUSPENDED';

  AdminUser copyWith({String? status}) => AdminUser(
        id: id,
        email: email,
        status: status ?? this.status,
        roles: roles,
        createdAt: createdAt,
        lastLoginAt: lastLoginAt,
        displayName: displayName,
        pendingRoles: pendingRoles,
      );

  factory AdminUser.fromJson(Map<String, dynamic> j) {
    final pending = j['pending_role_requests'];
    return AdminUser(
      id: (j['id'] ?? '').toString(),
      email: (j['email'] ?? '').toString(),
      status: (j['status'] ?? '').toString(),
      roles: _strings(j['roles']),
      createdAt: (j['created_at'] ?? '').toString(),
      lastLoginAt: j['last_login_at']?.toString(),
      displayName: j['display_name']?.toString(),
      pendingRoles: pending is List
          ? pending.whereType<Map<String, dynamic>>().map((p) => (p['role'] ?? '').toString()).where((s) => s.isNotEmpty).toList()
          : const [],
    );
  }
}

class AdminUsersPage {
  const AdminUsersPage({required this.items, required this.total});

  final List<AdminUser> items;
  final int total;
}

/// One row of the read-only audit trail (GET /admin/audit-logs).
class AuditEntry {
  const AuditEntry({
    required this.id,
    required this.createdAt,
    required this.actorEmail,
    required this.action,
    required this.subjectType,
    required this.subjectId,
    this.before,
    this.after,
  });

  final String id;
  final String createdAt;
  final String actorEmail;
  final String action;
  final String subjectType;
  final String subjectId;
  final Map<String, dynamic>? before;
  final Map<String, dynamic>? after;

  factory AuditEntry.fromJson(Map<String, dynamic> j) => AuditEntry(
        id: (j['id'] ?? '').toString(),
        createdAt: (j['created_at'] ?? '').toString(),
        actorEmail: (j['actor_email'] ?? '').toString(),
        action: (j['action'] ?? '').toString(),
        subjectType: (j['subject_type'] ?? '').toString(),
        subjectId: (j['subject_id'] ?? '').toString(),
        before: j['before'] is Map<String, dynamic> ? j['before'] as Map<String, dynamic> : null,
        after: j['after'] is Map<String, dynamic> ? j['after'] as Map<String, dynamic> : null,
      );
}

class AuditPage {
  const AuditPage({required this.items, required this.total});

  final List<AuditEntry> items;
  final int total;
}

/// Live counts from GET /admin/dashboard. Counts only; money figures are not part of this screen.
class DashboardStats {
  const DashboardStats({
    this.usersTotal = 0,
    this.usersActive = 0,
    this.usersSuspended = 0,
    this.usersNew7 = 0,
    this.bookingsByStatus = const {},
    this.bookingsNew7 = 0,
    this.paymentsByStatus = const {},
    this.queues = const {},
  });

  final int usersTotal;
  final int usersActive;
  final int usersSuspended;
  final int usersNew7;
  final Map<String, int> bookingsByStatus;
  final int bookingsNew7;
  final Map<String, int> paymentsByStatus;

  /// partners_pending, tickets_open, disputes_open, refunds_open, role_requests_pending, community_reports_open
  final Map<String, int> queues;

  int get bookingsTotal => bookingsByStatus.values.fold(0, (a, b) => a + b);

  int queue(String key) => queues[key] ?? 0;

  factory DashboardStats.fromJson(Map<String, dynamic> j) {
    final users = j['users'] is Map<String, dynamic> ? j['users'] as Map<String, dynamic> : const <String, dynamic>{};
    final bookings = j['bookings'] is Map<String, dynamic> ? j['bookings'] as Map<String, dynamic> : const <String, dynamic>{};
    final payments = j['payments'] is Map<String, dynamic> ? j['payments'] as Map<String, dynamic> : const <String, dynamic>{};
    return DashboardStats(
      usersTotal: _int(users['total']),
      usersActive: _int(users['active']),
      usersSuspended: _int(users['suspended']),
      usersNew7: _int(users['new_last_7_days']),
      bookingsByStatus: _intMap(bookings['by_status']),
      bookingsNew7: _int(bookings['created_last_7_days']),
      paymentsByStatus: _intMap(payments['by_status']),
      queues: _intMap(j['queues']),
    );
  }
}

/// A runtime feature flag (GET /admin/feature-flags). Switching one off stops that feature for every user at once.
class FeatureFlag {
  const FeatureFlag({required this.key, required this.enabled, this.description = '', this.updatedBy});

  final String key;
  final bool enabled;
  final String description;

  /// E-mail of whoever last changed it, if anyone has.
  final String? updatedBy;

  FeatureFlag copyWith({bool? enabled}) =>
      FeatureFlag(key: key, enabled: enabled ?? this.enabled, description: description, updatedBy: updatedBy);

  factory FeatureFlag.fromJson(Map<String, dynamic> j) => FeatureFlag(
        key: (j['key'] ?? '').toString(),
        enabled: j['enabled'] != false, // an absent value means on, like the server
        description: (j['description'] ?? '').toString(),
        updatedBy: j['updated_by']?.toString(),
      );
}
