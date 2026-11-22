import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/util/dates.dart';
import '../../data/models/admin_models.dart';
import '../../state/admin_controller.dart';

/// Read-only audit trail, newest first. Each row expands to show the before/after values the server recorded.
class AuditScreen extends StatefulWidget {
  const AuditScreen({super.key});

  @override
  State<AuditScreen> createState() => _AuditScreenState();
}

class _AuditScreenState extends State<AuditScreen> {
  final _filter = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AdminController>().loadAudit(action: '');
    });
  }

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  static String _pretty(Map<String, dynamic>? m) => m == null ? '-' : const JsonEncoder.withIndent('  ').convert(m);

  @override
  Widget build(BuildContext context) {
    final c = context.watch<AdminController>();
    return Scaffold(
      appBar: AppBar(title: const Text('ประวัติตรวจสอบ')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                key: const Key('auditActionField'),
                controller: _filter,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'กรองตามชื่อเหตุการณ์ เช่น user.status.changed',
                  prefixIcon: const Icon(Icons.filter_alt_outlined),
                  suffixIcon: IconButton(
                    key: const Key('auditFilterButton'),
                    icon: const Icon(Icons.arrow_forward),
                    tooltip: 'กรอง',
                    onPressed: () => c.loadAudit(action: _filter.text),
                  ),
                ),
                onSubmitted: (v) => c.loadAudit(action: v),
              ),
            ),
            Expanded(child: _body(c)),
          ]),
        ),
      ),
    );
  }

  Widget _body(AdminController c) {
    if (c.auditLoading && c.audit.isEmpty) return const Center(child: CircularProgressIndicator());
    if (c.auditError != null && c.audit.isEmpty) {
      return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(c.auditError!, key: const Key('auditError'))));
    }
    if (c.audit.isEmpty) return const Center(child: Text('ไม่มีรายการในประวัติตรวจสอบ', key: Key('auditEmpty')));
    return RefreshIndicator(
      onRefresh: () => c.loadAudit(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
        itemCount: c.audit.length + 1,
        itemBuilder: (context, i) {
          if (i == c.audit.length) {
            return Padding(
              padding: const EdgeInsets.all(12),
              child: Column(children: [
                Text('แสดง ${c.audit.length} จาก ${c.auditTotal}', key: const Key('auditCount'), style: Theme.of(context).textTheme.bodySmall),
                if (c.hasMoreAudit)
                  TextButton(key: const Key('auditMore'), onPressed: c.auditLoading ? null : c.loadMoreAudit, child: const Text('โหลดเพิ่ม')),
              ]),
            );
          }
          return _Row(entry: c.audit[i]);
        },
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.entry});

  final AuditEntry entry;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      key: Key('audit-${entry.id}'),
      title: Text(entry.action),
      subtitle: Text('${entry.actorEmail.isEmpty ? 'ระบบ' : entry.actorEmail} · ${formatDate(entry.createdAt)}'),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${entry.subjectType} ${entry.subjectId}'),
        const SizedBox(height: 8),
        const Text('ก่อน'),
        SelectableText(_AuditScreenState._pretty(entry.before)),
        const SizedBox(height: 8),
        const Text('หลัง'),
        SelectableText(_AuditScreenState._pretty(entry.after), key: Key('after-${entry.id}')),
      ],
    );
  }
}
