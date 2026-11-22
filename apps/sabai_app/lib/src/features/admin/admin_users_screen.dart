import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/util/dates.dart';
import '../../data/models/admin_models.dart';
import '../../state/admin_controller.dart';

/// Search and filter accounts; tap one to inspect it and suspend or reactivate it.
class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AdminController>().loadUsers(query: '', status: '');
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  static const _filters = [('', 'ทั้งหมด'), ('ACTIVE', 'ใช้งานอยู่'), ('SUSPENDED', 'ถูกระงับ')];

  @override
  Widget build(BuildContext context) {
    final c = context.watch<AdminController>();
    return Scaffold(
      appBar: AppBar(title: const Text('ผู้ใช้')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                key: const Key('userSearchField'),
                controller: _search,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'ค้นหาจากอีเมล',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    key: const Key('userSearchButton'),
                    icon: const Icon(Icons.arrow_forward),
                    tooltip: 'ค้นหา',
                    onPressed: () => c.loadUsers(query: _search.text),
                  ),
                ),
                onSubmitted: (v) => c.loadUsers(query: v),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(spacing: 8, children: [
                for (final f in _filters)
                  ChoiceChip(
                    key: Key('filter-${f.$1.isEmpty ? 'all' : f.$1}'),
                    label: Text(f.$2),
                    selected: c.userStatus == f.$1,
                    onSelected: (_) => c.loadUsers(status: f.$1),
                  ),
              ]),
            ),
            Expanded(child: _body(c)),
          ]),
        ),
      ),
    );
  }

  Widget _body(AdminController c) {
    if (c.usersLoading && c.users.isEmpty) return const Center(child: CircularProgressIndicator());
    if (c.usersError != null && c.users.isEmpty) {
      return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(c.usersError!, key: const Key('usersError'))));
    }
    if (c.users.isEmpty) {
      return const Center(child: Text('ไม่พบผู้ใช้ที่ตรงกับเงื่อนไข', key: Key('usersEmpty')));
    }
    return RefreshIndicator(
      onRefresh: () => c.loadUsers(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
        itemCount: c.users.length + 1,
        itemBuilder: (context, i) {
          if (i == c.users.length) {
            return Padding(
              padding: const EdgeInsets.all(12),
              child: Column(children: [
                Text('แสดง ${c.users.length} จาก ${c.usersTotal}', key: const Key('usersCount'), style: Theme.of(context).textTheme.bodySmall),
                if (c.hasMoreUsers)
                  TextButton(key: const Key('usersMore'), onPressed: c.usersLoading ? null : c.loadMoreUsers, child: const Text('โหลดเพิ่ม')),
              ]),
            );
          }
          final u = c.users[i];
          return ListTile(
            key: Key('user-${u.id}'),
            leading: CircleAvatar(child: Icon(u.suspended ? Icons.block : Icons.person_outline)),
            title: Text(u.email),
            subtitle: Text(u.roles.join(', ')),
            trailing: u.suspended
                ? Chip(key: Key('badge-${u.id}'), label: const Text('ถูกระงับ'))
                : const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => AdminUserDetailScreen(userId: u.id))),
          );
        },
      ),
    );
  }
}

/// One account. Suspending needs a reason and is recorded in the audit trail by the server.
class AdminUserDetailScreen extends StatefulWidget {
  const AdminUserDetailScreen({super.key, required this.userId});

  final String userId;

  @override
  State<AdminUserDetailScreen> createState() => _AdminUserDetailScreenState();
}

class _AdminUserDetailScreenState extends State<AdminUserDetailScreen> {
  AdminUser? _user;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final c = context.read<AdminController>();
    final u = await c.loadUser(widget.userId);
    if (!mounted) return;
    setState(() {
      _user = u;
      _error = u == null ? (c.actionError ?? 'โหลดข้อมูลไม่สำเร็จ') : null;
    });
  }

  Future<void> _change(String status) async {
    final user = _user;
    if (user == null) return;
    String reason = '';
    if (status == 'SUSPENDED') {
      final r = await showDialog<String>(context: context, builder: (_) => const _ReasonDialog());
      if (r == null) return;
      reason = r;
    } else {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('เปิดใช้งานบัญชีอีกครั้ง?'),
          content: Text(user.email),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('ยกเลิก')),
            FilledButton(key: const Key('confirmReactivate'), onPressed: () => Navigator.of(ctx).pop(true), child: const Text('ยืนยัน')),
          ],
        ),
      );
      if (ok != true) return;
    }
    if (!mounted) return;
    final c = context.read<AdminController>();
    setState(() => _busy = true);
    final ok = await c.setStatus(user.id, status, reason: reason);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (ok) _user = user.copyWith(status: status);
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? (status == 'SUSPENDED' ? 'ระงับบัญชีแล้ว' : 'เปิดใช้งานบัญชีแล้ว') : (c.actionError ?? 'ดำเนินการไม่สำเร็จ')),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final u = _user;
    return Scaffold(
      appBar: AppBar(title: const Text('รายละเอียดผู้ใช้')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: u == null
              ? Center(child: _error == null ? const CircularProgressIndicator() : Text(_error!, key: const Key('userError')))
              : ListView(padding: const EdgeInsets.all(16), children: [
                  Text(u.email, key: const Key('detailEmail'), style: Theme.of(context).textTheme.titleLarge),
                  if (u.displayName != null && u.displayName!.isNotEmpty) Text(u.displayName!),
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, runSpacing: 4, children: [
                    Chip(key: const Key('detailStatus'), label: Text(u.suspended ? 'ถูกระงับ' : 'ใช้งานอยู่')),
                    for (final r in u.roles) Chip(label: Text(r)),
                  ]),
                  const SizedBox(height: 12),
                  Text('สมัครเมื่อ ${formatDate(u.createdAt)}'),
                  Text(u.lastLoginAt == null ? 'ยังไม่เคยเข้าสู่ระบบ' : 'เข้าสู่ระบบล่าสุด ${formatDate(u.lastLoginAt!)}'),
                  if (u.pendingRoles.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('คำขอสิทธิ์ที่รออนุมัติ: ${u.pendingRoles.join(', ')}', key: const Key('pendingRoles')),
                  ],
                  const SizedBox(height: 24),
                  if (u.suspended)
                    FilledButton(key: const Key('reactivateButton'), onPressed: _busy ? null : () => _change('ACTIVE'), child: const Text('เปิดใช้งานบัญชีอีกครั้ง'))
                  else
                    FilledButton(
                      key: const Key('suspendButton'),
                      style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
                      onPressed: _busy ? null : () => _change('SUSPENDED'),
                      child: const Text('ระงับบัญชี'),
                    ),
                  const SizedBox(height: 8),
                  Text('การเปลี่ยนสถานะมีผลทันทีและถูกบันทึกในประวัติตรวจสอบ ไม่สามารถเปลี่ยนสถานะบัญชีของตัวเองได้',
                      style: Theme.of(context).textTheme.bodySmall),
                ]),
        ),
      ),
    );
  }
}

/// Owns its text controller so it is disposed with the dialog; returns the reason, or null on cancel.
class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog();

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
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
      title: const Text('ระงับบัญชีนี้?'),
      content: TextField(
        key: const Key('reasonField'),
        controller: _reason,
        maxLength: 500,
        maxLines: 3,
        decoration: InputDecoration(labelText: 'เหตุผล (จำเป็น)', errorText: _error),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('ยกเลิก')),
        FilledButton(key: const Key('confirmSuspend'), onPressed: _submit, child: const Text('ระงับ')),
      ],
    );
  }
}
