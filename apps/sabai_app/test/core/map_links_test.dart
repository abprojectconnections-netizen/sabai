import 'package:flutter_test/flutter_test.dart';
import 'package:sabai_app/src/core/util/map_links.dart';

void main() {
  test('search link encodes Thai and special characters', () {
    final u = mapsSearchUri(' วัดพระสิงห์ & ตลาด ');
    expect(u.host, 'www.google.com');
    expect(u.path, '/maps/search/');
    expect(u.queryParameters['api'], '1');
    expect(u.queryParameters['query'], 'วัดพระสิงห์ & ตลาด');
  });

  test('route link: last stop is the destination, others are waypoints', () {
    final u = mapsRouteUri(['A', 'B', 'C'])!;
    expect(u.path, '/maps/dir/');
    expect(u.queryParameters['destination'], 'C');
    expect(u.queryParameters['waypoints'], 'A|B');
    expect(u.queryParameters['travelmode'], 'driving');
    expect(u.queryParameters.containsKey('origin'), isFalse); // starts from the user's location
  });

  test('route link: one stop has no waypoints; none gives null; blanks ignored', () {
    expect(mapsRouteUri(['A'])!.queryParameters.containsKey('waypoints'), isFalse);
    expect(mapsRouteUri(const []), isNull);
    expect(mapsRouteUri(['  ', '']), isNull);
  });

  test('route link keeps at most 1 destination + 9 waypoints', () {
    final stops = List.generate(15, (i) => 'S$i');
    final u = mapsRouteUri(stops)!;
    expect(u.queryParameters['waypoints']!.split('|').length, maxMapWaypoints);
    expect(u.queryParameters['destination'], 'S9');
  });
}
