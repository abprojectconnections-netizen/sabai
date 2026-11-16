import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/util/dates.dart';
import '../../data/models/trip_models.dart';
import '../../state/trips_controller.dart';

class TripDetailScreen extends StatefulWidget {
  const TripDetailScreen({super.key, required this.tripId});

  final String tripId;

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  Trip? _trip;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  Future<void> _reload() async {
    final t = await context.read<TripsController>().open(widget.tripId);
    if (!mounted) return;
    setState(() {
      _trip = t ?? _trip;
      _loading = false;
    });
  }

  Future<void> _addActivity() async {
    final trip = _trip;
    if (trip == null) return;
    final c = context.read<TripsController>();
    final input = await showDialog<_ActivityInput>(
      context: context,
      builder: (_) => _ActivityDialog(trip: trip),
    );
    if (input == null) return;
    final ok = await c.addActivity(trip.id,
        title: input.title, date: input.date, startTime: input.startTime, endTime: input.endTime);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(c.error ?? 'เพิ่มกิจกรรมไม่สำเร็จ')));
      return;
    }
    await _reload();
  }

  Future<void> _removeActivity(Activity a) async {
    final c = context.read<TripsController>();
    final ok = await c.removeActivity(widget.tripId, a.id);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(c.error ?? 'ลบกิจกรรมไม่สำเร็จ')));
      return;
    }
    await _reload();
  }

  Future<void> _deleteTrip() async {
    final c = context.read<TripsController>();
    final navigator = Navigator.of(context);
    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ลบทริปนี้?'),
        content: const Text('กิจกรรมทั้งหมดในทริปจะถูกลบด้วย'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก')),
          FilledButton(key: const Key('confirmDeleteTrip'), onPressed: () => Navigator.pop(ctx, true), child: const Text('ลบ')),
        ],
      ),
    );
    if (sure != true) return;
    if (await c.delete(widget.tripId) && mounted) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final trip = _trip;
    return Scaffold(
      appBar: AppBar(
        title: Text(trip?.name ?? 'ทริป'),
        actions: [
          if (trip != null)
            IconButton(key: const Key('deleteTripButton'), tooltip: 'ลบทริป', icon: const Icon(Icons.delete_outline), onPressed: _deleteTrip),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : trip == null
              ? Center(child: Text(context.watch<TripsController>().error ?? 'ไม่พบทริป'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(trip.name, style: Theme.of(context).textTheme.headlineSmall),
                    Text(formatRange(trip.startDate, trip.endDate).isEmpty
                        ? 'ยังไม่กำหนดวันเดินทาง'
                        : formatRange(trip.startDate, trip.endDate)),
                    const SizedBox(height: 16),
                    if (trip.days.isEmpty) const Text('ยังไม่มีกิจกรรม เพิ่มกิจกรรมแรกได้เลย'),
                    for (final d in trip.days) ...[
                      Text('วันที่ ${d.dayNumber} · ${formatDate(d.date)}', style: Theme.of(context).textTheme.titleMedium),
                      for (final a in d.activities)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.place_outlined),
                          title: Text(a.title),
                          subtitle: a.startTime.isEmpty ? null : Text(a.endTime.isEmpty ? a.startTime : '${a.startTime} – ${a.endTime}'),
                          trailing: IconButton(tooltip: 'ลบกิจกรรม', icon: const Icon(Icons.close), onPressed: () => _removeActivity(a)),
                        ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
      floatingActionButton: trip == null
          ? null
          : FloatingActionButton.extended(
              key: const Key('addActivityButton'),
              onPressed: _addActivity,
              icon: const Icon(Icons.add),
              label: const Text('เพิ่มกิจกรรม'),
            ),
    );
  }
}

class _ActivityInput {
  const _ActivityInput(this.title, this.date, this.startTime, this.endTime);
  final String title;
  final String date;
  final String startTime;
  final String endTime;
}

class _ActivityDialog extends StatefulWidget {
  const _ActivityDialog({required this.trip});

  final Trip trip;

  @override
  State<_ActivityDialog> createState() => _ActivityDialogState();
}

class _ActivityDialogState extends State<_ActivityDialog> {
  final _title = TextEditingController();
  late DateTime _date;
  TimeOfDay? _start;
  TimeOfDay? _end;
  String? _problem;

  @override
  void initState() {
    super.initState();
    _date = parseIsoDate(widget.trip.startDate) ?? DateTime.now();
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  String _hhmm(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final first = parseIsoDate(widget.trip.startDate) ?? DateTime.now().subtract(const Duration(days: 365));
    final last = parseIsoDate(widget.trip.endDate) ?? DateTime.now().add(const Duration(days: 365 * 3));
    return AlertDialog(
      title: const Text('เพิ่มกิจกรรม'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('activityTitleField'),
              controller: _title,
              maxLength: 200,
              decoration: const InputDecoration(labelText: 'ชื่อกิจกรรม'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: Text(formatDate(toIsoDate(_date))),
              onTap: () async {
                final p = await showDatePicker(
                  context: context,
                  initialDate: _date.isBefore(first) ? first : (_date.isAfter(last) ? last : _date),
                  firstDate: first,
                  lastDate: last,
                );
                if (p != null) setState(() => _date = p);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule),
              title: Text(_start == null ? 'เวลาเริ่ม (ไม่บังคับ)' : _hhmm(_start!)),
              onTap: () async {
                final p = await showTimePicker(context: context, initialTime: _start ?? const TimeOfDay(hour: 9, minute: 0));
                if (p != null) setState(() => _start = p);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule_outlined),
              title: Text(_end == null ? 'เวลาสิ้นสุด (ไม่บังคับ)' : _hhmm(_end!)),
              onTap: () async {
                final p = await showTimePicker(context: context, initialTime: _end ?? _start ?? const TimeOfDay(hour: 10, minute: 0));
                if (p != null) setState(() => _end = p);
              },
            ),
            if (_problem != null) Text(_problem!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('ยกเลิก')),
        FilledButton(
          key: const Key('saveActivityButton'),
          onPressed: () {
            if (_title.text.trim().isEmpty) return setState(() => _problem = 'กรุณากรอกชื่อกิจกรรม');
            if (_end != null && _start == null) return setState(() => _problem = 'ต้องระบุเวลาเริ่มก่อนเวลาสิ้นสุด');
            if (_end != null && _start != null && _hhmm(_end!).compareTo(_hhmm(_start!)) < 0) {
              return setState(() => _problem = 'เวลาสิ้นสุดต้องไม่ก่อนเวลาเริ่ม');
            }
            Navigator.pop(context, _ActivityInput(_title.text.trim(), toIsoDate(_date), _start == null ? '' : _hhmm(_start!), _end == null ? '' : _hhmm(_end!)));
          },
          child: const Text('เพิ่ม'),
        ),
      ],
    );
  }
}
