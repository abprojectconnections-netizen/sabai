import 'package:flutter_test/flutter_test.dart';
import 'package:sabai_app/src/data/models/models.dart';
import 'package:sabai_app/src/domain/flight_info.dart';

Listing l(String id, String title, num price, {ListingType type = ListingType.flight}) =>
    Listing(id: id, title: title, type: type, location: 'x', price: price, serviceDate: '2030-01-10');

void main() {
  final a = l('a', 'สายการบินตัวอย่าง A XA 214 BKK→CNX ออก 07:00 (เที่ยวบินจำลอง)', 2200);
  final b = l('b', 'สายการบินตัวอย่าง C XC 581 BKK→CNX ออก 18:15 (เที่ยวบินจำลอง)', 1500);
  final c = l('c', 'สายการบินตัวอย่าง B XB 300 CNX→BKK ออก 12:30 (เที่ยวบินจำลอง)', 1800);
  final odd = l('d', 'เที่ยวบินพิเศษ', 900);
  final hotel = l('h', 'โรงแรม BKK→CNX', 100, type: ListingType.hotel);
  final all = [a, b, c, odd, hotel];

  test('parses route and departure; non-flights and non-matching titles give null', () {
    final i = FlightInfo.tryParse(a)!;
    expect((i.from, i.to, i.departs), ('BKK', 'CNX', '07:00'));
    expect(FlightInfo.tryParse(odd), isNull);
    expect(FlightInfo.tryParse(hotel), isNull);
  });

  test('only flights are selected; cheapest and earliest sorting', () {
    expect(selectFlights(all).map((x) => x.id), ['d', 'b', 'c', 'a']);
    expect(selectFlights(all, sort: FlightSort.earliest).map((x) => x.id), ['a', 'c', 'b', 'd']);
  });

  test('airport filters keep only parsable matching routes', () {
    expect(selectFlights(all, from: 'BKK', to: 'CNX').map((x) => x.id), ['b', 'a']);
    expect(selectFlights(all, from: 'CNX').map((x) => x.id), ['c']);
    expect(selectFlights(all, to: 'HKT'), isEmpty);
  });

  test('airport list is sorted and unique', () => expect(flightAirports(all), ['BKK', 'CNX']));
}
