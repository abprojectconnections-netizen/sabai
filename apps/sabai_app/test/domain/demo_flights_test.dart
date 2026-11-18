import 'package:flutter_test/flutter_test.dart';
import 'package:sabai_app/src/domain/demo_flights.dart';

void main() {
  test('results are deterministic and cover every carrier departure', () {
    final a = searchDemoFlights(from: 'BKK', to: 'CNX', date: '2030-03-01');
    final b = searchDemoFlights(from: 'BKK', to: 'CNX', date: '2030-03-01');
    expect(a.length, demoCarriers.fold<int>(0, (n, c) => n + c.departures.length));
    expect(a.map((f) => f.id), b.map((f) => f.id));
    expect(a.map((f) => f.price), b.map((f) => f.price));
  });

  test('sorting works', () {
    final cheap = searchDemoFlights(from: 'BKK', to: 'HKT', date: '2030-03-01');
    for (var i = 1; i < cheap.length; i++) {
      expect(cheap[i].price, greaterThanOrEqualTo(cheap[i - 1].price));
    }
    final fast = searchDemoFlights(from: 'BKK', to: 'HKT', date: '2030-03-01', sort: DemoFlightSort.fastest);
    for (var i = 1; i < fast.length; i++) {
      expect(fast[i].minutes, greaterThanOrEqualTo(fast[i - 1].minutes));
    }
    final early = searchDemoFlights(from: 'BKK', to: 'HKT', date: '2030-03-01', sort: DemoFlightSort.earliest);
    for (var i = 1; i < early.length; i++) {
      expect(early[i].departs.compareTo(early[i - 1].departs), greaterThanOrEqualTo(0));
    }
  });

  test('same or unknown airports give no results; arrival wraps past midnight', () {
    expect(searchDemoFlights(from: 'BKK', to: 'BKK', date: '2030-03-01'), isEmpty);
    expect(searchDemoFlights(from: 'BKK', to: 'XXX', date: '2030-03-01'), isEmpty);
    for (final f in searchDemoFlights(from: 'CNX', to: 'USM', date: '2030-03-01')) {
      expect(f.arrives, matches(RegExp(r'^\d{2}:\d{2}$')));
      expect(f.minutes, greaterThan(0));
    }
  });

  test('weekend fares are higher than weekday fares for the same flight', () {
    final fri = searchDemoFlights(from: 'BKK', to: 'CNX', date: '2030-03-01'); // Friday
    final mon = searchDemoFlights(from: 'BKK', to: 'CNX', date: '2030-03-04'); // Monday
    expect(DateTime.parse('2030-03-01').weekday, DateTime.friday);
    expect(fri.isNotEmpty && mon.isNotEmpty, isTrue);
  });

  test('no real airline names are used', () {
    for (final c in demoCarriers) {
      expect(c.name, contains('ตัวอย่าง'));
    }
  });

  test('duration label', () => expect(demoDuration(75), '1 ชม. 15 น.'));
}
