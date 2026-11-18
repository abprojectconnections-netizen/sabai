import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/util/dates.dart';
import '../../state/app_state.dart';
import '../../state/trips_controller.dart';
import '../auth/login_screen.dart';
import '../planner/planner_screen.dart';
import 'create_trip_screen.dart';
import 'trip_detail_screen.dart';

/// "ทริปของฉัน" tab. Loads the signed-in user's trips from the server each time it appears.
class TripsScreen extends StatefulWidget {
  const TripsScreen({super.key});

  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && context.read<AppState>().signedIn) context.read<TripsController>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!context.watch<AppState>().signedIn) return const SignInPrompt();
    final c = context.watch<TripsController>();
    final Widget body;
    if (c.loading && c.trips.isEmpty) {
      body = const Center(child: CircularProgressIndicator());
    } else if (c.trips.isEmpty) {
      body = ListView(children: [
        const SizedBox(height: 120),
        Center(child: Text(c.error ?? 'คุณยังไม่มีทริป เริ่มสร้างทริปแรกได้เลย')),
      ]);
    } else {
      body = ListView.separated(
        itemCount: c.trips.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final t = c.trips[i];
          final range = formatRange(t.startDate, t.endDate);
          return ListTile(
            leading: const Icon(Icons.luggage_outlined),
            title: Text(t.name),
            subtitle: Text(range.isEmpty ? 'ยังไม่กำหนดวันเดินทาง' : range),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => TripDetailScreen(tripId: t.id)),
            ),
          );
        },
      );
    }
    return Scaffold(
      body: Column(children: [
        ListTile(
          key: const Key('plannerTile'),
          leading: const Icon(Icons.auto_awesome_outlined),
          title: const Text('สร้างแผนจากแม่แบบ'),
          subtitle: const Text('แผนตัวอย่าง ไม่ใช่ AI'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PlannerScreen())),
        ),
        const Divider(height: 1),
        Expanded(child: RefreshIndicator(onRefresh: c.load, child: body)),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('newTripButton'),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const CreateTripScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('สร้างทริป'),
      ),
    );
  }
}
