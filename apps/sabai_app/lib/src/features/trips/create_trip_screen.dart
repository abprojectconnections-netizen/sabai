import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/util/dates.dart';
import '../../state/trips_controller.dart';

class CreateTripScreen extends StatefulWidget {
  const CreateTripScreen({super.key});

  @override
  State<CreateTripScreen> createState() => _CreateTripScreenState();
}

class _CreateTripScreenState extends State<CreateTripScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  DateTime? _start;
  DateTime? _end;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pick({required bool start}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (start ? _start : _end) ?? _start ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (start) {
        _start = picked;
        if (_end != null && _end!.isBefore(picked)) _end = picked;
      } else {
        _end = picked;
        _start ??= picked;
      }
    });
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final c = context.read<TripsController>();
    final navigator = Navigator.of(context);
    setState(() => _saving = true);
    final t = await c.create(
      _name.text.trim(),
      startDate: _start == null ? '' : toIsoDate(_start!),
      endDate: _end == null ? '' : toIsoDate(_end!),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (t != null) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final error = context.watch<TripsController>().error;
    return Scaffold(
      appBar: AppBar(title: const Text('สร้างทริป')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              key: const Key('tripNameField'),
              controller: _name,
              maxLength: 200,
              decoration: const InputDecoration(labelText: 'ชื่อทริป'),
              validator: (v) => (v ?? '').trim().isEmpty ? 'กรุณากรอกชื่อทริป' : null,
            ),
            const SizedBox(height: 8),
            ListTile(
              key: const Key('startDateTile'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: Text(_start == null ? 'วันเริ่มเดินทาง (ไม่บังคับ)' : formatDate(toIsoDate(_start!))),
              onTap: () => _pick(start: true),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_available),
              title: Text(_end == null ? 'วันสิ้นสุด (ไม่บังคับ)' : formatDate(toIsoDate(_end!))),
              onTap: () => _pick(start: false),
            ),
            const Text('ทริปยาวได้ไม่เกิน 60 วัน', style: TextStyle(fontSize: 12)),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(error, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('saveTripButton'),
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'กำลังบันทึก…' : 'บันทึกทริป'),
            ),
          ],
        ),
      ),
    );
  }
}
