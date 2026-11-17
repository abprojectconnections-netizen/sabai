import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sabai_app/src/core/config/app_config.dart';
import 'package:sabai_app/src/core/errors/api_error.dart';
import 'package:sabai_app/src/data/models/engagement_models.dart';
import 'package:sabai_app/src/data/repositories/http_repository.dart';
import 'package:sabai_app/src/data/repositories/mock_repository.dart';
import 'package:sabai_app/src/state/notifications_controller.dart';
import 'package:sabai_app/src/state/reviews_controller.dart';

http.Response json(int status, Object? body) => http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

HttpRepository repoFor(MockClient c) =>
    HttpRepository(client: c, baseUrl: 'https://api.test', mode: ApiMode.beta, pollDelay: Duration.zero);

void main() {
  test('models map server rows', () {
    final n = AppNotification.fromJson({'id': 'n', 'type': 'booking', 'title': 'จองแล้ว', 'body': 'x', 'read': false, 'created_at': '2030-01-02T10:00:00.000000Z'});
    expect(n.read, isFalse);
    expect(n.date, '2030-01-02');
    expect(n.copyWith(read: true).read, isTrue);
    final r = Review.fromJson({'id': 'r', 'subject_type': 'BOOKING', 'subject_id': 'b', 'rating': 4.5, 'body': 'ดี', 'created_at': '2030-01-02T10:00:00Z'});
    expect(r.rating, 4.5);
    expect(r.withTags(['ธรรมชาติ']).tags, ['ธรรมชาติ']);
    expect(Review.fromJson({'id': 'x', 'rating': 'bad'}).rating, 0);
  });

  test('parseTagInput splits on commas and keeps spaces inside a tag', () {
    expect(parseTagInput('ธรรมชาติ, คาเฟ่ ,  อาหาร ท้องถิ่น,,'), ['ธรรมชาติ', 'คาเฟ่', 'อาหาร ท้องถิ่น']);
    expect(parseTagInput('  '), isEmpty);
  });

  group('HttpRepository', () {
    test('notifications needs {items, unread_count}; mark read uses PATCH; read-all uses POST', () async {
      final seen = <String>[];
      final r = repoFor(MockClient((req) async {
        seen.add('${req.method} ${req.url.path}');
        if (req.method == 'GET') {
          return json(200, {'data': {'items': [{'id': 'n1', 'title': 't', 'body': '', 'read': false, 'created_at': '2030-01-02T00:00:00Z'}], 'unread_count': 3}});
        }
        return json(200, {'data': {}});
      }));
      final page = await r.notifications();
      expect(page.items.single.id, 'n1');
      expect(page.unreadCount, 3);
      await r.markNotificationRead('n1');
      await r.markAllNotificationsRead();
      expect(seen, ['GET /notifications', 'PATCH /notifications/n1/read', 'POST /notifications/read-all']);
      final bad = repoFor(MockClient((req) async => json(200, {'data': []})));
      await expectLater(bad.notifications(), throwsA(isA<ApiError>().having((e) => e.code, 'code', 'BAD_RESPONSE')));
    });

    test('myReviews attaches tags and survives a tag-read failure', () async {
      final r = repoFor(MockClient((req) async {
        if (req.url.path == '/reviews/mine') {
          return json(200, {'data': {'items': [
            {'id': 'r1', 'subject_type': 'BOOKING', 'subject_id': 'b1', 'rating': 5, 'body': '', 'created_at': '2030-01-02T00:00:00Z'},
            {'id': 'r2', 'subject_type': 'BOOKING', 'subject_id': 'b2', 'rating': 3, 'body': '', 'created_at': '2030-01-02T00:00:00Z'},
          ]}});
        }
        if (req.url.path == '/content/REVIEW/r1/tags') {
          return json(200, {'data': [{'slug': 'คาเฟ่', 'label': 'คาเฟ่'}]});
        }
        return json(500, {'error': {'code': 'INTERNAL_ERROR', 'message': 'x'}});
      }));
      final list = await r.myReviews();
      expect(list[0].tags, ['คาเฟ่']);
      expect(list[1].tags, isEmpty);
      expect(list.length, 2);
    });

    test('createReview, deleteReview and setTags send the documented requests', () async {
      final seen = <String>[];
      final bodies = <String, Object?>{};
      final r = repoFor(MockClient((req) async {
        final key = '${req.method} ${req.url.path}';
        seen.add(key);
        if (req.body.isNotEmpty) bodies[key] = jsonDecode(req.body);
        if (key == 'POST /reviews') return json(201, {'data': {'id': 'r9', 'subject_type': 'BOOKING', 'subject_id': 'b1', 'rating': 4.5, 'body': 'ดี', 'created_at': '2030-01-02T00:00:00Z'}});
        if (key == 'PUT /content/REVIEW/r9/tags') return json(200, {'data': [{'slug': 'a', 'label': 'A'}]});
        return http.Response('', 204);
      }));
      final created = await r.createReview(subjectType: 'BOOKING', subjectId: 'b1', rating: 4.5, body: 'ดี');
      expect(created.id, 'r9');
      expect(await r.setTags(contentType: 'REVIEW', contentId: 'r9', tags: ['A']), ['A']);
      await r.deleteReview('r9');
      expect(bodies['POST /reviews'], {'subject_type': 'BOOKING', 'subject_id': 'b1', 'rating': 4.5, 'body': 'ดี'});
      expect(bodies['PUT /content/REVIEW/r9/tags'], {'tags': ['A']});
      expect(seen, ['POST /reviews', 'PUT /content/REVIEW/r9/tags', 'DELETE /reviews/r9']);
    });
  });

  group('controllers on the mock repository', () {
    Future<MockRepository> signedIn() async {
      final m = MockRepository();
      await m.login(email: 'a@b.c', password: 'password1');
      return m;
    }

    test('notifications: unread count falls as items are read', () async {
      final c = NotificationsController(await signedIn());
      await c.ensureLoaded();
      expect(c.unreadCount, 1);
      await c.markRead(c.items.first);
      expect(c.unreadCount, 0);
      expect(c.items.first.read, isTrue);
      await c.markAllRead();
      expect(c.unreadCount, 0);
    });

    test('notifications: ensureLoaded loads once; reset clears for the next user', () async {
      final repo = await signedIn();
      final c = NotificationsController(repo);
      await c.ensureLoaded();
      await repo.markAllNotificationsRead();
      await c.ensureLoaded(); // no reload
      expect(c.unreadCount, 1);
      c.reset();
      expect(c.items, isEmpty);
      expect(c.loadedOnce, isFalse);
    });

    test('reviews: create with tags, duplicate is a friendly Thai error, delete', () async {
      final c = ReviewsController(await signedIn());
      expect(await c.reviewBooking('b1', 4.5, 'ดีมาก', ['ธรรมชาติ', 'ธรรมชาติ', 'คาเฟ่']), isTrue);
      expect(c.reviews.single.tags, ['ธรรมชาติ', 'คาเฟ่']);
      expect(c.hasReviewedBooking('b1'), isTrue);

      expect(await c.reviewBooking('b1', 3, '', []), isFalse);
      expect(c.error, 'คุณรีวิวรายการนี้ไปแล้ว');
      expect(c.reviews.length, 1);

      expect(await c.reviewBooking('b2', 0.5 - 1, '', []), isFalse);
      expect(c.error, contains('ข้อมูลไม่ถูกต้อง'));

      expect(await c.delete(c.reviews.single.id), isTrue);
      expect(c.reviews, isEmpty);
      expect(await c.delete('missing'), isFalse);
    });

    test('reviews: a failed tag step keeps the review and reports it', () async {
      final c = ReviewsController(await signedIn());
      final tooMany = List.generate(11, (i) => 't$i');
      expect(await c.reviewBooking('b1', 5, '', tooMany), isFalse);
      expect(c.reviews.length, 1); // the review itself was saved
      expect(c.error, startsWith('บันทึกรีวิวแล้ว แต่ตั้งแท็กไม่สำเร็จ'));
    });
  });
}
