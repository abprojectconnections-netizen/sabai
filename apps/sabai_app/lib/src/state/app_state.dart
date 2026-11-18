import 'package:flutter/foundation.dart';

import '../core/errors/api_error.dart';
import '../data/models/models.dart';
import '../data/repositories/app_repository.dart';

/// App-wide state. Screens read it with `context.watch<AppState>()` and call its methods; they never touch the repository.
/// Every money figure shown here comes from the server.
class AppState extends ChangeNotifier {
  AppState(this.repository);

  final AppRepository repository;

  Session? session;
  List<Listing> listings = const [];
  List<Booking> bookings = const [];
  Wallet wallet = const Wallet();

  bool booting = true;
  bool busy = false;

  /// Thai message for the last failed action; cleared by [clearError].
  String? error;

  bool get signedIn => session != null;

  Future<void> boot() async {
    booting = true;
    notifyListeners();
    try {
      listings = await repository.listings();
    } catch (e) {
      error = describeApiErrorTh(e);
    }
    booting = false;
    notifyListeners();
  }

  void clearError() {
    if (error == null) return;
    error = null;
    notifyListeners();
  }

  /// Runs [action], toggling [busy] and turning any failure into [error]. Returns true on success.
  Future<bool> _run(Future<void> Function() action) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      await action();
      return true;
    } catch (e) {
      error = describeApiErrorTh(e);
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<bool> login(String email, String password) => _run(() async {
        session = await repository.login(email: email, password: password);
        await _refreshAccount();
      });

  Future<bool> register(String email, String password, String displayName) =>
      _run(() async {
        session = await repository.register(
            email: email, password: password, displayName: displayName);
        await _refreshAccount();
      });

  void logout() {
    repository.logout();
    session = null;
    bookings = const [];
    wallet = const Wallet();
    error = null;
    notifyListeners();
  }

  Future<void> _refreshAccount() async {
    final results = await Future.wait<Object>([repository.bookings(), repository.wallet()]);
    bookings = results[0] as List<Booking>;
    wallet = results[1] as Wallet;
  }

  Future<bool> refreshAccount() => _run(_refreshAccount);

  /// Pays for [listing]. On success [result] receives the server-reported outcome.
  Future<CheckoutResult?> pay(Listing listing, {bool simulateFailure = false}) async {
    CheckoutResult? result;
    await _run(() async {
      result = await repository.pay(
          inventoryItemId: listing.id, serviceDate: listing.serviceDate, simulateFailure: simulateFailure);
      await _refreshAccount();
    });
    return result;
  }

  Future<RefundResult?> requestRefund(Booking booking) async {
    RefundResult? result;
    await _run(() async {
      result = await repository.requestRefund(bookingId: booking.id);
      await _refreshAccount();
    });
    return result;
  }
}
