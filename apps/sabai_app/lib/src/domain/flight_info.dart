import '../data/models/models.dart';

/// Route and departure time read from a FLIGHT listing's title, e.g.
/// "สายการบินตัวอย่าง A XA 214 BKK→CNX ออก 07:00 (เที่ยวบินจำลอง)".
/// The catalogue has no structured flight fields yet, so this is a display-only parse; a listing that does not match
/// simply has no route and is still shown and bookable like any listing.
class FlightInfo {
  const FlightInfo({required this.from, required this.to, required this.departs});

  final String from;
  final String to;
  final String departs;

  static final RegExp _pattern = RegExp(r'([A-Z]{3})\s*(?:→|->)\s*([A-Z]{3})(?:\s+ออก\s+(\d{1,2}:\d{2}))?');

  static FlightInfo? tryParse(Listing l) {
    if (l.type != ListingType.flight) return null;
    final m = _pattern.firstMatch(l.title);
    if (m == null) return null;
    return FlightInfo(from: m.group(1)!, to: m.group(2)!, departs: m.group(3) ?? '');
  }
}

enum FlightSort { cheapest, earliest }

/// Flights only, filtered by optional airport codes, sorted. Listings without a parsable route are kept when no
/// airport filter is set (so nothing bookable silently disappears) and dropped when one is.
List<Listing> selectFlights(List<Listing> all, {String? from, String? to, FlightSort sort = FlightSort.cheapest}) {
  final out = all.where((l) {
    if (l.type != ListingType.flight) return false;
    final info = FlightInfo.tryParse(l);
    if (from != null && info?.from != from) return false;
    if (to != null && info?.to != to) return false;
    return true;
  }).toList();
  int cmpPrice(Listing a, Listing b) => a.price.compareTo(b.price);
  out.sort((a, b) {
    if (sort == FlightSort.earliest) {
      final c = (FlightInfo.tryParse(a)?.departs ?? '99:99').compareTo(FlightInfo.tryParse(b)?.departs ?? '99:99');
      if (c != 0) return c;
    }
    final c = cmpPrice(a, b);
    return c != 0 ? c : a.title.compareTo(b.title);
  });
  return out;
}

/// Airport codes present in [flights], for the filter menus.
List<String> flightAirports(List<Listing> all) {
  final s = <String>{};
  for (final l in all) {
    final i = FlightInfo.tryParse(l);
    if (i != null) {
      s
        ..add(i.from)
        ..add(i.to);
    }
  }
  return s.toList()..sort();
}
