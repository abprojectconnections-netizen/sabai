import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/admin_models.dart';
import '../../state/admin_controller.dart';

/// Runtime feature switches (config.manage). Turning a feature off needs a reason, which the server writes to the audit
/// trail. The list always reflects what the server holds.
class FeatureFlagsScreen extends StatefulWidget {
  const FeatureFlagsScreen({super.key});

  @override
  State<FeatureFlagsScreen> createState() => _FeatureFlagsScreenState();
}

class _FeatureFlagsScreenState extends State<FeatureFlagsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AdminController>().loadFlags();
    });
  }

  Future<void> _toggle(FeatureFlag flag, bool enabled) async {
    final c = context.read<AdminController>();
    final messenger = ScaffoldMessenger.of(context);
    var reason = '';
    if (!enabled) {
      final r = await showDialog<String>(context: context, builder: (_) => _OffDialog(flag: flag));
      if (r == null) return;
      reason = r;
    }
    final ok = await c.setFlag(flag.key, enabled, reason: reason);
    messenger.showSnackBar(SnackBar(content: Text(ok ? (enabled ? 'เปิดฟีเจอร์แล้ว' : 'ปิดฟีเจอร์แล้ว') : (c.actionError ?? 'ทำรายการไม่สำเร็จ'))));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<AdminController>();
    Widget body;
    if (c.flagsLoading && c.flags.isEmpty) {
      body = const Center(child: CircularProgressIndicator());
    } else if (c.flagsError != null && c.flags.isEmpty) {
      body = Center(
          child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(c.flagsError!, key: const Key('flagsError')),
                const SizedBox(height: 12),
                OutlinedButton(onPressed: c.loadFlags, child: const Text('ลองอีกครั้ง')),
              ])));
    } else if (c.flags.isEmpty) {
      body = const Center(child: Text('ยังไม่มีฟีเจอร์ที่ปิดเปิดได้', key: Key('flagsEmpty')));
    } else {
      body = RefreshIndicator(
        onRefresh: c.loadFlags,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text('ปิดฟีเจอร์เมื่อเกิดเหตุฉุกเฉิน เช่น สแปมท่วมชุมชน การเปลี่ยนมีผลกับผู้ใช้ทุกคนทันที และถูกบันทึกใน Audit'),
            ),
            for (final f in c.flags)
              SwitchListTile(
                key: Key('flag-${f.key}'),
                value: f.enabled,
                title: Text(f.key),
                subtitle: Text([f.description, if (f.updatedBy != null) 'แก้ไขล่าสุดโดย ${f.updatedBy}'].where((s) => s.isNotEmpty).join('\n')),
                isThreeLine: f.description.isNotEmpty && f.updatedBy != null,
                onChanged: (v) => _toggle(f, v),
              ),
          ],
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('ฟีเจอร์ที่ปิดเปิดได้')),
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 900), child: body)),
    );
  }
}

class _OffDialog extends StatefulWidget {
  const _OffDialog({required this.flag});

  final FeatureFlag flag;

  @override
  State<_OffDialog> createState() => _OffDialogState();
}

class _OffDialogState extends State<_OffDialog> {
  final _reason = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  void _submit() {
    final r = _reason.text.trim();
    if (r.length < 3) {
      setState(() => _error = 'กรุณาระบุเหตุผลอย่างน้อย 3 ตัวอักษร');
      return;
    }
    Navigator.of(context).pop(r);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('ปิด ${widget.flag.key}?'),
      content: TextField(
        key: const Key('flagReasonField'),
        controller: _reason,
        maxLength: 500,
        maxLines: 3,
        decoration: InputDecoration(labelText: 'เหตุผล (จำเป็น)', errorText: _error),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('ยกเลิก')),
        FilledButton(key: const Key('confirmFlagOff'), onPressed: _submit, child: const Text('ปิดฟีเจอร์')),
      ],
    );
  }
}
