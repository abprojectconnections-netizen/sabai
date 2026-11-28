import '../models/admin_models.dart';
import '../models/community_models.dart';
import '../models/engagement_models.dart';
import '../models/models.dart';
import '../models/staff_models.dart';
import '../models/support_models.dart';
import '../models/trip_models.dart';

/// The only way the UI talks to data sources (same contract as apps/web-prototype/src/repositories/contract.js).
/// Implementations: [MockRepository] (offline demo) and [HttpRepository] (beta/production REST).
abstract class AppRepository {
  /// True when checkout talks to the real backend. The mock repository only simulates it locally.
  bool get isRealCheckout;

  /// True when this build may ask the sandbox provider to simulate a failed payment (never in production).
  bool get canSimulatePayment;

  /// Public catalogue (no sign-in needed).
  Future<List<Listing>> listings();

  Future<Session> login({required String email, required String password});

  Future<Session> register({
    required String email,
    required String password,
    required String displayName,
  });

  void logout();

  Future<List<Booking>> bookings();

  Future<Wallet> wallet();

  /// Create the booking, open a payment intent and wait for the SERVER to report the result.
  /// The client sends ids, a date, a quantity and a method only: price and totals come from the server.
  Future<CheckoutResult> pay({
    required String inventoryItemId,
    required String serviceDate,
    int quantity = 1,
    String method = 'PROMPTPAY_QR',
    bool simulateFailure = false,
  });

  /// A refund is a REQUEST: the server computes the amount from the booking's price snapshot and decides approval.
  Future<RefundResult> requestRefund({
    required String bookingId,
    String method = 'ORIGINAL_METHOD',
  });

  // ---- Trips (backend: /trips; every trip belongs to the signed-in user) ----

  Future<List<Trip>> trips();

  /// Trip with its days and activities.
  Future<Trip> trip(String id);

  /// Dates are optional ISO `YYYY-MM-DD`; a trip spans at most 60 days (the server enforces it).
  Future<Trip> createTrip({required String name, String startDate = '', String endDate = ''});

  Future<void> deleteTrip(String id);

  /// [startTime]/[endTime] are `HH:MM` or empty; an end time needs a start time.
  Future<Activity> addActivity({
    required String tripId,
    required String title,
    required String date,
    String startTime = '',
    String endTime = '',
  });

  Future<void> removeActivity({required String tripId, required String activityId});

  // ---- Notifications (backend: /notifications) ----

  Future<NotificationsPage> notifications();

  Future<void> markNotificationRead(String id);

  Future<void> markAllNotificationsRead();

  // ---- Reviews (backend: /reviews) ----

  /// The caller's reviews, each with its tags.
  Future<List<Review>> myReviews();

  /// One review per user per subject (a duplicate is CONFLICT). Rating 1..5 in steps of 0.5.
  Future<Review> createReview({
    required String subjectType,
    required String subjectId,
    required double rating,
    String body = '',
  });

  Future<void> deleteReview(String id);

  // ---- Community (backend: /community) ----

  /// Newest first. Posts the caller reported are already hidden by the server.
  Future<List<CommunityPost>> communityFeed();

  /// Shown to everyone at once (no pre-moderation); 1..1000 characters.
  Future<CommunityPost> createPost(String body);

  Future<void> deletePost(String id);

  /// [reason] is one of [communityReportReasons]. Reporting is idempotent.
  Future<void> reportPost({required String id, required String reason, String detail = ''});

  // ---- Account and staff moderation (backend: /me, /portal/community) ----

  Future<AccountInfo> accountInfo();

  /// STAFF (support.manage): live posts with open reports, most reported first. 403 for everyone else.
  Future<List<ReportedPost>> reportedPosts();

  /// [action] is `remove` (delete the post) or `dismiss` (keep it); both close the post's open reports.
  Future<void> moderatePost({required String id, required String action, String note = ''});

  // ---- Admin console (backend: /admin). Each call is checked by the server; the app only hides what you cannot use. ----

  /// user.manage, portal.read or audit.read.
  Future<DashboardStats> adminDashboard();

  /// user.manage. [query] is a literal e-mail substring; [status] is '' (all), ACTIVE or SUSPENDED.
  Future<AdminUsersPage> adminUsers({String query = '', String status = '', int offset = 0, int limit = 20});

  /// user.manage. Includes display name and pending role requests.
  Future<AdminUser> adminUser(String id);

  /// user.manage. [status] is ACTIVE or SUSPENDED; a reason is required to suspend. You cannot change your own account.
  Future<void> setUserStatus({required String id, required String status, String reason = ''});

  /// support.manage. Ticket queue: active tickets first, oldest first, closed last.
  Future<StaffPage<QueueTicket>> staffTickets({String status = '', int offset = 0, int limit = 20});

  /// support.manage. One ticket with its description and conversation.
  Future<StaffTicketDetail> staffTicket(String id);

  /// support.manage. Answers a customer; the first reply moves an OPEN ticket to IN_PROGRESS. A CLOSED ticket is a CONFLICT.
  Future<void> replyAsStaff({required String id, required String body});

  /// support.manage. Moves a ticket along the server's transition rules (see [QueueTicket.nextStatuses]).
  Future<void> changeTicketStatus({required String id, required String to, String note = ''});

  /// Signed in. Your own support tickets, newest first.
  Future<TicketsPage> myTickets({int offset = 0, int limit = 20});

  /// Signed in. One of your tickets with its conversation; someone else's is NOT_FOUND.
  Future<SupportTicketDetail> myTicket(String id);

  /// Signed in. Subject 3-120 characters, description 1-2000, category one of [supportCategoriesTh]. At most 5 tickets may be
  /// open at once (CONFLICT). Returns the new ticket's id.
  Future<String> createTicket({required String subject, required String category, required String description});

  /// Signed in. A CLOSED ticket is a CONFLICT; a reply to a RESOLVED one reopens it.
  Future<void> replyToMyTicket({required String id, required String body});

  Future<void> closeMyTicket(String id);

  /// config.manage. Every feature flag, by key.
  Future<List<FeatureFlag>> featureFlags();

  /// config.manage. A reason is required when turning a feature off; repeating the current value changes nothing.
  Future<void> setFeatureFlag({required String key, required bool enabled, String reason = ''});

  /// audit.read. Newest first. [action] filters on the exact action name (empty = all).
  Future<AuditPage> auditLogs({String action = '', int offset = 0, int limit = 20});

  // ---- Staff work queues (backend: /portal). The server lists the allowed next statuses with every row. ----

  /// booking.manage. [status] and [query] (booking code contains) are optional filters.
  Future<StaffPage<QueueBooking>> staffBookings({String status = '', String query = '', int offset = 0, int limit = 20});

  /// support.manage.
  Future<StaffPage<QueueDispute>> staffDisputes({String status = '', int offset = 0, int limit = 20});

  /// partner.review. Oldest first.
  Future<StaffPage<QueuePartner>> staffPartners({String status = '', int offset = 0, int limit = 20});

  /// booking.manage. [to] must be one of the row's nextStatuses (CONFLICT otherwise).
  Future<void> changeBookingStatus({required String id, required String to, String note = ''});

  /// support.manage.
  Future<void> changeDisputeStatus({required String id, required String to, String note = ''});

  /// partner.review.
  Future<void> changePartnerStatus({required String id, required String to, String note = ''});

  /// support.manage. Opens a dispute on a booking; [reason] is required (max 100 characters).
  Future<void> openDispute({required String bookingId, required String reason, String description = ''});

  // ---- Coupons (backend: /coupons). Saving only: the app never applies a coupon to a price. ----

  /// Saves a code to the caller's list. Errors: NOT_FOUND (unknown), CONFLICT (already saved/expired/not started/used up).
  Future<void> claimCoupon(String code);

  Future<List<SavedCoupon>> myCoupons();

  // ---- Tags (backend: /content/{type}/{id}/tags) ----

  /// Replaces the tag set of one item the caller owns; returns the stored labels.
  Future<List<String>> setTags({required String contentType, required String contentId, required List<String> tags});
}
