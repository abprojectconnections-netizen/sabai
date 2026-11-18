import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/util/dates.dart';
import '../../domain/trip_planner.dart';
import '../../state/trips_controller.dart';
import '../trips/trip_detail_screen.dart';

/// Starter itinerary from fixed templates. It is not AI: the screen says so and the plan is saved as an ordinary trip
/// the user can edit.
class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key});

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  final _destination = TextEditingController();
  int _days = 3;
  DateTime? _start;
  final Set<String> _styles = {};
  List<PlannedDay>? _plan;
  String? _problem;
  bool _saving = false;

  @override
  void dispose() {
    _destination.dispose();
    super.dispose();
  }

  Future<void> _pickStart() async {
    final now = DateTime.now();
    final p = await showDatePicker(
      context: context,
      initialDate: _start ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (p != null) setState(() => _start = p);
  }

  void _generate() {
    final d = _destination.text.trim();
    if (d.isEmpty) return setState(() => _problem = 'กรุณากรอกจุดหมายปลายทาง');
    if (_start == null) return setState(() => _problem = 'กรุณาเลือกวันเริ่มเดินทาง');
    setState(() {
      _problem = null;
      _plan = buildPlan(destination: d, days: _days, styles: _styles.toList());
    });
  }

  Future<void> _save() async {
    final plan = _plan;
    final start = _start;
    if (plan == null || start == null) return;
    final c = context.read<TripsController>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final d = _destination.text.trim();
    final end = DateTime(start.year, start.month, start.day + plan.length - 1);
    setState(() => _saving = true);
    final r = await c.createFromPlan(
      name: 'ทริป$d ${plan.length} วัน',
      startDate: toIsoDate(start),
      endDate: toIsoDate(end),
      plan: plan,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (r == null) {
      setState(() => _problem = c.error ?? 'บันทึกทริปไม่สำเร็จ');
      return;
    }
    if (r.failed > 0) {
      messenger.showSnackBar(SnackBar(content: Text('บันทึกทริปแล้ว แต่เพิ่มกิจกรรมไม่สำเร็จ ${r.failed} รายการ')));
    }
    navigator.pushReplacement(MaterialPageRoute<void>(builder: (_) => TripDetailScreen(tripId: r.tripId)));
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan;
    return Scaffold(
      appBar: AppBar(title: const Text('สร้างแผนจากแม่แบบ')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            key: const Key('plannerNotice'),
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Text('แผนตัวอย่างจากแม่แบบ ไม่ใช่ AI และไม่ตรวจเวลาเปิด-ปิด ระยะทาง หรือค่าใช้จ่ายจริง '
                  'ปรับแก้ได้หลังบันทึกเป็นทริป'),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('plannerDestinationField'),
            controller: _destination,
            decoration: const InputDecoration(labelText: 'จุดหมายปลายทาง', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          Row(children: [
            const Text('จำนวนวัน'),
            IconButton(
              key: const Key('daysMinus'),
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: _days > 1 ? () => setState(() => _days--) : null,
            ),
            Text('$_days', key: const Key('daysValue')),
            IconButton(
              key: const Key('daysPlus'),
              icon: const Icon(Icons.add_circle_outline),
              onPressed: _days < maxPlannerDays ? () => setState(() => _days++) : null,
            ),
            Text('(สูงสุด $maxPlannerDays)', style: Theme.of(context).textTheme.bodySmall),
          ]),
          ListTile(
            key: const Key('plannerStartTile'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event),
            title: Text(_start == null ? 'เลือกวันเริ่มเดินทาง' : formatDate(toIsoDate(_start!))),
            onTap: _pickStart,
          ),
          Wrap(spacing: 8, children: [
            for (final s in plannerStyles)
              FilterChip(
                key: Key('style-$s'),
                label: Text(s),
                selected: _styles.contains(s),
                onSelected: (on) => setState(() => on ? _styles.add(s) : _styles.remove(s)),
              ),
          ]),
          if (_problem != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_problem!, key: const Key('plannerError'), style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          const SizedBox(height: 12),
          FilledButton(key: const Key('generatePlanButton'), onPressed: _generate, child: const Text('สร้างแผน')),
          if (plan != null) ...[
            const SizedBox(height: 16),
            for (final day in plan) ...[
              Text(day.title, style: Theme.of(context).textTheme.titleMedium),
              for (final it in day.items)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Text(it.time),
                  title: Text(it.text),
                ),
            ],
            const SizedBox(height: 8),
            FilledButton.tonal(
              key: const Key('savePlanButton'),
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'กำลังบันทึก...' : 'บันทึกเป็นทริป'),
            ),
          ],
        ],
      ),
    );
  }
}
