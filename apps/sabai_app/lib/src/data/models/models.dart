import '../../core/util/format.dart';

/// Immutable view models mapped from API payloads (same mapping as apps/web-prototype/src/repositories/mappers.js).

class Session {
  const Session({
    required this.accessToken,
    this.userId = '',
    this.email = '',
    this.displayName = '',
  });

  final String accessToken;
  final String userId;
  final String email;
  final String displayName;
}

enum ListingType { hotel, flight, attraction }

class Listing {
  const Listing({
    required this.id,
    required this.title,
    required this.type,
    required this.location,
    required this.price,
    required this.serviceDate,
  });

  /// Inventory item UUID: a booking references it.
  final String id;
  final String title;
  final ListingType type;
  final String location;
  final num price;

  /// Next available service date (YYYY-MM-DD); empty when sold out.
  final String serviceDate;

  bool get isAvailable => serviceDate.isNotEmpty;

  factory Listing.fromJson(Map<String, dynamic> j) {
    const types = {
      'HOTEL': ListingType.hotel,
      'FLIGHT': ListingType.flight,
    };
    return Listing(
      id: (j['id'] ?? '').toString(),
      title: (j['title'] ?? '').toString(),
      type: types[j['category']] ?? ListingType.attraction,
      location: (j['partner_name'] ?? '').toString(),
      price: parseAmount(j['from_price']),
      serviceDate: (j['next_available_date'] ?? '').toString(),
    );
  }
}

enum BookingStatus { pending, confirmed, completed, cancelled, refunded, unknown }

class Booking {
  const Booking({
    required this.id,
    required this.code,
    required this.title,
    required this.amount,
    required this.status,
    required this.serverStatus,
    required this.date,
  });

  final String id;
  final String code;
  final String title;
  final num amount;
  final BookingStatus status;
  final String serverStatus;
  final String date;

  bool get canRequestRefund =>
      status == BookingStatus.confirmed || status == BookingStatus.completed;

  factory Booking.fromJson(Map<String, dynamic> j) {
    const map = {
      'PENDING_PAYMENT': BookingStatus.pending,
      'PAID': BookingStatus.confirmed,
      'CONFIRMED': BookingStatus.confirmed,
      'COMPLETED': BookingStatus.completed,
      'CANCELLED': BookingStatus.cancelled,
      'EXPIRED': BookingStatus.cancelled,
      'REFUNDED': BookingStatus.refunded,
    };
    final server = (j['status'] ?? '').toString();
    final code = (j['booking_code'] ?? '').toString();
    final created = (j['created_at'] ?? '').toString();
    final title = (j['title'] ?? '').toString();
    return Booking(
      id: (j['id'] ?? '').toString(),
      code: code,
      title: title.isEmpty ? code : title,
      amount: parseAmount(j['payable_total']),
      status: map[server] ?? BookingStatus.unknown,
      serverStatus: server,
      date: created.length >= 10 ? created.substring(0, 10) : '',
    );
  }
}

class WalletTransaction {
  const WalletTransaction({
    required this.id,
    required this.label,
    required this.amount,
    required this.isCredit,
    required this.date,
  });

  final String id;
  final String label;
  final num amount;
  final bool isCredit;
  final String date;

  factory WalletTransaction.fromJson(Map<String, dynamic> j) {
    final credit = parseAmount(j['credit_amount']);
    final type = (j['type'] ?? '').toString();
    final created = (j['created_at'] ?? '').toString();
    return WalletTransaction(
      id: (j['id'] ?? '').toString(),
      label: type == 'REFUND_CREDIT'
          ? 'เงินคืนเข้ากระเป๋า (เครดิตคืนเงิน)'
          : type,
      amount: credit > 0 ? credit : parseAmount(j['debit_amount']),
      isCredit: credit > 0,
      date: created.length >= 10 ? created.substring(0, 10) : '',
    );
  }
}

class Wallet {
  const Wallet({this.balance = 0, this.transactions = const []});
  final num balance;
  final List<WalletTransaction> transactions;
}

class CheckoutResult {
  const CheckoutResult({
    required this.bookingId,
    required this.bookingCode,
    required this.status,
    required this.payableTotal,
    this.qrPayload = '',
  });

  final String bookingId;
  final String bookingCode;
  final String status;
  final num payableTotal;
  final String qrPayload;

  bool get isPaid => status != 'PENDING_PAYMENT';
}

class RefundResult {
  const RefundResult({
    required this.id,
    required this.status,
    required this.calculatedAmount,
    required this.autoApproved,
  });

  final String id;
  final String status;
  final num calculatedAmount;
  final bool autoApproved;
}
