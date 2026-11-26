import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import '../../core/errors/api_error.dart';
import '../../core/util/format.dart';
import '../models/admin_models.dart';
import '../models/community_models.dart';
import '../models/engagement_models.dart';
import '../models/models.dart';
import '../models/staff_models.dart';
import '../models/support_models.dart';
import '../models/trip_models.dart';
import 'app_repository.dart';

/// REST repository for beta and production (endpoints in backend/docs/openapi.yaml).
/// Response envelope: `{data, request_id}` or `{error: {code, message}, request_id}`.
/// The access token is kept in memory only. Authorization is enforced by the server.
class HttpRepository implements AppRepository {
  HttpRepository({
    required http.Client client,
    required String baseUrl,
    required this.mode,
    this.timeout = const Duration(seconds: 10),
    this.pollTries = 8,
    this.pollDelay = const Duration(seconds: 1),
    this.onUnauthorized,
    Random? random,
  })  : _client = client,
        _baseUrl = baseUrl,
        _random = random ?? Random.secure();

  final http.Client _client;
  final String _baseUrl;
  final ApiMode mode;
  final Duration timeout;
  final int pollTries;
  final Duration pollDelay;
  final void Function()? onUnauthorized;
  final Random _random;

  String _token = '';
  final Map<String, String> _refundKeys = {};
  final Map<String, String> _attemptKeys = {};

  @override
  bool get isRealCheckout => true;

  @override
  bool get canSimulatePayment => mode != ApiMode.production;

  String _newId() {
    String hex(int n) =>
        List.generate(n, (_) => _random.nextInt(16).toRadixString(16)).join();
    return '${hex(8)}-${hex(4)}-${hex(4)}-${hex(4)}-${hex(12)}';
  }

  Future<dynamic> _request(
    String path, {
    String method = 'GET',
    Object? body,
    bool auth = false,
    Map<String, String> headers = const {},
  }) async {
    final requestId = _newId();
    final h = <String, String>{
      'Accept': 'application/json',
      'X-Request-ID': requestId,
      ...headers,
    };
    if (body != null) h['Content-Type'] = 'application/json';
    if (auth && _token.isNotEmpty) h['Authorization'] = 'Bearer $_token';

    http.Response res;
    try {
      final req = http.Request(method, Uri.parse('$_baseUrl$path'))
        ..headers.addAll(h);
      if (body != null) req.body = jsonEncode(body);
      final streamed = await _client.send(req).timeout(timeout);
      res = await http.Response.fromStream(streamed);
    } on TimeoutException {
      throw ApiError(code: 'TIMEOUT', message: 'request timed out', requestId: requestId);
    } catch (_) {
      throw ApiError(code: 'NETWORK_ERROR', message: 'request failed', requestId: requestId);
    }

    final ok = res.statusCode >= 200 && res.statusCode < 300;
    if (ok && res.statusCode == 204) return null;

    Map<String, dynamic>? payload;
    try {
      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      if (decoded is Map<String, dynamic>) payload = decoded;
    } catch (_) {
      payload = null;
    }
    final rid = (payload?['request_id'] ?? requestId).toString();

    if (!ok) {
      final err = payload?['error'];
      if (res.statusCode == 401 && auth) onUnauthorized?.call();
      final errMap = err is Map<String, dynamic> ? err : const <String, dynamic>{};
      throw ApiError(
        code: (errMap['code'] ?? (res.statusCode >= 500 ? 'INTERNAL_ERROR' : 'HTTP_ERROR')).toString(),
        message: (errMap['message'] ?? 'HTTP ${res.statusCode}').toString(),
        status: res.statusCode,
        requestId: rid,
      );
    }
    if (payload == null || !payload.containsKey('data')) {
      throw ApiError(code: 'BAD_RESPONSE', message: 'response is missing data', status: res.statusCode, requestId: rid);
    }
    return payload['data'];
  }

  /// Bookings and the ledger return a bare array; notifications and reviews return `{items: [...]}`.
  List<Map<String, dynamic>> _rows(dynamic data, String path) {
    final raw = data is List
        ? data
        : (data is Map<String, dynamic> && data['items'] is List ? data['items'] as List<dynamic> : null);
    if (raw == null) {
      throw ApiError(code: 'BAD_RESPONSE', message: '$path must return a list');
    }
    return raw.whereType<Map<String, dynamic>>().toList();
  }

  Session _toSession(dynamic data) {
    if (data is! Map<String, dynamic> ||
        data['access_token'] is! String ||
        (data['access_token'] as String).isEmpty) {
      throw const ApiError(code: 'BAD_RESPONSE', message: 'response is missing access_token');
    }
    _token = data['access_token'] as String;
    final u = data['user'];
    final user = u is Map<String, dynamic> ? u : const <String, dynamic>{};
    return Session(
      accessToken: _token,
      userId: (user['id'] ?? '').toString(),
      email: (user['email'] ?? '').toString(),
      displayName: (user['display_name'] ?? '').toString(),
    );
  }

  @override
  Future<List<Listing>> listings() async {
    final data = await _request('/catalog/items?limit=100');
    return _rows(data, '/catalog/items').map(Listing.fromJson).toList();
  }

  @override
  Future<Session> login({required String email, required String password}) async =>
      _toSession(await _request('/auth/login', method: 'POST', body: {'email': email, 'password': password}));

  @override
  Future<Session> register({
    required String email,
    required String password,
    required String displayName,
  }) async =>
      _toSession(await _request('/auth/register',
          method: 'POST', body: {'email': email, 'password': password, 'display_name': displayName}));

  @override
  void logout() {
    _token = '';
  }

  @override
  Future<List<Booking>> bookings() async {
    final data = await _request('/bookings', auth: true);
    return _rows(data, '/bookings').map(Booking.fromJson).toList();
  }

  @override
  Future<Wallet> wallet() async {
    final results = await Future.wait<dynamic>([
      _request('/wallet', auth: true),
      _request('/wallet/transactions', auth: true),
    ]);
    final w = results[0];
    if (w is! Map<String, dynamic> || w['available_balance'] is! String) {
      throw const ApiError(code: 'BAD_RESPONSE', message: 'wallet payload is invalid');
    }
    return Wallet(
      balance: parseAmount(w['available_balance']),
      transactions: _rows(results[1], '/wallet/transactions').map(WalletTransaction.fromJson).toList(),
    );
  }

  @override
  Future<CheckoutResult> pay({
    required String inventoryItemId,
    required String serviceDate,
    int quantity = 1,
    String method = 'PROMPTPAY_QR',
    bool simulateFailure = false,
  }) async {
    if (simulateFailure && mode == ApiMode.production) {
      throw const ApiError(code: 'VALIDATION_ERROR', message: 'payment simulation is not available in production');
    }
    // One Idempotency-Key per (item, date, quantity) attempt, so a retry after a timeout cannot create a second booking.
    final attempt = '$inventoryItemId|$serviceDate|$quantity';
    final key = _attemptKeys.putIfAbsent(attempt, _newId);

    final b = await _request('/bookings',
        method: 'POST',
        auth: true,
        headers: {'Idempotency-Key': 'app-bk-$key'},
        body: {
          'items': [
            {'inventory_item_id': inventoryItemId, 'service_date': serviceDate, 'quantity': quantity}
          ]
        });
    if (b is! Map<String, dynamic> || b['id'] is! String) {
      throw const ApiError(code: 'BAD_RESPONSE', message: 'booking payload is invalid');
    }
    final bookingId = b['id'] as String;

    final intent = await _request('/payments/intents',
        method: 'POST',
        auth: true,
        headers: {'Idempotency-Key': 'app-pi-$key'},
        body: {'booking_id': bookingId, 'method': method});
    if (intent is! Map<String, dynamic> || intent['payment_reference'] is! String) {
      throw const ApiError(code: 'BAD_RESPONSE', message: 'payment payload is invalid');
    }

    if (mode != ApiMode.production) {
      // Development simulator: absent (404) when the server runs a real provider.
      try {
        await _request('/dev/payments/simulate',
            method: 'POST',
            auth: true,
            body: {
              'payment_reference': intent['payment_reference'],
              if (simulateFailure) 'outcome': 'FAILED',
            });
      } on ApiError catch (e) {
        if (e.code != 'NOT_FOUND') rethrow;
      }
    }

    Map<String, dynamic> detail = const {};
    for (var i = 0; i < pollTries; i++) {
      final d = await _request('/bookings/$bookingId', auth: true);
      if (d is! Map<String, dynamic>) {
        throw const ApiError(code: 'BAD_RESPONSE', message: 'booking detail is invalid');
      }
      detail = d;
      if (d['status'] != 'PENDING_PAYMENT' || d['payment_status'] == 'FAILED') break;
      if (i < pollTries - 1) await Future<void>.delayed(pollDelay);
    }
    _attemptKeys.remove(attempt);
    return CheckoutResult(
      bookingId: bookingId,
      bookingCode: (detail['booking_code'] ?? '').toString(),
      status: (detail['status'] ?? '').toString(),
      payableTotal: parseAmount(detail['payable_total']),
      qrPayload: (intent['qr_payload'] ?? '').toString(),
      paymentStatus: (detail['payment_status'] ?? '').toString(),
    );
  }

  @override
  Future<RefundResult> requestRefund({
    required String bookingId,
    String method = 'ORIGINAL_METHOD',
  }) async {
    final key = _refundKeys.putIfAbsent(bookingId, () => 'app-refund-$bookingId-${_newId()}');
    final r = await _request('/refunds',
        method: 'POST',
        auth: true,
        headers: {'Idempotency-Key': key},
        body: {'booking_id': bookingId, 'method': method});
    if (r is! Map<String, dynamic> || r['id'] is! String) {
      throw const ApiError(code: 'BAD_RESPONSE', message: 'refund payload is invalid');
    }
    return RefundResult(
      id: r['id'] as String,
      status: (r['status'] ?? '').toString(),
      calculatedAmount: parseAmount(r['calculated_amount']),
      autoApproved: r['auto_approved'] == true,
    );
  }

  String _tripPath(String id) => '/trips/${Uri.encodeComponent(id)}';

  Trip _toTrip(dynamic data) {
    if (data is! Map<String, dynamic> || data['id'] is! String || (data['name'] ?? '') is! String) {
      throw const ApiError(code: 'BAD_RESPONSE', message: 'trip payload is invalid');
    }
    return Trip.fromJson(data);
  }

  @override
  Future<List<Trip>> trips() async {
    final data = await _request('/trips', auth: true);
    return _rows(data, '/trips').map(Trip.fromJson).toList();
  }

  @override
  Future<Trip> trip(String id) async => _toTrip(await _request(_tripPath(id), auth: true));

  @override
  Future<Trip> createTrip({required String name, String startDate = '', String endDate = ''}) async =>
      _toTrip(await _request('/trips',
          method: 'POST',
          auth: true,
          body: {'name': name, 'destination_id': '', 'start_date': startDate, 'end_date': endDate}));

  @override
  Future<void> deleteTrip(String id) async {
    await _request(_tripPath(id), method: 'DELETE', auth: true);
  }

  @override
  Future<Activity> addActivity({
    required String tripId,
    required String title,
    required String date,
    String startTime = '',
    String endTime = '',
  }) async {
    final a = await _request('${_tripPath(tripId)}/activities',
        method: 'POST',
        auth: true,
        body: {'title': title, 'date': date, 'start_time': startTime, 'end_time': endTime, 'destination_id': ''});
    if (a is! Map<String, dynamic> || a['id'] is! String) {
      throw const ApiError(code: 'BAD_RESPONSE', message: 'activity payload is invalid');
    }
    return Activity.fromJson(a);
  }

  @override
  Future<void> removeActivity({required String tripId, required String activityId}) async {
    await _request('${_tripPath(tripId)}/activities/${Uri.encodeComponent(activityId)}', method: 'DELETE', auth: true);
  }

  @override
  Future<NotificationsPage> notifications() async {
    final data = await _request('/notifications?limit=100', auth: true);
    if (data is! Map<String, dynamic> || data['items'] is! List) {
      throw const ApiError(code: 'BAD_RESPONSE', message: '/notifications must return {items}');
    }
    final u = data['unread_count'];
    return NotificationsPage(
      items: _rows(data, '/notifications').map(AppNotification.fromJson).toList(),
      unreadCount: u is int ? u : 0,
    );
  }

  @override
  Future<void> markNotificationRead(String id) async {
    await _request('/notifications/${Uri.encodeComponent(id)}/read', method: 'PATCH', auth: true);
  }

  @override
  Future<void> markAllNotificationsRead() async {
    await _request('/notifications/read-all', method: 'POST', auth: true);
  }

  @override
  Future<List<Review>> myReviews() async {
    final data = await _request('/reviews/mine?limit=50', auth: true);
    final reviews = _rows(data, '/reviews/mine').map(Review.fromJson).toList();
    // One request per review (at most 50): the tags API is per item. A failure to read tags must not hide the review.
    return Future.wait(reviews.map((r) async {
      try {
        final t = await _request('/content/REVIEW/${Uri.encodeComponent(r.id)}/tags', auth: true);
        return r.withTags(_rows(t, 'tags').map((x) => (x['label'] ?? x['slug'] ?? '').toString()).where((x) => x.isNotEmpty).toList());
      } on ApiError {
        return r;
      }
    }));
  }

  @override
  Future<Review> createReview({
    required String subjectType,
    required String subjectId,
    required double rating,
    String body = '',
  }) async {
    final r = await _request('/reviews',
        method: 'POST',
        auth: true,
        body: {'subject_type': subjectType, 'subject_id': subjectId, 'rating': rating, 'body': body});
    if (r is! Map<String, dynamic> || r['id'] is! String) {
      throw const ApiError(code: 'BAD_RESPONSE', message: 'review payload is invalid');
    }
    return Review.fromJson(r);
  }

  @override
  Future<void> deleteReview(String id) async {
    await _request('/reviews/${Uri.encodeComponent(id)}', method: 'DELETE', auth: true);
  }

  @override
  Future<List<CommunityPost>> communityFeed() async {
    final data = await _request('/community/posts?limit=50', auth: true);
    return _rows(data, '/community/posts').map(CommunityPost.fromJson).toList();
  }

  @override
  Future<CommunityPost> createPost(String body) async {
    final r = await _request('/community/posts', method: 'POST', auth: true, body: {'body': body});
    if (r is! Map<String, dynamic> || r['id'] is! String) {
      throw const ApiError(code: 'BAD_RESPONSE', message: 'post payload is invalid');
    }
    return CommunityPost.fromJson(r);
  }

  @override
  Future<void> deletePost(String id) async {
    await _request('/community/posts/${Uri.encodeComponent(id)}', method: 'DELETE', auth: true);
  }

  @override
  Future<void> reportPost({required String id, required String reason, String detail = ''}) async {
    await _request('/community/posts/${Uri.encodeComponent(id)}/report',
        method: 'POST', auth: true, body: {'reason': reason, 'detail': detail});
  }

  @override
  Future<void> claimCoupon(String code) async {
    await _request('/coupons/claim', method: 'POST', auth: true, body: {'code': code});
  }

  @override
  Future<List<SavedCoupon>> myCoupons() async {
    final data = await _request('/coupons/mine?limit=50', auth: true);
    return _rows(data, '/coupons/mine').map(SavedCoupon.fromJson).toList();
  }

  @override
  Future<AccountInfo> accountInfo() async {
    final r = await _request('/me', auth: true);
    if (r is! Map<String, dynamic>) throw const ApiError(code: 'BAD_RESPONSE', message: 'account payload is invalid');
    return AccountInfo.fromJson(r);
  }

  @override
  Future<List<ReportedPost>> reportedPosts() async {
    final data = await _request('/portal/community/reports?limit=50', auth: true);
    return _rows(data, '/portal/community/reports').map(ReportedPost.fromJson).toList();
  }

  @override
  Future<void> moderatePost({required String id, required String action, String note = ''}) async {
    if (action != 'remove' && action != 'dismiss') {
      throw const ApiError(code: 'VALIDATION_ERROR', message: 'unknown moderation action');
    }
    await _request('/portal/community/posts/${Uri.encodeComponent(id)}/$action',
        method: 'POST', auth: true, body: {'note': note});
  }

  @override
  Future<DashboardStats> adminDashboard() async {
    final r = await _request('/admin/dashboard', auth: true);
    if (r is! Map<String, dynamic>) throw const ApiError(code: 'BAD_RESPONSE', message: 'dashboard payload is invalid');
    return DashboardStats.fromJson(r);
  }

  @override
  Future<AdminUsersPage> adminUsers({String query = '', String status = '', int offset = 0, int limit = 20}) async {
    final params = <String, String>{'limit': '$limit', 'offset': '$offset'};
    if (query.trim().isNotEmpty) params['q'] = query.trim();
    if (status.isNotEmpty) params['status'] = status;
    final data = await _request('/admin/users?${Uri(queryParameters: params).query}', auth: true);
    final rows = _rows(data, '/admin/users').map(AdminUser.fromJson).toList();
    final total = data is Map<String, dynamic> && data['total'] is num ? (data['total'] as num).toInt() : rows.length;
    return AdminUsersPage(items: rows, total: total);
  }

  @override
  Future<AdminUser> adminUser(String id) async {
    final r = await _request('/admin/users/${Uri.encodeComponent(id)}', auth: true);
    if (r is! Map<String, dynamic>) throw const ApiError(code: 'BAD_RESPONSE', message: 'user payload is invalid');
    return AdminUser.fromJson(r);
  }

  @override
  Future<void> setUserStatus({required String id, required String status, String reason = ''}) async {
    if (status != 'ACTIVE' && status != 'SUSPENDED') {
      throw const ApiError(code: 'VALIDATION_ERROR', message: 'unknown status');
    }
    await _request('/admin/users/${Uri.encodeComponent(id)}/status',
        method: 'PATCH', auth: true, body: {'status': status, 'reason': reason});
  }

  @override
  Future<TicketsPage> myTickets({int offset = 0, int limit = 20}) async {
    final data = await _request('/support/tickets?limit=$limit&offset=$offset', auth: true);
    final rows = _rows(data, '/support/tickets').map(SupportTicket.fromJson).toList();
    final total = data is Map<String, dynamic> && data['total'] is num ? (data['total'] as num).toInt() : rows.length;
    return TicketsPage(items: rows, total: total);
  }

  @override
  Future<SupportTicketDetail> myTicket(String id) async {
    final r = await _request('/support/tickets/${Uri.encodeComponent(id)}', auth: true);
    if (r is! Map<String, dynamic>) throw const ApiError(code: 'BAD_RESPONSE', message: 'ticket payload is invalid');
    return SupportTicketDetail.fromJson(r);
  }

  @override
  Future<String> createTicket({required String subject, required String category, required String description}) async {
    final r = await _request('/support/tickets',
        method: 'POST', auth: true, body: {'subject': subject, 'category': category, 'description': description});
    if (r is! Map<String, dynamic> || (r['id'] ?? '').toString().isEmpty) {
      throw const ApiError(code: 'BAD_RESPONSE', message: 'ticket payload is invalid');
    }
    return r['id'].toString();
  }

  @override
  Future<void> replyToMyTicket({required String id, required String body}) async {
    await _request('/support/tickets/${Uri.encodeComponent(id)}/messages', method: 'POST', auth: true, body: {'body': body});
  }

  @override
  Future<void> closeMyTicket(String id) async {
    await _request('/support/tickets/${Uri.encodeComponent(id)}/close', method: 'POST', auth: true);
  }

  @override
  Future<List<FeatureFlag>> featureFlags() async {
    final data = await _request('/admin/feature-flags', auth: true);
    return _rows(data, '/admin/feature-flags').map(FeatureFlag.fromJson).toList();
  }

  @override
  Future<void> setFeatureFlag({required String key, required bool enabled, String reason = ''}) async {
    await _request('/admin/feature-flags/${Uri.encodeComponent(key)}',
        method: 'PATCH', auth: true, body: {'enabled': enabled, if (reason.trim().isNotEmpty) 'reason': reason.trim()});
  }

  @override
  Future<AuditPage> auditLogs({String action = '', int offset = 0, int limit = 20}) async {
    final params = <String, String>{'limit': '$limit', 'offset': '$offset'};
    if (action.trim().isNotEmpty) params['action'] = action.trim();
    final data = await _request('/admin/audit-logs?${Uri(queryParameters: params).query}', auth: true);
    final rows = _rows(data, '/admin/audit-logs').map(AuditEntry.fromJson).toList();
    final total = data is Map<String, dynamic> && data['total'] is num ? (data['total'] as num).toInt() : rows.length;
    return AuditPage(items: rows, total: total);
  }

  Future<StaffPage<T>> _staffPage<T>(String path, Map<String, String> params, T Function(Map<String, dynamic>) parse) async {
    final data = await _request('$path?${Uri(queryParameters: params).query}', auth: true);
    final rows = _rows(data, path).map(parse).toList();
    final total = data is Map<String, dynamic> && data['total'] is num ? (data['total'] as num).toInt() : rows.length;
    return StaffPage(items: rows, total: total);
  }

  @override
  Future<StaffPage<QueueBooking>> staffBookings({String status = '', String query = '', int offset = 0, int limit = 20}) {
    final params = <String, String>{'limit': '$limit', 'offset': '$offset'};
    if (status.isNotEmpty) params['status'] = status;
    if (query.trim().isNotEmpty) params['q'] = query.trim();
    return _staffPage('/portal/bookings', params, QueueBooking.fromJson);
  }

  @override
  Future<StaffPage<QueueDispute>> staffDisputes({String status = '', int offset = 0, int limit = 20}) {
    final params = <String, String>{'limit': '$limit', 'offset': '$offset'};
    if (status.isNotEmpty) params['status'] = status;
    return _staffPage('/portal/disputes', params, QueueDispute.fromJson);
  }

  @override
  Future<StaffPage<QueuePartner>> staffPartners({String status = '', int offset = 0, int limit = 20}) {
    final params = <String, String>{'limit': '$limit', 'offset': '$offset'};
    if (status.isNotEmpty) params['status'] = status;
    return _staffPage('/portal/partners', params, QueuePartner.fromJson);
  }

  @override
  Future<void> changeBookingStatus({required String id, required String to, String note = ''}) async {
    await _request('/portal/bookings/${Uri.encodeComponent(id)}/status', method: 'PATCH', auth: true, body: {'status': to, 'note': note});
  }

  @override
  Future<void> changeDisputeStatus({required String id, required String to, String note = ''}) async {
    await _request('/portal/disputes/${Uri.encodeComponent(id)}/status', method: 'PATCH', auth: true, body: {'status': to, 'note': note});
  }

  @override
  Future<void> changePartnerStatus({required String id, required String to, String note = ''}) async {
    await _request('/portal/partners/${Uri.encodeComponent(id)}/approval', method: 'PATCH', auth: true, body: {'status': to, 'note': note});
  }

  @override
  Future<void> openDispute({required String bookingId, required String reason, String description = ''}) async {
    if (reason.trim().isEmpty || reason.trim().length > 100) {
      throw const ApiError(code: 'VALIDATION_ERROR', message: 'reason is required (max 100 characters)');
    }
    await _request('/portal/disputes', method: 'POST', auth: true, body: {'booking_id': bookingId, 'reason': reason.trim(), 'description': description.trim()});
  }

  @override
  Future<List<String>> setTags({required String contentType, required String contentId, required List<String> tags}) async {
    final t = await _request('/content/${Uri.encodeComponent(contentType)}/${Uri.encodeComponent(contentId)}/tags',
        method: 'PUT', auth: true, body: {'tags': tags});
    return _rows(t, 'tags').map((x) => (x['label'] ?? x['slug'] ?? '').toString()).where((x) => x.isNotEmpty).toList();
  }
}
