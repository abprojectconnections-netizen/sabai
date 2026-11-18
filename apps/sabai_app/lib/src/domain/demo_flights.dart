/// SIMULATED flights for a demo screen. Nothing here comes from an airline or a provider: carriers are fictional,
/// times and prices are generated deterministically from the route and date. Never feed these numbers into booking,
/// payment or any money flow (real prices come from the server only).

class DemoAirport {
  const DemoAirport(this.code, this.name, this.baseMinutes);
  final String code;
  final String name;

  /// Simulated flight time from Bangkok, in minutes.
  final int baseMinutes;
}

const List<DemoAirport> demoAirports = [
  DemoAirport('BKK', 'กรุงเทพฯ (สุวรรณภูมิ)', 0),
  DemoAirport('CNX', 'เชียงใหม่', 75),
  DemoAirport('HKT', 'ภูเก็ต', 90),
  DemoAirport('KBV', 'กระบี่', 85),
  DemoAirport('USM', 'เกาะสมุย', 80),
];

class DemoCarrier {
  const DemoCarrier(this.code, this.name, this.factor, this.departures);
  final String code;
  final String name;
  final double factor;
  final List<String> departures;
}

const List<DemoCarrier> demoCarriers = [
  DemoCarrier('XA', 'สายการบินตัวอย่าง A', 1.3, ['07:00', '12:30', '18:15']),
  DemoCarrier('XB', 'สายการบินตัวอย่าง B', 1.0, ['08:20', '14:10', '19:40']),
  DemoCarrier('XC', 'สายการบินตัวอย่าง C', 0.8, ['06:15', '10:45', '16:30', '20:50']),
];

class DemoFlight {
  const DemoFlight({
    required this.id,
    required this.carrier,
    required this.number,
    required this.from,
    required this.to,
    required this.date,
    required this.departs,
    required this.arrives,
    required this.minutes,
    required this.price,
  });

  final String id;
  final String carrier;
  final String number;
  final String from;
  final String to;
  final String date;
  final String departs;
  final String arrives;
  final int minutes;

  /// Simulated, in baht. Not a quote.
  final int price;
}

enum DemoFlightSort { cheapest, fastest, earliest }

int _hash(String s) {
  var h = 7;
  for (final c in s.codeUnits) {
    h = (h * 31 + c) & 0xFFFFFFFF;
  }
  return h;
}

String _hhmm(int minutes) {
  final m = minutes % (24 * 60);
  return '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
}

int _mins(String hhmm) {
  final p = hhmm.split(':');
  return int.parse(p[0]) * 60 + int.parse(p[1]);
}

/// Deterministic: the same route and date always give the same list. Returns an empty list when the airports are
/// equal or unknown.
List<DemoFlight> searchDemoFlights({required String from, required String to, required String date, DemoFlightSort sort = DemoFlightSort.cheapest}) {
  if (from == to) return const [];
  final a = demoAirports.where((x) => x.code == from);
  final b = demoAirports.where((x) => x.code == to);
  if (a.isEmpty || b.isEmpty) return const [];
  // Routes are Bangkok <-> a city; between two cities the simulated time is the sum (a connection through Bangkok is not modelled).
  final base = a.first.baseMinutes + b.first.baseMinutes;
  final d = DateTime.tryParse(date);
  final weekend = d != null && (d.weekday == DateTime.friday || d.weekday == DateTime.saturday || d.weekday == DateTime.sunday);
  final out = <DemoFlight>[];
  for (final c in demoCarriers) {
    for (final dep in c.departures) {
      final h = _hash('${c.code}$from$to$date$dep');
      final dur = base + (h % 9);
      final raw = 1700 * c.factor * (1 + (h % 15) / 100) * (weekend ? 1.12 : 1) * (base / 75);
      out.add(DemoFlight(
        id: '${c.code}-$from$to-$date-$dep',
        carrier: c.name,
        number: '${c.code} ${100 + (h % 900)}',
        from: from,
        to: to,
        date: date,
        departs: dep,
        arrives: _hhmm(_mins(dep) + dur),
        minutes: dur,
        price: (raw / 10).round() * 10,
      ));
    }
  }
  switch (sort) {
    case DemoFlightSort.cheapest:
      out.sort((x, y) => x.price != y.price ? x.price.compareTo(y.price) : x.departs.compareTo(y.departs));
    case DemoFlightSort.fastest:
      out.sort((x, y) => x.minutes != y.minutes ? x.minutes.compareTo(y.minutes) : x.price.compareTo(y.price));
    case DemoFlightSort.earliest:
      out.sort((x, y) => x.departs.compareTo(y.departs));
  }
  return out;
}

String demoDuration(int minutes) => '${minutes ~/ 60} ชม. ${(minutes % 60).toString().padLeft(2, '0')} น.';
