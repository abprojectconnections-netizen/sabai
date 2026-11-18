import 'package:flutter/material.dart';

import '../../core/util/dates.dart';
import '../../core/util/format.dart';
import '../../domain/demo_flights.dart';

/// Demo flight search. Every flight is simulated and cannot be booked; the screen says so at the top and on each card.
class FlightsDemoScreen extends StatefulWidget {
  const FlightsDemoScreen({super.key, DateTime? today}) : _today = today;

  final DateTime? _today;

  @override
  State<FlightsDemoScreen> createState() => _FlightsDemoScreenState();
}

class _FlightsDemoScreenState extends State<FlightsDemoScreen> {
  String _from = 'BKK';
  String _to = 'CNX';
  late DateTime _date;
  DemoFlightSort _sort = DemoFlightSort.cheapest;

  @override
  void initState() {
    super.initState();
    final t = widget._today ?? DateTime.now();
    _date = DateTime(t.year, t.month, t.day + 14);
  }

  Future<void> _pickDate() async {
    final now = widget._today ?? DateTime.now();
    final p = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 1, now.month, now.day),
    );
    if (p != null) setState(() => _date = p);
  }

  @override
  Widget build(BuildContext context) {
    final results = searchDemoFlights(from: _from, to: _to, date: toIsoDate(_date), sort: _sort);
    return Scaffold(
      appBar: AppBar(title: const Text('เที่ยวบิน (ตัวอย่าง)')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            key: const Key('flightsDemoNotice'),
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Text('ข้อมูลตัวอย่างเพื่อสาธิตเท่านั้น สายการบิน เวลา และราคาเป็นข้อมูลจำลอง ไม่ใช่ราคาจริง และจองไม่ได้'),
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _airportField(const Key('fromField'), 'ต้นทาง', _from, (v) => setState(() => _from = v))),
            const SizedBox(width: 8),
            Expanded(child: _airportField(const Key('toField'), 'ปลายทาง', _to, (v) => setState(() => _to = v))),
          ]),
          ListTile(
            key: const Key('flightDateTile'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event),
            title: Text(formatDate(toIsoDate(_date))),
            onTap: _pickDate,
          ),
          Wrap(spacing: 8, children: [
            for (final s in DemoFlightSort.values)
              ChoiceChip(
                key: Key('sort-${s.name}'),
                label: Text(switch (s) {
                  DemoFlightSort.cheapest => 'ราคาถูกสุด',
                  DemoFlightSort.fastest => 'เร็วที่สุด',
                  DemoFlightSort.earliest => 'ออกเช้าสุด',
                }),
                selected: _sort == s,
                onSelected: (_) => setState(() => _sort = s),
              ),
          ]),
          const SizedBox(height: 12),
          if (_from == _to)
            const Text('ต้นทางและปลายทางต้องไม่ใช่สนามบินเดียวกัน', key: Key('sameAirport'))
          else
            for (final f in results) _FlightCard(flight: f),
        ],
      ),
    );
  }

  Widget _airportField(Key key, String label, String value, ValueChanged<String> onChanged) {
    return DropdownButtonFormField<String>(
      key: key,
      value: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      items: [
        for (final a in demoAirports) DropdownMenuItem(value: a.code, child: Text('${a.code} · ${a.name}', overflow: TextOverflow.ellipsis)),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

class _FlightCard extends StatelessWidget {
  const _FlightCard({required this.flight});

  final DemoFlight flight;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        key: Key('flight-${flight.id}'),
        leading: const Icon(Icons.flight),
        title: Text('${flight.departs} → ${flight.arrives}  ·  ${flight.from}→${flight.to}'),
        subtitle: Text('${flight.carrier} ${flight.number}\n${demoDuration(flight.minutes)} · ตัวอย่าง'),
        isThreeLine: true,
        trailing: Text('${formatBaht(flight.price)}\n(จำลอง)', textAlign: TextAlign.end),
      ),
    );
  }
}
