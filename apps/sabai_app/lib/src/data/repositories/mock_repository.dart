import '../../core/errors/api_error.dart';
import '../models/admin_models.dart';
import '../models/community_models.dart';
import '../models/engagement_models.dart';
import '../models/models.dart';
import '../models/staff_models.dart';
import '../models/trip_models.dart';
import 'app_repository.dart';

/// Offline demo data. Checkout is a local simulation only: no money, no server.
class MockRepository implements AppRepository {
  MockRepository();

  final List<Booking> _bookings = [];
  num _balance = 0;
  final List<WalletTransaction> _ledger = [];
  bool _signedIn = false;
  int _seq = 0;

  static const List<Listing> _catalog = [
    Listing(
        id: 'mock-hotel-1',
        title: 'ล้านนา วิว รีสอร์ท',
        type: ListingType.hotel,
        location: 'นิมมานเหมินท์, เชียงใหม่',
        price: 1490,
        serviceDate: '2030-01-10'),
    Listing(
        id: 'mock-attr-1',
        title: 'วัดพระธาตุดอยสุเทพ',
        type: ListingType.attraction,
        location: 'ดอยสุเทพ, เชียงใหม่',
        price: 50,
        serviceDate: '2030-01-10'),
    Listing(
        id: 'mock-hotel-2',
        title: 'อันดามัน บีช วิลลา',
        type: ListingType.hotel,
        location: 'ป่าตอง, ภูเก็ต',
        price: 2350,
        serviceDate: ''),
    Listing(
        id: 'mock-flight-1',
        title: 'สายการบินตัวอย่าง A XA 214 BKK→CNX ออก 07:00 (เที่ยวบินจำลอง)',
        type: ListingType.flight,
        location: 'ตัวอย่างทัวร์แอนด์เทรเวล',
        price: 2210,
        serviceDate: '2030-01-10'),
    Listing(
        id: 'mock-flight-2',
        title: 'สายการบินตัวอย่าง C XC 581 BKK→HKT ออก 18:15 (เที่ยวบินจำลอง)',
        type: ListingType.flight,
        location: 'ตัวอย่างทัวร์แอนด์เทรเวล',
        price: 1980,
        serviceDate: '2030-01-11'),
  ];

  @override
  bool get isRealCheckout => false;

  @override
  bool get canSimulatePayment => true;

  @override
  Future<List<Listing>> listings() async => _catalog;

  @override
  Future<Session> login(
      {required String email, required String password}) async {
    if (!email.contains('@') || password.length < 8) {
      throw const ApiError(code: 'UNAUTHORIZED', message: 'invalid credentials');
    }
    _signedIn = true;
    _email = email.trim().toLowerCase();
    _welcome();
    return Session(
        accessToken: 'mock-token', userId: 'mock-user', email: email, displayName: 'ผู้ใช้ทดลอง');
  }

  @override
  Future<Session> register(
      {required String email,
      required String password,
      required String displayName}) async {
    if (!email.contains('@') || password.length < 8 || displayName.trim().isEmpty) {
      throw const ApiError(code: 'VALIDATION_ERROR', message: 'invalid input');
    }
    _signedIn = true;
    _email = email.trim().toLowerCase();
    _welcome();
    return Session(
        accessToken: 'mock-token', userId: 'mock-user', email: email, displayName: displayName);
  }

  @override
  void logout() {
    _signedIn = false;
    _email = '';
    _trips.clear();
    _notifications.clear();
    _reviews.clear();
    _bookings.clear();
    _ledger.clear();
    _balance = 0;
  }

  void _requireSignIn() {
    if (!_signedIn) {
      throw const ApiError(code: 'UNAUTHORIZED', message: 'sign in required', status: 401);
    }
  }

  @override
  Future<List<Booking>> bookings() async {
    _requireSignIn();
    return List.unmodifiable(_bookings);
  }

  @override
  Future<Wallet> wallet() async {
    _requireSignIn();
    return Wallet(balance: _balance, transactions: List.unmodifiable(_ledger));
  }

  @override
  Future<CheckoutResult> pay({
    required String inventoryItemId,
    required String serviceDate,
    int quantity = 1,
    String method = 'PROMPTPAY_QR',
    bool simulateFailure = false,
  }) async {
    _requireSignIn();
    final item = _catalog.firstWhere(
      (l) => l.id == inventoryItemId,
      orElse: () => throw const ApiError(code: 'NOT_FOUND', message: 'item'),
    );
    _seq += 1;
    final code = 'MOCK-${_seq.toString().padLeft(4, '0')}';
    if (simulateFailure) {
      // Like the real server: the booking exists but stays unpaid.
      _bookings.insert(
          0,
          Booking(
              id: 'mock-booking-$_seq',
              code: code,
              title: item.title,
              amount: item.price * quantity,
              status: BookingStatus.pending,
              serverStatus: 'PENDING_PAYMENT',
              date: serviceDate));
      return CheckoutResult(
          bookingId: 'mock-booking-$_seq',
          bookingCode: code,
          status: 'PENDING_PAYMENT',
          payableTotal: item.price * quantity,
          paymentStatus: 'FAILED');
    }
    _bookings.insert(
        0,
        Booking(
            id: 'mock-booking-$_seq',
            code: code,
            title: item.title,
            amount: item.price * quantity,
            status: BookingStatus.confirmed,
            serverStatus: 'CONFIRMED',
            date: serviceDate));
    return CheckoutResult(
        bookingId: 'mock-booking-$_seq',
        bookingCode: code,
        status: 'CONFIRMED',
        payableTotal: item.price * quantity,
        paymentStatus: 'SUCCEEDED');
  }

  @override
  Future<RefundResult> requestRefund(
      {required String bookingId, String method = 'ORIGINAL_METHOD'}) async {
    _requireSignIn();
    final i = _bookings.indexWhere((b) => b.id == bookingId);
    if (i < 0) throw const ApiError(code: 'NOT_FOUND', message: 'booking');
    final b = _bookings[i];
    _bookings[i] = Booking(
        id: b.id,
        code: b.code,
        title: b.title,
        amount: b.amount,
        status: BookingStatus.refunded,
        serverStatus: 'REFUNDED',
        date: b.date);
    return RefundResult(
        id: 'mock-refund-$bookingId',
        status: 'COMPLETED',
        calculatedAmount: b.amount,
        autoApproved: true);
  }

  // ---- Trips (in memory) ----
  final List<Trip> _trips = [];

  Trip _find(String id) => _trips.firstWhere(
        (t) => t.id == id,
        orElse: () => throw const ApiError(code: 'NOT_FOUND', message: 'trip', status: 404),
      );

  @override
  Future<List<Trip>> trips() async {
    _requireSignIn();
    return _trips.map((t) => Trip(id: t.id, name: t.name, startDate: t.startDate, endDate: t.endDate, status: t.status)).toList();
  }

  @override
  Future<Trip> trip(String id) async {
    _requireSignIn();
    return _find(id);
  }

  @override
  Future<Trip> createTrip({required String name, String startDate = '', String endDate = ''}) async {
    _requireSignIn();
    if (name.trim().isEmpty) throw const ApiError(code: 'VALIDATION_ERROR', message: 'trip name is required');
    if (startDate.isNotEmpty && endDate.isNotEmpty && endDate.compareTo(startDate) < 0) {
      throw const ApiError(code: 'VALIDATION_ERROR', message: 'end date must not be before start date');
    }
    _seq += 1;
    final t = Trip(id: 'mock-trip-$_seq', name: name.trim(), startDate: startDate, endDate: endDate);
    _trips.insert(0, t);
    return t;
  }

  @override
  Future<void> deleteTrip(String id) async {
    _requireSignIn();
    _trips.remove(_find(id));
  }

  @override
  Future<Activity> addActivity({
    required String tripId,
    required String title,
    required String date,
    String startTime = '',
    String endTime = '',
  }) async {
    _requireSignIn();
    final t = _find(tripId);
    if (title.trim().isEmpty) throw const ApiError(code: 'VALIDATION_ERROR', message: 'title is required');
    if (endTime.isNotEmpty && startTime.isEmpty) {
      throw const ApiError(code: 'VALIDATION_ERROR', message: 'start_time is required when end_time is set');
    }
    _seq += 1;
    final a = Activity(id: 'mock-act-$_seq', title: title.trim(), startTime: startTime, endTime: endTime);
    final days = [...t.days];
    final i = days.indexWhere((d) => d.date == date);
    if (i >= 0) {
      days[i] = TripDay(id: days[i].id, date: date, dayNumber: days[i].dayNumber, activities: [...days[i].activities, a]);
    } else {
      days.add(TripDay(id: 'mock-day-$_seq', date: date, dayNumber: 0, activities: [a]));
    }
    days.sort((x, y) => x.date.compareTo(y.date));
    final numbered = [
      for (var k = 0; k < days.length; k++)
        TripDay(id: days[k].id, date: days[k].date, dayNumber: k + 1, activities: days[k].activities),
    ];
    _trips[_trips.indexOf(t)] = Trip(
        id: t.id, name: t.name, startDate: t.startDate, endDate: t.endDate, status: t.status, days: numbered);
    return a;
  }

  @override
  Future<void> removeActivity({required String tripId, required String activityId}) async {
    _requireSignIn();
    final t = _find(tripId);
    final days = [
      for (final d in t.days)
        TripDay(id: d.id, date: d.date, dayNumber: d.dayNumber, activities: d.activities.where((a) => a.id != activityId).toList()),
    ];
    _trips[_trips.indexOf(t)] = Trip(
        id: t.id, name: t.name, startDate: t.startDate, endDate: t.endDate, status: t.status, days: days);
  }

  // ---- Notifications and reviews (in memory) ----
  final List<AppNotification> _notifications = [];
  final List<Review> _reviews = [];

  void _welcome() {
    if (_notifications.isNotEmpty) return;
    _notifications.add(const AppNotification(
        id: 'mock-n-1',
        type: 'system',
        title: 'ยินดีต้อนรับสู่ Sabai',
        body: 'นี่คือข้อมูลทดลองในโหมดออฟไลน์',
        read: false,
        date: '2030-01-01'));
  }

  @override
  Future<NotificationsPage> notifications() async {
    _requireSignIn();
    return NotificationsPage(
      items: List.unmodifiable(_notifications),
      unreadCount: _notifications.where((n) => !n.read).length,
    );
  }

  @override
  Future<void> markNotificationRead(String id) async {
    _requireSignIn();
    final i = _notifications.indexWhere((n) => n.id == id);
    if (i < 0) throw const ApiError(code: 'NOT_FOUND', message: 'notification', status: 404);
    _notifications[i] = _notifications[i].copyWith(read: true);
  }

  @override
  Future<void> markAllNotificationsRead() async {
    _requireSignIn();
    for (var i = 0; i < _notifications.length; i++) {
      _notifications[i] = _notifications[i].copyWith(read: true);
    }
  }

  @override
  Future<List<Review>> myReviews() async {
    _requireSignIn();
    return List.unmodifiable(_reviews);
  }

  @override
  Future<Review> createReview({
    required String subjectType,
    required String subjectId,
    required double rating,
    String body = '',
  }) async {
    _requireSignIn();
    if (rating < 1 || rating > 5 || (rating * 2) % 1 != 0) {
      throw const ApiError(code: 'VALIDATION_ERROR', message: 'rating must be between 1 and 5 in steps of 0.5');
    }
    if (_reviews.any((r) => r.subjectType == subjectType && r.subjectId == subjectId)) {
      throw const ApiError(code: 'CONFLICT', message: 'already reviewed', status: 409);
    }
    _seq += 1;
    final r = Review(
        id: 'mock-review-$_seq', subjectType: subjectType, subjectId: subjectId, rating: rating, body: body.trim(), date: '2030-01-01');
    _reviews.insert(0, r);
    return r;
  }

  @override
  Future<void> deleteReview(String id) async {
    _requireSignIn();
    final i = _reviews.indexWhere((r) => r.id == id);
    if (i < 0) throw const ApiError(code: 'NOT_FOUND', message: 'review', status: 404);
    _reviews.removeAt(i);
  }

  final List<CommunityPost> _posts = [
    const CommunityPost(
        id: 'mock-post-seed',
        body: 'แนะนำคาเฟ่ริมน้ำที่เชียงใหม่ บรรยากาศดีมาก (ตัวอย่างข้อมูลออฟไลน์)',
        authorName: 'สมาชิกตัวอย่าง',
        date: '2030-01-01',
        mine: false,
        tags: ['คาเฟ่']),
  ];
  final Set<String> _reportedPosts = {};
  final Set<String> _savedCoupons = {};

  @override
  Future<List<CommunityPost>> communityFeed() async {
    _requireSignIn();
    return List.unmodifiable(_posts.where((p) => !_reportedPosts.contains(p.id)));
  }

  @override
  Future<CommunityPost> createPost(String body) async {
    _requireSignIn();
    final text = body.trim();
    if (text.isEmpty || text.runes.length > 1000) {
      throw const ApiError(code: 'VALIDATION_ERROR', message: 'body must be 1-1000 characters');
    }
    _seq += 1;
    final p = CommunityPost(id: 'mock-post-$_seq', body: text, authorName: 'ฉัน', date: '2030-01-01', mine: true);
    _posts.insert(0, p);
    return p;
  }

  @override
  Future<void> deletePost(String id) async {
    _requireSignIn();
    final i = _posts.indexWhere((p) => p.id == id && p.mine);
    if (i < 0) throw const ApiError(code: 'NOT_FOUND', message: 'post', status: 404);
    _posts.removeAt(i);
  }

  @override
  Future<void> reportPost({required String id, required String reason, String detail = ''}) async {
    _requireSignIn();
    if (!communityReportReasons.contains(reason)) {
      throw const ApiError(code: 'VALIDATION_ERROR', message: 'unknown reason');
    }
    final i = _posts.indexWhere((p) => p.id == id);
    if (i < 0) throw const ApiError(code: 'NOT_FOUND', message: 'post', status: 404);
    if (_posts[i].mine) throw const ApiError(code: 'VALIDATION_ERROR', message: 'cannot report your own post');
    _reportedPosts.add(id);
  }

  static const Map<String, SavedCoupon> _couponCatalog = {
    'SABAI10': SavedCoupon(
        code: 'SABAI10',
        title: 'ส่วนลดตัวอย่าง',
        discountType: 'PERCENT',
        value: '10.00',
        validFrom: '2030-01-01',
        validUntil: '2030-12-31',
        state: 'ACTIVE'),
    'OLD10': SavedCoupon(
        code: 'OLD10',
        title: 'คูปองหมดอายุ',
        discountType: 'FIXED',
        value: '100.00',
        validFrom: '2020-01-01',
        validUntil: '2020-12-31',
        state: 'EXPIRED'),
  };

  @override
  Future<void> claimCoupon(String code) async {
    _requireSignIn();
    final key = code.trim().toUpperCase();
    if (key.isEmpty || key.length > 40) throw const ApiError(code: 'VALIDATION_ERROR', message: 'invalid code');
    final c = _couponCatalog[key];
    if (c == null) throw const ApiError(code: 'NOT_FOUND', message: 'coupon', status: 404);
    if (!c.isActive) throw const ApiError(code: 'CONFLICT', message: 'coupon is not claimable', status: 409);
    if (!_savedCoupons.add(key)) throw const ApiError(code: 'CONFLICT', message: 'already saved', status: 409);
  }

  @override
  Future<List<SavedCoupon>> myCoupons() async {
    _requireSignIn();
    return _savedCoupons.map((k) => _couponCatalog[k]!).toList();
  }

  String _email = '';
  final List<ReportedPost> _queue = [
    const ReportedPost(
        id: 'mock-report-1',
        body: 'โปรโมชันสุดคุ้ม ทักไลน์ด่วน (ตัวอย่างข้อมูลออฟไลน์)',
        authorName: 'สมาชิกตัวอย่าง',
        date: '2030-01-01',
        reportCount: 2,
        reasons: ['ABUSE', 'SPAM']),
    const ReportedPost(
        id: 'mock-report-2',
        body: 'ร้านนี้ราคาแพงเกินจริงทุกอย่าง (ตัวอย่างข้อมูลออฟไลน์)',
        authorName: 'สมาชิกตัวอย่าง',
        date: '2030-01-02',
        reportCount: 1,
        reasons: ['MISLEADING']),
  ];

  /// In the offline mock, an address starting with "staff@" simulates a Staff member (moderation and all work queues), "officer@" a Booking Officer (bookings and disputes), "admin@" a System Admin and "auditor@" an Auditor.
  @override
  Future<AccountInfo> accountInfo() async {
    _requireSignIn();
    return _account();
  }

  AccountInfo _account() {
    if (_email.startsWith('staff@')) {
      return const AccountInfo(roles: ['STAFF'], permissions: ['portal.read', 'support.manage', 'booking.manage', 'partner.review']);
    }
    if (_email.startsWith('officer@')) {
      return const AccountInfo(roles: ['BOOKING_OFFICER'], permissions: ['portal.read', 'booking.manage', 'support.manage']);
    }
    if (_email.startsWith('admin@')) {
      return const AccountInfo(roles: ['ADMIN'], permissions: ['user.manage', 'config.manage', 'role.request', 'role.approve']);
    }
    if (_email.startsWith('auditor@')) return const AccountInfo(roles: ['AUDITOR'], permissions: ['audit.read', 'portal.read']);
    return const AccountInfo(roles: ['CUSTOMER']);
  }

  @override
  Future<List<ReportedPost>> reportedPosts() async {
    _requireSignIn();
    if (!_email.startsWith('staff@')) throw const ApiError(code: 'FORBIDDEN', message: 'forbidden', status: 403);
    return List.unmodifiable(_queue);
  }

  @override
  Future<void> moderatePost({required String id, required String action, String note = ''}) async {
    _requireSignIn();
    if (!_email.startsWith('staff@')) throw const ApiError(code: 'FORBIDDEN', message: 'forbidden', status: 403);
    if (action != 'remove' && action != 'dismiss') {
      throw const ApiError(code: 'VALIDATION_ERROR', message: 'unknown moderation action');
    }
    final i = _queue.indexWhere((p) => p.id == id);
    if (i < 0) throw const ApiError(code: 'NOT_FOUND', message: 'post', status: 404);
    _queue.removeAt(i);
  }

  // ---- Staff work queues (offline fixtures; same transition rules as the backend) ----

  static const _bookingTransitions = <String, List<String>>{'PENDING': ['CONFIRMED', 'CANCELLED'], 'CONFIRMED': ['CANCELLED']};
  static const _disputeTransitions = <String, List<String>>{'OPEN': ['IN_REVIEW'], 'IN_REVIEW': ['RESOLVED', 'REJECTED']};
  static const _partnerTransitions = <String, List<String>>{'PENDING': ['APPROVED', 'REJECTED'], 'APPROVED': ['SUSPENDED'], 'SUSPENDED': ['APPROVED']};

  QueueBooking _qb(String id, String code, String status, String total, String email) => QueueBooking(
      id: id, code: code, status: status, currency: 'THB', total: total, customerEmail: email, createdAt: '2030-01-08T09:00:00Z', nextStatuses: _bookingTransitions[status] ?? const []);

  QueueDispute _qd(String id, String bookingId, String code, String reason, String description, String status, String by) => QueueDispute(
      id: id, bookingId: bookingId, bookingCode: code, reason: reason, description: description, status: status, openedBy: by, createdAt: '2030-01-09T09:00:00Z', nextStatuses: _disputeTransitions[status] ?? const []);

  QueuePartner _qp(String id, String name, String status, String owner) => QueuePartner(
      id: id, legalName: name, status: status, ownerEmail: owner, createdAt: '2030-01-07T09:00:00Z', nextStatuses: _partnerTransitions[status] ?? const []);

  late final List<QueueBooking> _queueBookings = [
    _qb('mock-qb-1', 'SB-1001', 'PENDING', '3200.00', 'somchai@example.com'),
    _qb('mock-qb-2', 'SB-1002', 'CONFIRMED', '1800.00', 'mali@example.com'),
    _qb('mock-qb-3', 'SB-1003', 'PAID', '5400.00', 'somchai@example.com'),
  ];
  late final List<QueueDispute> _queueDisputes = [
    _qd('mock-qd-1', 'mock-qb-2', 'SB-1002', 'NO_SHOW', 'ลูกค้าแจ้งว่าไม่มีผู้รับที่จุดนัดพบ', 'OPEN', 'staff@example.com'),
  ];
  late final List<QueuePartner> _queuePartners = [
    _qp('mock-qp-1', 'ร้านอาหารริมทะเล', 'PENDING', 'owner1@example.com'),
    _qp('mock-qp-2', 'ทัวร์เกาะสวย', 'APPROVED', 'owner2@example.com'),
  ];

  void _requirePerm(String permission) {
    _requireSignIn();
    if (!_account().permissions.contains(permission)) throw const ApiError(code: 'FORBIDDEN', message: 'forbidden', status: 403);
  }

  StaffPage<T> _page<T>(List<T> all, int offset, int limit) {
    final end = offset + limit > all.length ? all.length : offset + limit;
    return StaffPage(items: offset >= all.length ? <T>[] : all.sublist(offset, end), total: all.length);
  }

  @override
  Future<StaffPage<QueueBooking>> staffBookings({String status = '', String query = '', int offset = 0, int limit = 20}) async {
    _requirePerm('booking.manage');
    final q = query.trim().toLowerCase();
    return _page(_queueBookings.where((b) => (status.isEmpty || b.status == status) && (q.isEmpty || b.code.toLowerCase().contains(q))).toList(), offset, limit);
  }

  @override
  Future<StaffPage<QueueDispute>> staffDisputes({String status = '', int offset = 0, int limit = 20}) async {
    _requirePerm('support.manage');
    return _page(_queueDisputes.where((d) => status.isEmpty || d.status == status).toList(), offset, limit);
  }

  @override
  Future<StaffPage<QueuePartner>> staffPartners({String status = '', int offset = 0, int limit = 20}) async {
    _requirePerm('partner.review');
    return _page(_queuePartners.where((p) => status.isEmpty || p.status == status).toList(), offset, limit);
  }

  /// Applies the same rule as the server: the target must be allowed from the current status, otherwise CONFLICT.
  String _nextStatus(Map<String, List<String>> rules, String from, String to) {
    if (!rules.values.any((targets) => targets.contains(to))) throw const ApiError(code: 'VALIDATION_ERROR', message: 'invalid status');
    if (!(rules[from] ?? const <String>[]).contains(to)) throw const ApiError(code: 'CONFLICT', message: 'status change is not allowed from the current status', status: 409);
    return to;
  }

  @override
  Future<void> changeBookingStatus({required String id, required String to, String note = ''}) async {
    _requirePerm('booking.manage');
    final i = _queueBookings.indexWhere((b) => b.id == id);
    if (i < 0) throw const ApiError(code: 'NOT_FOUND', message: 'booking', status: 404);
    final b = _queueBookings[i];
    _queueBookings[i] = _qb(b.id, b.code, _nextStatus(_bookingTransitions, b.status, to), b.total, b.customerEmail);
  }

  @override
  Future<void> changeDisputeStatus({required String id, required String to, String note = ''}) async {
    _requirePerm('support.manage');
    final i = _queueDisputes.indexWhere((d) => d.id == id);
    if (i < 0) throw const ApiError(code: 'NOT_FOUND', message: 'dispute', status: 404);
    final d = _queueDisputes[i];
    _queueDisputes[i] = _qd(d.id, d.bookingId, d.bookingCode, d.reason, d.description, _nextStatus(_disputeTransitions, d.status, to), d.openedBy);
  }

  @override
  Future<void> changePartnerStatus({required String id, required String to, String note = ''}) async {
    _requirePerm('partner.review');
    final i = _queuePartners.indexWhere((p) => p.id == id);
    if (i < 0) throw const ApiError(code: 'NOT_FOUND', message: 'partner', status: 404);
    final p = _queuePartners[i];
    _queuePartners[i] = _qp(p.id, p.legalName, _nextStatus(_partnerTransitions, p.status, to), p.ownerEmail);
  }

  @override
  Future<void> openDispute({required String bookingId, required String reason, String description = ''}) async {
    _requirePerm('support.manage');
    if (reason.trim().isEmpty || reason.trim().length > 100) {
      throw const ApiError(code: 'VALIDATION_ERROR', message: 'reason is required (max 100 characters)');
    }
    final b = _queueBookings.where((x) => x.id == bookingId).toList();
    if (b.isEmpty) throw const ApiError(code: 'NOT_FOUND', message: 'booking', status: 404);
    _queueDisputes.insert(0, _qd('mock-qd-${_queueDisputes.length + 1}', b.first.id, b.first.code, reason.trim(), description.trim(), 'OPEN', _email));
  }

  // ---- Admin console (offline fixtures; the real rules live in the backend) ----

  final List<AdminUser> _adminUsers = [
    const AdminUser(id: 'mock-admin', email: 'admin@example.com', status: 'ACTIVE', roles: ['ADMIN', 'CUSTOMER'], createdAt: '2030-01-01T00:00:00Z', lastLoginAt: '2030-01-09T08:00:00Z'),
    const AdminUser(id: 'mock-user-1', email: 'somchai@example.com', status: 'ACTIVE', roles: ['CUSTOMER'], createdAt: '2030-01-02T00:00:00Z', lastLoginAt: '2030-01-08T10:30:00Z', displayName: 'สมชาย ใจดี'),
    const AdminUser(id: 'mock-user-2', email: 'mali@example.com', status: 'ACTIVE', roles: ['CUSTOMER', 'PARTNER'], createdAt: '2030-01-03T00:00:00Z', displayName: 'มาลี รักเที่ยว', pendingRoles: ['PARTNER_FINANCE']),
    const AdminUser(id: 'mock-user-3', email: 'banned@example.com', status: 'SUSPENDED', roles: ['CUSTOMER'], createdAt: '2030-01-04T00:00:00Z'),
  ];

  final List<AuditEntry> _auditLog = [
    const AuditEntry(
        id: 'mock-audit-1',
        createdAt: '2030-01-05T09:00:00Z',
        actorEmail: 'admin@example.com',
        action: 'user.status.changed',
        subjectType: 'user',
        subjectId: 'mock-user-3',
        before: {'status': 'ACTIVE'},
        after: {'status': 'SUSPENDED', 'reason': 'โพสต์สแปมซ้ำ'}),
  ];

  void _requireAdmin() {
    _requireSignIn();
    if (!_email.startsWith('admin@')) throw const ApiError(code: 'FORBIDDEN', message: 'forbidden', status: 403);
  }

  @override
  Future<DashboardStats> adminDashboard() async {
    _requireSignIn();
    if (!(_email.startsWith('admin@') || _email.startsWith('auditor@') || _email.startsWith('staff@'))) {
      throw const ApiError(code: 'FORBIDDEN', message: 'forbidden', status: 403);
    }
    return DashboardStats(
      usersTotal: _adminUsers.length,
      usersActive: _adminUsers.where((u) => !u.suspended).length,
      usersSuspended: _adminUsers.where((u) => u.suspended).length,
      usersNew7: 2,
      bookingsByStatus: const {'CONFIRMED': 3, 'PENDING': 1},
      bookingsNew7: 2,
      paymentsByStatus: const {'SUCCEEDED': 3},
      queues: {'community_reports_open': _queue.length, 'tickets_open': 0, 'disputes_open': 0, 'refunds_open': 0, 'partners_pending': 0, 'role_requests_pending': 1},
    );
  }

  @override
  Future<AdminUsersPage> adminUsers({String query = '', String status = '', int offset = 0, int limit = 20}) async {
    _requireAdmin();
    final q = query.trim().toLowerCase();
    final all = _adminUsers.where((u) => (q.isEmpty || u.email.toLowerCase().contains(q)) && (status.isEmpty || u.status == status)).toList();
    final end = offset + limit > all.length ? all.length : offset + limit;
    return AdminUsersPage(items: offset >= all.length ? const [] : all.sublist(offset, end), total: all.length);
  }

  @override
  Future<AdminUser> adminUser(String id) async {
    _requireAdmin();
    final i = _adminUsers.indexWhere((u) => u.id == id);
    if (i < 0) throw const ApiError(code: 'NOT_FOUND', message: 'user', status: 404);
    return _adminUsers[i];
  }

  @override
  Future<void> setUserStatus({required String id, required String status, String reason = ''}) async {
    _requireAdmin();
    if (status != 'ACTIVE' && status != 'SUSPENDED') throw const ApiError(code: 'VALIDATION_ERROR', message: 'unknown status');
    if (status == 'SUSPENDED' && reason.trim().length < 3) {
      throw const ApiError(code: 'VALIDATION_ERROR', message: 'a reason is required to suspend an account');
    }
    final i = _adminUsers.indexWhere((u) => u.id == id);
    if (i < 0) throw const ApiError(code: 'NOT_FOUND', message: 'user', status: 404);
    final user = _adminUsers[i];
    if (user.email == _email) throw const ApiError(code: 'FORBIDDEN', message: 'you cannot change your own account status', status: 403);
    if (user.status == status) return; // same as the server: repeating a status writes and audits nothing
    _adminUsers[i] = user.copyWith(status: status);
    _auditLog.insert(
        0,
        AuditEntry(
            id: 'mock-audit-${_auditLog.length + 1}',
            createdAt: '2030-01-10T00:00:00Z',
            actorEmail: _email,
            action: 'user.status.changed',
            subjectType: 'user',
            subjectId: id,
            before: {'status': user.status},
            after: {'status': status, if (reason.trim().isNotEmpty) 'reason': reason.trim()}));
  }

  final List<FeatureFlag> _flags = [
    const FeatureFlag(key: 'community.posting', enabled: true, description: 'อนุญาตให้ผู้ใช้โพสต์ใหม่ในชุมชน'),
    const FeatureFlag(key: 'coupons.claiming', enabled: true, description: 'อนุญาตให้ผู้ใช้เก็บคูปองด้วยโค้ด'),
  ];

  void _requireConfig() {
    _requireSignIn();
    if (!_account().canManageConfig) throw const ApiError(code: 'FORBIDDEN', message: 'forbidden', status: 403);
  }

  @override
  Future<List<FeatureFlag>> featureFlags() async {
    _requireConfig();
    return List.of(_flags);
  }

  @override
  Future<void> setFeatureFlag({required String key, required bool enabled, String reason = ''}) async {
    _requireConfig();
    if (!enabled && reason.trim().isEmpty) {
      throw const ApiError(code: 'VALIDATION_ERROR', message: 'reason is required when turning a feature off');
    }
    final i = _flags.indexWhere((f) => f.key == key);
    if (i < 0) throw const ApiError(code: 'NOT_FOUND', message: 'feature flag', status: 404);
    if (_flags[i].enabled == enabled) return; // same as the server: no change, no audit row
    _flags[i] = FeatureFlag(key: key, enabled: enabled, description: _flags[i].description, updatedBy: _email);
    _auditLog.insert(
        0,
        AuditEntry(
            id: 'mock-audit-${_auditLog.length + 1}',
            createdAt: '2030-01-10T00:00:00Z',
            actorEmail: _email,
            action: 'feature_flag.changed',
            subjectType: 'feature_flag',
            subjectId: key,
            before: {'key': key, 'enabled': !enabled},
            after: {'key': key, 'enabled': enabled, if (reason.trim().isNotEmpty) 'reason': reason.trim()}));
  }

  @override
  Future<AuditPage> auditLogs({String action = '', int offset = 0, int limit = 20}) async {
    _requireSignIn();
    if (!_email.startsWith('auditor@')) throw const ApiError(code: 'FORBIDDEN', message: 'forbidden', status: 403);
    final all = _auditLog.where((e) => action.trim().isEmpty || e.action == action.trim()).toList();
    final end = offset + limit > all.length ? all.length : offset + limit;
    return AuditPage(items: offset >= all.length ? const [] : all.sublist(offset, end), total: all.length);
  }

  @override
  Future<List<String>> setTags({required String contentType, required String contentId, required List<String> tags}) async {
    _requireSignIn();
    if (contentType != 'REVIEW' && contentType != 'COMMUNITY_POST') {
      throw const ApiError(code: 'VALIDATION_ERROR', message: 'unsupported content type');
    }
    final reviewIndex = contentType == 'REVIEW' ? _reviews.indexWhere((r) => r.id == contentId) : -1;
    final postIndex = contentType == 'COMMUNITY_POST' ? _posts.indexWhere((p) => p.id == contentId && p.mine) : -1;
    if (reviewIndex < 0 && postIndex < 0) throw const ApiError(code: 'NOT_FOUND', message: 'content', status: 404);
    if (tags.length > 10) throw const ApiError(code: 'VALIDATION_ERROR', message: 'at most 10 tags per item');
    final seen = <String>{};
    final clean = <String>[];
    for (final raw in tags) {
      final label = raw.trim().split(RegExp(r'\s+')).join(' ');
      if (label.isEmpty || label.length > 30) throw const ApiError(code: 'VALIDATION_ERROR', message: 'invalid tag');
      if (seen.add(label.toLowerCase())) clean.add(label);
    }
    if (reviewIndex >= 0) _reviews[reviewIndex] = _reviews[reviewIndex].withTags(clean);
    if (postIndex >= 0) _posts[postIndex] = _posts[postIndex].withTags(clean);
    return clean;
  }
}
