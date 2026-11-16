import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sabai_app/src/core/config/app_config.dart';
import 'package:sabai_app/src/core/errors/api_error.dart';
import 'package:sabai_app/src/data/repositories/http_repository.dart';

http.Response json(int status, Object body) => http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

HttpRepository repo(MockClient client, {ApiMode mode = ApiMode.beta}) => HttpRepository(
      client: client,
      baseUrl: 'https://api.test',
      mode: mode,
      pollTries: 3,
      pollDelay: Duration.zero,
    );

void main() {
  test('catalogue is public and parsed from the envelope', () async {
    final calls = <http.Request>[];
    final r = repo(MockClient((req) async {
      calls.add(req);
      return json(200, {
        'data': [
          {'id': 'i1', 'title': 'ทัวร์ดอยสุเทพ', 'category': 'TOUR', 'from_price': '1490.00', 'next_available_date': '2030-01-10'}
        ],
        'request_id': 'r'
      });
    }));
    final items = await r.listings();
    expect(items.single.title, 'ทัวร์ดอยสุเทพ');
    expect(calls.single.url.toString(), 'https://api.test/catalog/items?limit=100');
    expect(calls.single.headers.containsKey('Authorization'), isFalse);
    expect(calls.single.headers['X-Request-ID'], isNotEmpty);
  });

  test('login stores the token in memory and sends it on authenticated calls', () async {
    final seen = <String, String?>{};
    final r = repo(MockClient((req) async {
      seen[req.url.path] = req.headers['Authorization'];
      if (req.url.path == '/auth/login') {
        return json(200, {
          'data': {'access_token': 'tok', 'token_type': 'Bearer', 'user': {'id': 'u', 'email': 'a@b.c', 'display_name': 'A'}}
        });
      }
      return json(200, {'data': []});
    }));
    final s = await r.login(email: 'a@b.c', password: 'password1');
    expect(s.accessToken, 'tok');
    expect(s.displayName, 'A');
    await r.bookings();
    expect(seen['/bookings'], 'Bearer tok');
    r.logout();
    await r.bookings();
    expect(seen['/bookings'], isNull);
  });

  test('error envelope becomes ApiError with its code and request id', () async {
    final r = repo(MockClient((req) async => json(401, {
          'error': {'code': 'UNAUTHORIZED', 'message': 'bad'},
          'request_id': 'rid-1'
        })));
    await expectLater(
      r.login(email: 'a@b.c', password: 'x'),
      throwsA(isA<ApiError>().having((e) => e.code, 'code', 'UNAUTHORIZED').having((e) => e.requestId, 'requestId', 'rid-1')),
    );
  });

  test('network failure is reported as NETWORK_ERROR', () async {
    final r = repo(MockClient((req) async => throw http.ClientException('down')));
    await expectLater(r.listings(), throwsA(isA<ApiError>().having((e) => e.code, 'code', 'NETWORK_ERROR')));
  });

  test('bookings accepts a bare array and rejects other shapes', () async {
    final good = repo(MockClient((req) async => json(200, {'data': [{'id': 'b', 'booking_code': 'SB-1', 'status': 'PAID', 'payable_total': '10.00'}]})));
    expect((await good.bookings()).single.code, 'SB-1');
    final bad = repo(MockClient((req) async => json(200, {'data': 'nope'})));
    await expectLater(bad.bookings(), throwsA(isA<ApiError>().having((e) => e.code, 'code', 'BAD_RESPONSE')));
  });

  group('pay', () {
    MockClient payClient(List<String> log, {String finalStatus = 'CONFIRMED', bool simulator = true}) {
      var polls = 0;
      return MockClient((req) async {
        log.add('${req.method} ${req.url.path}');
        switch ('${req.method} ${req.url.path}') {
          case 'POST /bookings':
            expect(req.headers['Idempotency-Key'], startsWith('app-bk-'));
            expect(jsonDecode(req.body), {
              'items': [
                {'inventory_item_id': 'item-1', 'service_date': '2030-01-10', 'quantity': 1}
              ]
            });
            return json(201, {'data': {'id': 'bk-1'}});
          case 'POST /payments/intents':
            expect(req.headers['Idempotency-Key'], startsWith('app-pi-'));
            return json(201, {'data': {'payment_reference': 'pay-1', 'qr_payload': 'QR'}});
          case 'POST /dev/payments/simulate':
            return simulator
                ? json(200, {'data': {}})
                : json(404, {'error': {'code': 'NOT_FOUND', 'message': 'nf'}});
          case 'GET /bookings/bk-1':
            polls += 1;
            final status = polls < 2 ? 'PENDING_PAYMENT' : finalStatus;
            return json(200, {'data': {'id': 'bk-1', 'booking_code': 'SB-42', 'status': status, 'payable_total': '1490.00'}});
        }
        return json(500, {'error': {'code': 'INTERNAL_ERROR', 'message': 'unexpected'}});
      });
    }

    test('beta: creates booking, intent, simulates, then polls until the server confirms', () async {
      final log = <String>[];
      final res = await repo(payClient(log)).pay(inventoryItemId: 'item-1', serviceDate: '2030-01-10');
      expect(res.bookingCode, 'SB-42');
      expect(res.isPaid, isTrue);
      expect(res.payableTotal, 1490);
      expect(log, [
        'POST /bookings',
        'POST /payments/intents',
        'POST /dev/payments/simulate',
        'GET /bookings/bk-1',
        'GET /bookings/bk-1',
      ]);
    });

    test('a missing simulator (404) is tolerated', () async {
      final log = <String>[];
      final res = await repo(payClient(log, simulator: false)).pay(inventoryItemId: 'item-1', serviceDate: '2030-01-10');
      expect(res.isPaid, isTrue);
    });

    test('production never calls the simulator', () async {
      final log = <String>[];
      await repo(payClient(log), mode: ApiMode.production).pay(inventoryItemId: 'item-1', serviceDate: '2030-01-10');
      expect(log.contains('POST /dev/payments/simulate'), isFalse);
    });

    test('stays pending when the provider has not confirmed', () async {
      final log = <String>[];
      final res = await repo(payClient(log, finalStatus: 'PENDING_PAYMENT')).pay(inventoryItemId: 'item-1', serviceDate: '2030-01-10');
      expect(res.isPaid, isFalse);
      expect(res.qrPayload, 'QR');
    });
  });

  test('refund request reuses one Idempotency-Key per booking', () async {
    final keys = <String?>[];
    final r = repo(MockClient((req) async {
      keys.add(req.headers['Idempotency-Key']);
      return json(201, {'data': {'id': 'rf', 'status': 'APPROVED', 'calculated_amount': '1490.00', 'auto_approved': true}});
    }));
    final a = await r.requestRefund(bookingId: 'bk-1');
    await r.requestRefund(bookingId: 'bk-1');
    expect(a.calculatedAmount, 1490);
    expect(a.autoApproved, isTrue);
    expect(keys[0], keys[1]);
  });

  test('wallet needs a string balance', () async {
    final r = repo(MockClient((req) async => req.url.path == '/wallet'
        ? json(200, {'data': {'available_balance': '250.00'}})
        : json(200, {'data': [{'id': 't', 'type': 'REFUND_CREDIT', 'credit_amount': '250.00', 'debit_amount': '0.00'}]})));
    final w = await r.wallet();
    expect(w.balance, 250);
    expect(w.transactions.single.isCredit, isTrue);
  });
}
