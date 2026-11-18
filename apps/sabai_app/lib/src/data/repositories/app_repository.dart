import '../models/community_models.dart';
import '../models/engagement_models.dart';
import '../models/models.dart';
import '../models/trip_models.dart';

/// The only way the UI talks to data sources (same contract as apps/web-prototype/src/repositories/contract.js).
/// Implementations: [MockRepository] (offline demo) and [HttpRepository] (beta/production REST).
abstract class AppRepository {
  /// True when checkout talks to the real backend. The mock repository only simulates it locally.
  bool get isRealCheckout;

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

  // ---- Coupons (backend: /coupons). Saving only: the app never applies a coupon to a price. ----

  /// Saves a code to the caller's list. Errors: NOT_FOUND (unknown), CONFLICT (already saved/expired/not started/used up).
  Future<void> claimCoupon(String code);

  Future<List<SavedCoupon>> myCoupons();

  // ---- Tags (backend: /content/{type}/{id}/tags) ----

  /// Replaces the tag set of one item the caller owns; returns the stored labels.
  Future<List<String>> setTags({required String contentType, required String contentId, required List<String> tags});
}
