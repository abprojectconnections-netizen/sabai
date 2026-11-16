import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/settings_controller.dart';

/// Device-only preferences. Password change and account deletion are NOT here: the backend has no such endpoints yet,
/// and the app must not pretend to do them.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsController>();
    return Scaffold(
      appBar: AppBar(title: const Text('การตั้งค่า')),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text('ธีม'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<ThemeMode>(
              key: const Key('themeSelector'),
              segments: const [
                ButtonSegment(value: ThemeMode.light, label: Text('สว่าง')),
                ButtonSegment(value: ThemeMode.dark, label: Text('มืด')),
                ButtonSegment(value: ThemeMode.system, label: Text('ตามระบบ')),
              ],
              selected: {s.themeMode},
              onSelectionChanged: (v) => s.setThemeMode(v.first),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 24, 16, 0),
            child: Text('การเตือนบนอุปกรณ์นี้'),
          ),
          SwitchListTile(
            key: const Key('notifyTripSwitch'),
            title: const Text('เตือนก่อนเดินทาง'),
            subtitle: const Text('เก็บเฉพาะในเครื่องนี้'),
            value: s.notifyTrip,
            onChanged: s.setNotifyTrip,
          ),
          SwitchListTile(
            key: const Key('notifyPromoSwitch'),
            title: const Text('โปรโมชั่นและคูปอง'),
            subtitle: const Text('เก็บเฉพาะในเครื่องนี้'),
            value: s.notifyPromo,
            onChanged: s.setNotifyPromo,
          ),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.lock_outline),
            title: Text('เปลี่ยนรหัสผ่าน / ลบบัญชี'),
            subtitle: Text('ยังไม่เปิดให้ใช้ เพราะระบบหลังบ้านยังไม่รองรับ'),
            enabled: false,
          ),
        ],
      ),
    );
  }
}
