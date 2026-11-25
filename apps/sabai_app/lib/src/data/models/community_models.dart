/// Community posts and saved coupons (backend: /community, /coupons).

class CommunityPost {
  const CommunityPost({
    required this.id,
    required this.body,
    required this.authorName,
    required this.date,
    required this.mine,
    this.tags = const [],
  });

  final String id;
  final String body;
  final String authorName;
  final String date;

  /// True when the signed-in user wrote the post (the server decides; only then may it be deleted).
  final bool mine;
  final List<String> tags;

  CommunityPost withTags(List<String> t) =>
      CommunityPost(id: id, body: body, authorName: authorName, date: date, mine: mine, tags: t);

  factory CommunityPost.fromJson(Map<String, dynamic> j) {
    final created = (j['created_at'] ?? '').toString();
    final author = j['author'];
    final name = author is Map ? (author['display_name'] ?? '').toString() : '';
    final tags = j['tags'];
    return CommunityPost(
      id: (j['id'] ?? '').toString(),
      body: (j['body'] ?? '').toString(),
      authorName: name.isEmpty ? 'สมาชิก' : name,
      date: created.length >= 10 ? created.substring(0, 10) : '',
      mine: j['mine'] == true,
      tags: tags is List ? tags.map((t) => t.toString()).where((t) => t.isNotEmpty).toList() : const [],
    );
  }
}

/// Report reasons accepted by the server.
const List<String> communityReportReasons = ['SPAM', 'ABUSE', 'MISLEADING', 'OTHER'];

String communityReportReasonTh(String reason) {
  switch (reason) {
    case 'SPAM':
      return 'สแปมหรือโฆษณา';
    case 'ABUSE':
      return 'ข้อความไม่เหมาะสม';
    case 'MISLEADING':
      return 'ข้อมูลทำให้เข้าใจผิด';
    default:
      return 'อื่น ๆ';
  }
}

/// A coupon the user saved. Saving never changes a price: the app cannot apply it to a booking.
class SavedCoupon {
  const SavedCoupon({
    required this.code,
    required this.title,
    required this.discountType,
    required this.value,
    required this.validFrom,
    required this.validUntil,
    required this.state,
  });

  final String code;
  final String title;

  /// FIXED, PERCENT or empty when the coupon carries no discount rule.
  final String discountType;

  /// Decimal string from the server, shown as is.
  final String value;
  final String validFrom;
  final String validUntil;

  /// ACTIVE, EXPIRED, NOT_STARTED, EXHAUSTED or UNAVAILABLE (computed by the server).
  final String state;

  bool get isActive => state == 'ACTIVE';

  /// Human-readable value, or empty when the server did not describe a discount.
  String get valueLabel {
    if (value.isEmpty) return '';
    if (discountType == 'PERCENT') return 'ลด $value%';
    if (discountType == 'FIXED') return 'ลด $value บาท';
    return '';
  }

  factory SavedCoupon.fromJson(Map<String, dynamic> j) {
    String day(Object? v) {
      final s = (v ?? '').toString();
      return s.length >= 10 ? s.substring(0, 10) : '';
    }

    return SavedCoupon(
      code: (j['code'] ?? '').toString(),
      title: (j['title'] ?? '').toString(),
      discountType: (j['discount_type'] ?? '').toString(),
      value: (j['value'] ?? '').toString(),
      validFrom: day(j['valid_from']),
      validUntil: day(j['valid_until']),
      state: (j['state'] ?? 'UNAVAILABLE').toString(),
    );
  }
}

String couponStateTh(String state) {
  switch (state) {
    case 'ACTIVE':
      return 'ใช้งานได้';
    case 'EXPIRED':
      return 'หมดอายุ';
    case 'NOT_STARTED':
      return 'ยังไม่เริ่ม';
    case 'EXHAUSTED':
      return 'ถูกใช้ครบแล้ว';
    default:
      return 'ไม่พร้อมใช้งาน';
  }
}

/// What the signed-in user may do, from GET /me. Used only to decide which screens to offer; the server enforces
/// every action regardless.
class AccountInfo {
  const AccountInfo({this.roles = const [], this.permissions = const []});

  final List<String> roles;
  final List<String> permissions;

  bool get canModerateCommunity => permissions.contains('portal.read') && permissions.contains('support.manage');

  /// user.manage: list, inspect and suspend accounts (System Admin).
  bool get canManageUsers => permissions.contains('user.manage');

  /// audit.read: read the audit trail (Auditor, CFO). System Admin deliberately does not have it.
  bool get canReadAudit => permissions.contains('audit.read');

  bool get canViewDashboard => canManageUsers || canReadAudit || permissions.contains('portal.read');

  /// booking.manage / support.manage / partner.review: the staff work queues (a role may hold only some of them).
  bool get canManageBookings => permissions.contains('booking.manage');
  bool get canManageDisputes => permissions.contains('support.manage');
  bool get canReviewPartners => permissions.contains('partner.review');
  bool get hasStaffQueues => canManageBookings || canManageDisputes || canReviewPartners;

  /// Whether the admin console has anything to show this person.
  bool get hasAdminConsole => canManageUsers || canReadAudit;

  factory AccountInfo.fromJson(Map<String, dynamic> j) {
    List<String> strings(Object? v) => v is List ? v.map((e) => e.toString()).toList() : const [];
    return AccountInfo(roles: strings(j['roles']), permissions: strings(j['permissions']));
  }
}

/// A live post with open reports, as shown to staff.
class ReportedPost {
  const ReportedPost({
    required this.id,
    required this.body,
    required this.authorName,
    required this.date,
    required this.reportCount,
    required this.reasons,
  });

  final String id;
  final String body;
  final String authorName;
  final String date;
  final int reportCount;
  final List<String> reasons;

  factory ReportedPost.fromJson(Map<String, dynamic> j) {
    final created = (j['created_at'] ?? '').toString();
    final r = j['reasons'];
    final count = j['report_count'];
    return ReportedPost(
      id: (j['id'] ?? '').toString(),
      body: (j['body'] ?? '').toString(),
      authorName: (j['author_name'] ?? '').toString(),
      date: created.length >= 10 ? created.substring(0, 10) : '',
      reportCount: count is num ? count.toInt() : 0,
      reasons: r is List ? r.map((e) => e.toString()).toList() : const [],
    );
  }
}
