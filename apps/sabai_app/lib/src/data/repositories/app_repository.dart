import '../models/models.dart';

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
}
