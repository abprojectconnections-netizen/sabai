import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/util/dates.dart';
import '../../data/models/community_models.dart';
import '../../state/moderation_controller.dart';

/// Staff queue for reported community posts. Works on phones (one column, full width) and on desktop/tablet windows
/// (content centred in a readable column, actions on the same row as the post when there is room).
class ModerationScreen extends StatefulWidget {
  const ModerationScreen({super.key});

  @override
  State<ModerationScreen> createState() => _ModerationScreenState();
}

class _ModerationScreenState extends State<ModerationScreen> {
  static const double _wide = 720;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ModerationController>().load();
    });
  }

  Future<void> _act(ReportedPost p, String action) async {
    final c = context.read<ModerationController>();
    final note = TextEditingController();
    final remove = action == 'remove';
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(remove ? 'ลบโพสต์นี้?' : 'ปัดตกรายงาน (คงโพสต์ไว้)?'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(remove ? 'โพสต์จะหายจากชุมชนของทุกคน การกระทำนี้ถูกบันทึกในประวัติตรวจสอบ' : 'โพสต์ยังแสดงอยู่ และรายงานทั้งหมดของโพสต์นี้จะถูกปิด'),
          const SizedBox(height: 12),
          TextField(
            key: const Key('moderationNote'),
            controller: note,
            maxLength: 200,
            decoration: const InputDecoration(labelText: 'หมายเหตุ (ไม่บังคับ)', border: OutlineInputBorder()),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก')),
          FilledButton(key: const Key('confirmModeration'), onPressed: () => Navigator.pop(ctx, true), child: Text(remove ? 'ลบโพสต์' : 'ปัดตก')),
        ],
      ),
    );
    final text = note.text;
    note.dispose();
    if (go != true) return;
    final ok = await c.act(p.id, action, note: text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? (remove ? 'ลบโพสต์แล้ว' : 'ปัดตกรายงานแล้ว') : (c.error ?? 'ดำเนินการไม่สำเร็จ'))));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ModerationController>();
    return Scaffold(
      appBar: AppBar(title: const Text('ตรวจสอบรายงานชุมชน')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: c.loading && c.queue.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: c.load,
                  child: c.queue.isEmpty
                      ? ListView(children: [
                          Padding(
                            padding: const EdgeInsets.all(32),
                            child: Center(child: Text(c.error ?? 'ไม่มีรายงานที่รอตรวจสอบ', key: const Key('queueEmpty'))),
                          ),
                        ])
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: c.queue.length,
                          itemBuilder: (context, i) => _ReportCard(post: c.queue[i], onAct: (a) => _act(c.queue[i], a)),
                        ),
                ),
        ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.post, required this.onAct});

  final ReportedPost post;
  final ValueChanged<String> onAct;

  @override
  Widget build(BuildContext context) {
    final actions = [
      OutlinedButton(key: Key('dismiss-${post.id}'), onPressed: () => onAct('dismiss'), child: const Text('ปัดตก (คงโพสต์)')),
      FilledButton(
        key: Key('remove-${post.id}'),
        style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
        onPressed: () => onAct('remove'),
        child: const Text('ลบโพสต์'),
      ),
    ];
    return Card(
      key: Key('report-${post.id}'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(builder: (context, box) {
          final wide = box.maxWidth >= _ModerationScreenState._wide - 32;
          final info = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(post.body),
            const SizedBox(height: 8),
            Text('${post.authorName.isEmpty ? 'สมาชิก' : post.authorName} · ${formatDate(post.date)}', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 4, children: [
              Chip(label: Text('รายงาน ${post.reportCount} ครั้ง')),
              for (final r in post.reasons) Chip(label: Text(communityReportReasonTh(r))),
            ]),
          ]);
          if (wide) {
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: info),
              const SizedBox(width: 16),
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (final a in actions) Padding(padding: const EdgeInsets.only(bottom: 8), child: a)]),
            ]);
          }
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            info,
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: actions),
          ]);
        }),
      ),
    );
  }
}
