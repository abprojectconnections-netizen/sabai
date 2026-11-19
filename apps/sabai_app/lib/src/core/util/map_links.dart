/// Google Maps deep links. They open the Maps app or website; no API key and no embedded map.
const String _mapsBase = 'https://www.google.com/maps';

/// Google Maps accepts at most 9 waypoints between origin and destination.
const int maxMapWaypoints = 9;

Uri mapsSearchUri(String query) =>
    Uri.parse('$_mapsBase/search/?api=1&query=${Uri.encodeComponent(query.trim())}');

/// Route through [stops] in order: the last stop is the destination, the rest are waypoints. The origin is left
/// out, so Maps starts from the user's current location. Returns null with fewer than one stop; extra stops beyond
/// the Maps limit (1 destination + 9 waypoints) are dropped from the end.
Uri? mapsRouteUri(List<String> stops, {String mode = 'driving'}) {
  final clean = stops.map((s) => s.trim()).where((s) => s.isNotEmpty).take(maxMapWaypoints + 1).toList();
  if (clean.isEmpty) return null;
  final destination = clean.last;
  final waypoints = clean.sublist(0, clean.length - 1);
  final params = <String>[
    'api=1',
    'destination=${Uri.encodeComponent(destination)}',
    'travelmode=$mode',
    if (waypoints.isNotEmpty) 'waypoints=${waypoints.map(Uri.encodeComponent).join('%7C')}',
  ];
  return Uri.parse('$_mapsBase/dir/?${params.join('&')}');
}
