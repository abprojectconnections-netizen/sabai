import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sabai_app/src/core/config/app_config.dart';
import 'package:sabai_app/src/core/errors/api_error.dart';
import 'package:sabai_app/src/data/models/community_models.dart';
import 'package:sabai_app/src/data/repositories/http_repository.dart';
import 'package:sabai_app/src/data/repositories/mock_repository.dart';
import 'package:sabai_app/src/state/community_controller.dart';
import 'package:sabai_app/src/state/coupons_controller.dart';

http.Response json(int status, Object? body) => http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

HttpRepository repoFor(MockClient c) =>
    HttpRepository(client: c, baseUrl: 'https://api.test', mode: ApiMode.beta, pollDelay: Duration.zero);

Future<MockRepository> signedInMock() async {
  final r = MockRepository();
  await r.login(email: 'a@example.com', password: 'password123');
  return r;
}

void main() {
  test('models map server rows', () {
    final p = CommunityPost.fromJson({
      'id': 'p1',
      'body': 'สวัสดี',
      'created_at': '2030-01-02T10:00:00Z',
      'author': {'display_name': 'สมชาย'},
      'mine': true,
      'tags': ['คาเฟ่', ''],
    });
    expect(p.authorName, 'สมชาย');
    expect(p.date, '2030-01-02');
    expect(p.mine, isTrue);
    expect(p.tags, ['คาเฟ่']);
    expect(CommunityPost.fromJson({'id': 'x'}).authorName, 'สมาชิก');

    final c = SavedCoupon.fromJson({
      'code': 'SABAI10', 'title': 'ต้อนรับ', 'discount_type': 'PERCENT', 'value': '10.00',
      'valid_from': '2030-01-01T00:00:00Z', 'valid_until': '2030-12-31T00:00:00Z', 'state': 'ACTIVE'
    });
    expect(c.valueLabel, 'ลด 10.00%');
    expect(c.isActive, isTrue);
    expect(c.validUntil, '2030-12-31');
    expect(SavedCoupon.fromJson({'code': 'Z', 'discount_type': '', 'value': ''}).valueLabel, '');
    expect(SavedCoupon.fromJson({'code': 'Z'}).state, 'UNAVAILABLE');
  });

  group('HttpRepository', () {
    test('feed, post, delete and report use the documented routes and bodies', () async {
      final seen = <String>[];
      final bodies = <Object?>[];
      final r = repoFor(MockClient((req) async {
        seen.add('${req.method} ${req.url.path}');
        if (req.body.isNotEmpty) bodies.add(jsonDecode(req.body));
        if (req.method == 'GET') {
          return json(200, {'data': {'items': [{'id': 'p1', 'body': 'x', 'created_at': '2030-01-02T00:00:00Z', 'author': {'display_name': 'ก'}, 'mine': false, 'tags': []}]}});
        }
        if (req.method == 'DELETE') return http.Response('', 204);
        if (req.url.path.endsWith('/report')) return json(200, {'data': {'reported': true}});
        return json(201, {'data': {'id': 'p2', 'body': 'hi', 'created_at': '2030-01-02T00:00:00Z', 'author': {'display_name': 'ฉัน'}, 'mine': true, 'tags': []}});
      }));
      expect((await r.communityFeed()).single.id, 'p1');
      expect((await r.createPost('hi')).mine, isTrue);
      await r.deletePost('p2');
      await r.reportPost(id: 'p1', reason: 'SPAM');
      expect(seen, [
        'GET /community/posts',
        'POST /community/posts',
        'DELETE /community/posts/p2',
        'POST /community/posts/p1/report',
      ]);
      expect(bodies, [
        {'body': 'hi'},
        {'reason': 'SPAM', 'detail': ''},
      ]);
    });

    test('coupons: claim sends only the code; mine is read as a list', () async {
      final bodies = <Object?>[];
      final r = repoFor(MockClient((req) async {
        if (req.method == 'POST') {
          bodies.add(jsonDecode(req.body));
          return json(201, {'data': {'saved': true}});
        }
        return json(200, {'data': {'items': [{'code': 'SABAI10', 'state': 'ACTIVE'}]}});
      }));
      await r.claimCoupon('SABAI10');
      expect(bodies.single, {'code': 'SABAI10'}); // never a price, never a booking
      expect((await r.myCoupons()).single.code, 'SABAI10');
    });

    test('a coupon conflict is reported as CONFLICT', () async {
      final r = repoFor(MockClient((_) async => json(409, {'error': {'code': 'CONFLICT', 'message': 'expired'}})));
      expect(() => r.claimCoupon('OLD10'), throwsA(isA<ApiError>().having((e) => e.code, 'code', 'CONFLICT')));
    });
  });

  group('CommunityController', () {
    test('post with tags, then delete; mock tags only the owner', () async {
      final c = CommunityController(await signedInMock());
      await c.load();
      expect(c.posts.length, 1); // seed post
      expect(await c.post('  ทดสอบ  ', ['ธรรมชาติ', 'ธรรมชาติ']), isTrue);
      expect(c.posts.first.body, 'ทดสอบ');
      expect(c.posts.first.tags, ['ธรรมชาติ']);
      expect(c.posts.first.mine, isTrue);
      expect(await c.delete(c.posts.first.id), isTrue);
      expect(c.posts.length, 1);
    });

    test('an empty post is refused; tag failure keeps the post and says so', () async {
      final c = CommunityController(await signedInMock());
      expect(await c.post('   ', const []), isFalse);
      expect(c.error, isNotNull);
      final many = List.generate(11, (i) => 't$i');
      expect(await c.post('มีแท็กเยอะ', many), isFalse);
      expect(c.lastPostPublished, isTrue);
      expect(c.posts.first.body, 'มีแท็กเยอะ');
      expect(c.error, contains('ตั้งแท็กไม่สำเร็จ'));
    });

    test('reporting hides the post; own posts cannot be reported or others deleted', () async {
      final repo = await signedInMock();
      final c = CommunityController(repo);
      await c.load();
      final other = c.posts.single.id;
      expect(await c.delete(other), isFalse); // not mine
      expect(await c.report(other, 'SPAM'), isTrue);
      expect(c.posts, isEmpty);
      await c.post('ของฉัน', const []);
      expect(await c.report(c.posts.first.id, 'SPAM'), isFalse);
    });

    test('reset clears the feed (sign-out)', () async {
      final c = CommunityController(await signedInMock());
      await c.load();
      c.reset();
      expect(c.posts, isEmpty);
      expect(c.loadedOnce, isFalse);
    });
  });

  group('CouponsController', () {
    test('claim saves a coupon and lists it with its state', () async {
      final c = CouponsController(await signedInMock());
      expect(await c.claim(' sabai10 '), isTrue);
      expect(c.coupons.single.code, 'SABAI10');
      expect(c.coupons.single.isActive, isTrue);
    });

    test('unknown, expired, duplicate and empty codes give clear messages', () async {
      final c = CouponsController(await signedInMock());
      expect(await c.claim('NOPE'), isFalse);
      expect(c.error, 'ไม่พบรหัสคูปองนี้');
      expect(await c.claim('OLD10'), isFalse);
      expect(c.error, contains('หมดอายุ'));
      expect(await c.claim('SABAI10'), isTrue);
      expect(await c.claim('SABAI10'), isFalse);
      expect(c.error, contains('บันทึกไปแล้ว'));
      expect(await c.claim(''), isFalse);
      expect(c.error, 'กรุณากรอกรหัสคูปอง');
      expect(c.coupons.length, 1);
    });
  });
}
