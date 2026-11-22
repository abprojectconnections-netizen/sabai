import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/admin_models.dart';
import '../../state/admin_controller.dart';
import '../../state/app_state.dart';
import '../staff/moderation_screen.dart';
import 'admin_users_screen.dart';
import 'audit_screen.dart';

/// Landing page of the admin console: live counts from the backend and links to the tools this person may use.
/// The server checks every request; the links are only shown when /me says the permission is held.
class AdminConsoleScreen extends StatefulWidget {
  const AdminConsoleScreen({super.key});

  @override
  State<AdminConsoleScreen> createState() => _AdminConsoleScreenState();
}

class _AdminConsoleScreenState extends State<AdminConsoleScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && context.read<AppState>().account.canViewDashboard) context.read<AdminController>().loadStats();
    });
  }

  void _push(Widget screen) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final c = context.watch<AdminController>();
    final account = context.watch<AppState>().account;
    return Scaffold(
      appBar: AppBar(title: const Text('คอนโซลผู้ดูแล')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: RefreshIndicator(
            onRefresh: c.loadStats,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (account.canViewDashboard) ...[
                  if (c.statsLoading && c.stats == null)
                    const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
                  else if (c.statsError != null && c.stats == null)
                    Padding(padding: const EdgeInsets.all(16), child: Text(c.statsError!, key: const Key('dashboardError')))
                  else if (c.stats != null)
                    _Stats(stats: c.stats!),
                  const SizedBox(height: 16),
                ],
                if (account.canManageUsers)
                  ListTile(
                    key: const Key('usersTile'),
                    leading: const Icon(Icons.people_outline),
                    title: const Text('ผู้ใช้'),
                    subtitle: const Text('ค้นหา ดูรายละเอียด ระงับหรือเปิดใช้งานบัญชี'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _push(const AdminUsersScreen()),
                  ),
                if (account.canReadAudit)
                  ListTile(
                    key: const Key('auditTile'),
                    leading: const Icon(Icons.fact_check_outlined),
                    title: const Text('ประวัติตรวจสอบ (Audit)'),
                    subtitle: const Text('อ่านอย่างเดียว เรียงจากใหม่ไปเก่า'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _push(const AuditScreen()),
                  ),
                if (account.canModerateCommunity)
                  ListTile(
                    key: const Key('consoleModerationTile'),
                    leading: const Icon(Icons.shield_outlined),
                    title: const Text('ตรวจสอบรายงานชุมชน'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _push(const ModerationScreen()),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.stats});

  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final cards = <(String, String, int)>[
      ('stat-users-total', 'ผู้ใช้ทั้งหมด', stats.usersTotal),
      ('stat-users-active', 'ใช้งานอยู่', stats.usersActive),
      ('stat-users-suspended', 'ถูกระงับ', stats.usersSuspended),
      ('stat-users-new', 'สมัครใหม่ 7 วัน', stats.usersNew7),
      ('stat-bookings-total', 'การจองทั้งหมด', stats.bookingsTotal),
      ('stat-bookings-new', 'จองใหม่ 7 วัน', stats.bookingsNew7),
    ];
    final queues = <(String, String, int)>[
      ('queue-reports', 'รายงานชุมชนที่รอตรวจ', stats.queue('community_reports_open')),
      ('queue-tickets', 'ตั๋วช่วยเหลือที่เปิดอยู่', stats.queue('tickets_open')),
      ('queue-disputes', 'ข้อพิพาทที่เปิดอยู่', stats.queue('disputes_open')),
      ('queue-refunds', 'คำขอคืนเงินที่ค้าง', stats.queue('refunds_open')),
      ('queue-partners', 'พาร์ตเนอร์รออนุมัติ', stats.queue('partners_pending')),
      ('queue-roles', 'คำขอสิทธิ์ที่รออนุมัติ', stats.queue('role_requests_pending')),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 12, runSpacing: 12, children: [for (final c in cards) _StatCard(id: c.$1, label: c.$2, value: c.$3)]),
      const SizedBox(height: 20),
      Text('งานที่รอดำเนินการ', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      Wrap(spacing: 12, runSpacing: 12, children: [for (final c in queues) _StatCard(id: c.$1, label: c.$2, value: c.$3)]),
      if (stats.bookingsByStatus.isNotEmpty) ...[
        const SizedBox(height: 20),
        Text('การจองตามสถานะ', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 4, children: [for (final e in stats.bookingsByStatus.entries) Chip(label: Text('${e.key} ${e.value}'))]),
      ],
    ]);
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.id, required this.label, required this.value});

  final String id;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$value', key: Key(id), style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ]),
        ),
      ),
    );
  }
}
