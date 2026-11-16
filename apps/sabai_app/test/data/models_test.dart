import 'package:flutter_test/flutter_test.dart';
import 'package:sabai_app/src/data/models/models.dart';

void main() {
  test('Listing maps catalogue rows; unknown categories fall back to attraction', () {
    final l = Listing.fromJson({
      'id': 'u1',
      'title': 'ทัวร์',
      'category': 'TOUR',
      'partner_name': 'พาร์ทเนอร์',
      'from_price': '1490.00',
      'next_available_date': '2030-01-10',
    });
    expect(l.type, ListingType.attraction);
    expect(l.price, 1490);
    expect(l.isAvailable, isTrue);
    expect(Listing.fromJson({'id': 'u2', 'title': 'x', 'category': 'HOTEL'}).type, ListingType.hotel);
    expect(Listing.fromJson({'id': 'u3', 'title': 'x'}).isAvailable, isFalse);
  });

  test('Booking maps server statuses', () {
    Booking b(String s) => Booking.fromJson({
          'id': 'b',
          'booking_code': 'SB-1',
          'status': s,
          'payable_total': '500.00',
          'created_at': '2030-01-02T10:00:00Z',
        });
    expect(b('PENDING_PAYMENT').status, BookingStatus.pending);
    expect(b('PAID').status, BookingStatus.confirmed);
    expect(b('EXPIRED').status, BookingStatus.cancelled);
    expect(b('REFUNDED').status, BookingStatus.refunded);
    expect(b('WHATEVER').status, BookingStatus.unknown);
    expect(b('CONFIRMED').canRequestRefund, isTrue);
    expect(b('PENDING_PAYMENT').canRequestRefund, isFalse);
    expect(b('CONFIRMED').date, '2030-01-02');
    expect(b('CONFIRMED').title, 'SB-1');
  });

  test('WalletTransaction distinguishes credit and debit', () {
    final credit = WalletTransaction.fromJson({'id': 't', 'type': 'REFUND_CREDIT', 'credit_amount': '100.00', 'debit_amount': '0.00'});
    expect(credit.isCredit, isTrue);
    expect(credit.amount, 100);
    final debit = WalletTransaction.fromJson({'id': 't', 'type': 'X', 'credit_amount': '0.00', 'debit_amount': '30.00'});
    expect(debit.isCredit, isFalse);
    expect(debit.amount, 30);
  });
}
