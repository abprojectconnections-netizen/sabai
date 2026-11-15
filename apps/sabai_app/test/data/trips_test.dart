import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sabai_app/src/core/config/app_config.dart';
import 'package:sabai_app/src/core/errors/api_error.dart';
import 'package:sabai_app/src/data/models/trip_models.dart';
import 'package:sabai_app/src/data/repositories/http_repository.dart';
import 'package:sabai_app/src/data/repositories/mock_repository.dart';
import 'package:sabai_app/src/state/trips_controller.dart';

http.Response json(int status, Object? body) => http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

const tripJson = {
  'id': 't1',
  'name': 'เชียงใหม่',
  'start_date': '2030-01-10',
  'end_date': '2030-01-12',
  'status': 'DRAFT',
  'days': [
    {
      'id': 'd1',
      'date': '2030-01-10',
      'day_number': 1,
      'activities': [
        {'id': 'a1', 'title': 'ดอยสุเทพ', 'starts_at': '2030-01-10T09:30:00.000000Z', 'ends_at': '2030-01-10T11:00:00.000000Z'},
        {'id': 'a2', 'title': 'ตลาดเช้า', 'starts_at': '', 'ends_at': ''},
      ]
    }
  ],
};

void main() {
  test('Trip.fromJson maps days and activity clock times', () {
    final t = Trip.fromJson(tripJson);
    expect(t.name, 'เชียงใหม่');
    expect(t.days.single.dayNumber, 1);
    expect(t.activityCount, 2);
    expect(t.days.single.activities[0].startTime, '09:30');
    expect(t.days.single.activities[0].endTime, '11:00');
    expect(t.days.single.activities[1].startTime, '');
    expect(Trip.fromJson({'id': 'x', 'name': 'y'}).days, isEmpty);
  });

  group('HttpRepository trips', () {
    HttpRepository repoFor(MockClient c) => HttpRepository(
        client: c, baseUrl: 'https://api.test', mode: ApiMode.beta, pollDelay: Duration.zero);

    test('list, detail, create, delete use the /trips endpoints with the right bodies', () async {
      final log = <String>[];
      final bodies = <String, Object?>{};
      final r = repoFor(MockClient((req) async {
        final key = '${req.method} ${req.url.path}';
        log.add(key);
        if (req.body.isNotEmpty) bodies[key] = jsonDecode(req.body);
        switch (key) {
          case 'GET /trips':
            return json(200, {'data': [tripJson]});
          case 'GET /trips/t1':
            return json(200, {'data': tripJson});
          case 'POST /trips':
            return json(201, {'data': tripJson});
          case 'DELETE /trips/t1':
            return http.Response('', 204);
        }
        return json(500, {'error': {'code': 'INTERNAL_ERROR', 'message': 'x'}});
      }));
      expect((await r.trips()).single.id, 't1');
      expect((await r.trip('t1')).activityCount, 2);
      await r.createTrip(name: 'เชียงใหม่', startDate: '2030-01-10', endDate: '2030-01-12');
      await r.deleteTrip('t1');
      expect(bodies['POST /trips'], {'name': 'เชียงใหม่', 'destination_id': '', 'start_date': '2030-01-10', 'end_date': '2030-01-12'});
      expect(log, ['GET /trips', 'GET /trips/t1', 'POST /trips', 'DELETE /trips/t1']);
    });

    test('activities: add sends HH:MM, remove hits the activity path', () async {
      final seen = <String>[];
      Object? body;
      final r = repoFor(MockClient((req) async {
        seen.add('${req.method} ${req.url.path}');
        if (req.method == 'POST') {
          body = jsonDecode(req.body);
          return json(201, {'data': {'id': 'a9', 'title': 'x', 'starts_at': '2030-01-10T09:30:00.000000Z'}});
        }
        return http.Response('', 204);
      }));
      final a = await r.addActivity(tripId: 't1', title: 'x', date: '2030-01-10', startTime: '09:30');
      await r.removeActivity(tripId: 't1', activityId: 'a9');
      expect(a.startTime, '09:30');
      expect(body, {'title': 'x', 'date': '2030-01-10', 'start_time': '09:30', 'end_time': '', 'destination_id': ''});
      expect(seen, ['POST /trips/t1/activities', 'DELETE /trips/t1/activities/a9']);
    });

    test('a trip id is URL-encoded and a bad payload is BAD_RESPONSE', () async {
      Uri? uri;
      final r = repoFor(MockClient((req) async {
        uri = req.url;
        return json(200, {'data': {'oops': true}});
      }));
      await expectLater(r.trip('a/b'), throwsA(isA<ApiError>().having((e) => e.code, 'code', 'BAD_RESPONSE')));
      expect(uri!.path, '/trips/a%2Fb');
    });

    test('server errors keep their code (404 for another user\'s trip)', () async {
      final r = repoFor(MockClient((req) async => json(404, {'error': {'code': 'NOT_FOUND', 'message': 'trip not found'}})));
      await expectLater(r.trip('x'), throwsA(isA<ApiError>().having((e) => e.code, 'code', 'NOT_FOUND')));
    });
  });

  group('MockRepository trips + TripsController', () {
    Future<(MockRepository, TripsController)> signedIn() async {
      final m = MockRepository();
      await m.login(email: 'a@b.c', password: 'password1');
      return (m, TripsController(m));
    }

    test('requires sign-in', () async {
      await expectLater(MockRepository().trips(), throwsA(isA<ApiError>().having((e) => e.status, 'status', 401)));
    });

    test('create, add activities across days (days renumber in date order), remove, delete', () async {
      final (_, c) = await signedIn();
      final t = await c.create('ภูเก็ต', startDate: '2030-02-01', endDate: '2030-02-03');
      expect(t, isNotNull);
      expect(c.trips.single.name, 'ภูเก็ต');

      expect(await c.addActivity(t!.id, title: 'หาดป่าตอง', date: '2030-02-02', startTime: '10:00'), isTrue);
      expect(await c.addActivity(t.id, title: 'ตลาด', date: '2030-02-01'), isTrue);
      var d = (await c.open(t.id))!;
      expect(d.days.map((x) => x.date), ['2030-02-01', '2030-02-02']);
      expect(d.days.map((x) => x.dayNumber), [1, 2]);

      final actId = d.days.first.activities.single.id;
      expect(await c.removeActivity(t.id, actId), isTrue);
      d = (await c.open(t.id))!;
      expect(d.activityCount, 1);

      expect(await c.delete(t.id), isTrue);
      expect(c.trips, isEmpty);
      expect(await c.open(t.id), isNull);
      expect(c.error, isNotNull);
    });

    test('validation errors surface as Thai messages and leave state unchanged', () async {
      final (_, c) = await signedIn();
      expect(await c.create('  '), isNull);
      expect(c.error, contains('ข้อมูลไม่ถูกต้อง'));
      expect(await c.create('x', startDate: '2030-02-03', endDate: '2030-02-01'), isNull);
      expect(c.trips, isEmpty);
      final t = (await c.create('ok'))!;
      expect(await c.addActivity(t.id, title: 'x', date: '2030-01-01', endTime: '10:00'), isFalse);
    });

    test('reset clears the list (sign-out) and notifies on a microtask', () async {
      final (_, c) = await signedIn();
      await c.create('a');
      var notified = 0;
      c.addListener(() => notified++);
      c.reset();
      expect(c.trips, isEmpty);
      expect(notified, 0); // never synchronously: it may run during a build
      await Future<void>.delayed(Duration.zero);
      expect(notified, 1);
    });
  });
}
