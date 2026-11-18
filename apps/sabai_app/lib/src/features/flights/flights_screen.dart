import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/util/format.dart';
import '../../data/models/models.dart';
import '../../domain/flight_info.dart';
import '../../state/app_state.dart';
import '../catalog/listing_detail_screen.dart';

/// Flights come from the catalogue like every other product and are booked through the normal checkout.
/// The current catalogue holds simulated flights (fictional carriers) paid through the sandbox provider: no real
/// ticket is issued and no money moves. Real flights need a provider decision first.
class FlightsScreen extends StatefulWidget {
  const FlightsScreen({super.key});

  @override
  State<FlightsScreen> createState() => _FlightsScreenState();
}

class _FlightsScreenState extends State<FlightsScreen> {
  String? _from;
  String? _to;
  FlightSort _sort = FlightSort.cheapest;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final airports = flightAirports(state.listings);
    final flights = selectFlights(state.listings, from: _from, to: _to, sort: _sort);
    return Scaffold(
      appBar: AppBar(title: const Text('เที่ยวบิน')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            key: const Key('flightsSandboxNotice'),
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Text('ระบบทดสอบ (SANDBOX): เที่ยวบินเหล่านี้เป็นข้อมูลจำลอง ไม่ใช่ตั๋วจริง '
                  'การชำระเงินเป็นการจำลอง ไม่มีการตัดเงินจริง'),
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _airportMenu(const Key('flightFrom'), 'ต้นทาง', _from, airports, (v) => setState(() => _from = v))),
            const SizedBox(width: 8),
            Expanded(child: _airportMenu(const Key('flightTo'), 'ปลายทาง', _to, airports, (v) => setState(() => _to = v))),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            ChoiceChip(
              key: const Key('sort-cheapest'),
              label: const Text('ราคาถูกสุด'),
              selected: _sort == FlightSort.cheapest,
              onSelected: (_) => setState(() => _sort = FlightSort.cheapest),
            ),
            ChoiceChip(
              key: const Key('sort-earliest'),
              label: const Text('ออกเช้าสุด'),
              selected: _sort == FlightSort.earliest,
              onSelected: (_) => setState(() => _sort = FlightSort.earliest),
            ),
          ]),
          const SizedBox(height: 12),
          if (flights.isEmpty)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('ไม่พบเที่ยวบินตามเงื่อนไข', key: Key('noFlights'))))
          else
            for (final f in flights) _FlightCard(listing: f),
        ],
      ),
    );
  }

  Widget _airportMenu(Key key, String label, String? value, List<String> airports, ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String?>(
      key: key,
      value: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      items: [
        const DropdownMenuItem<String?>(value: null, child: Text('ทั้งหมด')),
        for (final a in airports) DropdownMenuItem<String?>(value: a, child: Text(a)),
      ],
      onChanged: onChanged,
    );
  }
}

class _FlightCard extends StatelessWidget {
  const _FlightCard({required this.listing});

  final Listing listing;

  @override
  Widget build(BuildContext context) {
    final info = FlightInfo.tryParse(listing);
    return Card(
      child: ListTile(
        key: Key('flight-${listing.id}'),
        leading: const Icon(Icons.flight),
        title: Text(info == null ? listing.title : '${info.from} → ${info.to}${info.departs.isEmpty ? '' : '  ·  ${info.departs}'}'),
        subtitle: Text(info == null ? listing.location : '${listing.title}\nวันที่ ${listing.serviceDate}'),
        isThreeLine: info != null,
        trailing: Text(listing.isAvailable ? formatBaht(listing.price) : 'เต็ม'),
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ListingDetailScreen(listing: listing))),
      ),
    );
  }
}
