import '../../core/errors/api_error.dart';
import '../models/models.dart';
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
  ];

  @override
  bool get isRealCheckout => false;

  @override
  Future<List<Listing>> listings() async => _catalog;

  @override
  Future<Session> login(
      {required String email, required String password}) async {
    if (!email.contains('@') || password.length < 8) {
      throw const ApiError(code: 'UNAUTHORIZED', message: 'invalid credentials');
    }
    _signedIn = true;
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
    return Session(
        accessToken: 'mock-token', userId: 'mock-user', email: email, displayName: displayName);
  }

  @override
  void logout() {
    _signedIn = false;
    _trips.clear();
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
  }) async {
    _requireSignIn();
    final item = _catalog.firstWhere(
      (l) => l.id == inventoryItemId,
      orElse: () => throw const ApiError(code: 'NOT_FOUND', message: 'item'),
    );
    _seq += 1;
    final code = 'MOCK-${_seq.toString().padLeft(4, '0')}';
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
        payableTotal: item.price * quantity);
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
}
