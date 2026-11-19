import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/util/dates.dart';
import '../../data/models/community_models.dart';
import '../../state/community_controller.dart';
import '../../state/reviews_controller.dart' show parseTagInput;

/// Community tab. Posts are public to every signed-in user and appear immediately; abuse is reported afterwards.
class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<CommunityController>().ensureLoaded();
    });
  }

  Future<void> _compose() async {
    final c = context.read<CommunityController>();
    final posted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ComposeSheet(controller: c),
    );
    if (posted == true && mounted && c.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(c.error!)));
    }
  }

  Future<void> _delete(String id) async {
    final c = context.read<CommunityController>();
    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ลบโพสต์นี้?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก')),
          FilledButton(key: const Key('confirmDeletePost'), onPressed: () => Navigator.pop(ctx, true), child: const Text('ลบ')),
        ],
      ),
    );
    if (sure == true) await c.delete(id);
  }

  Future<void> _report(String id) async {
    final c = context.read<CommunityController>();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('รายงานโพสต์นี้เพราะ'),
        children: [
          for (final r in communityReportReasons)
            SimpleDialogOption(
              key: Key('reason-$r'),
              onPressed: () => Navigator.pop(ctx, r),
              child: Text(communityReportReasonTh(r)),
            ),
        ],
      ),
    );
    if (reason == null) return;
    final ok = await c.report(id, reason);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'รายงานแล้ว โพสต์นี้จะไม่แสดงให้คุณอีก' : (c.error ?? 'รายงานไม่สำเร็จ'))));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<CommunityController>();
    return Scaffold(
      body: c.loading && c.posts.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: c.load,
              child: c.posts.isEmpty
                  ? ListView(children: [
                      Padding(
                        padding: const EdgeInsets.all(32),
                        child: Center(child: Text(c.error ?? 'ยังไม่มีโพสต์ เป็นคนแรกที่แบ่งปันประสบการณ์')),
                      ),
                    ])
                  : ListView.separated(
                      itemCount: c.posts.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) => _PostTile(
                        post: c.posts[i],
                        onDelete: () => _delete(c.posts[i].id),
                        onReport: () => _report(c.posts[i].id),
                      ),
                    ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('composePostButton'),
        onPressed: _compose,
        icon: const Icon(Icons.edit_outlined),
        label: const Text('โพสต์'),
      ),
    );
  }
}

class _PostTile extends StatelessWidget {
  const _PostTile({required this.post, required this.onDelete, required this.onReport});

  final CommunityPost post;
  final VoidCallback onDelete;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: Key('post-${post.id}'),
      title: Text(post.body),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text([
          '${post.mine ? 'คุณ' : post.authorName} · ${formatDate(post.date)}',
          if (post.tags.isNotEmpty) post.tags.map((t) => '#$t').join(' '),
        ].join('\n')),
      ),
      isThreeLine: post.tags.isNotEmpty,
      trailing: post.mine
          ? IconButton(
              key: Key('delete-${post.id}'), tooltip: 'ลบโพสต์', icon: const Icon(Icons.delete_outline), onPressed: onDelete)
          : IconButton(
              key: Key('report-${post.id}'), tooltip: 'รายงานโพสต์', icon: const Icon(Icons.flag_outlined), onPressed: onReport),
    );
  }
}

class _ComposeSheet extends StatefulWidget {
  const _ComposeSheet({required this.controller});

  final CommunityController controller;

  @override
  State<_ComposeSheet> createState() => _ComposeSheetState();
}

class _ComposeSheetState extends State<_ComposeSheet> {
  final _body = TextEditingController();
  final _tags = TextEditingController();
  bool _busy = false;
  String? _problem;

  @override
  void dispose() {
    _body.dispose();
    _tags.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _body.text.trim();
    if (text.isEmpty) {
      setState(() => _problem = 'กรุณาเขียนข้อความ');
      return;
    }
    if (text.runes.length > 1000) {
      setState(() => _problem = 'ข้อความยาวเกิน 1,000 ตัวอักษร');
      return;
    }
    setState(() {
      _busy = true;
      _problem = null;
    });
    final ok = await widget.controller.post(text, parseTagInput(_tags.text));
    if (!mounted) return;
    // The post exists even if tagging failed (the controller reports that); only a failed publish keeps the sheet open.
    if (ok || widget.controller.lastPostPublished) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _busy = false;
        _problem = widget.controller.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextField(
          key: const Key('postBodyField'),
          controller: _body,
          maxLines: 4,
          maxLength: 1000,
          decoration: const InputDecoration(labelText: 'แบ่งปันประสบการณ์การเดินทาง', border: OutlineInputBorder()),
        ),
        TextField(
          key: const Key('postTagsField'),
          controller: _tags,
          decoration: const InputDecoration(
              labelText: 'แท็ก (ไม่บังคับ คั่นด้วย ,)', hintText: 'เช่น ธรรมชาติ, คาเฟ่', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 8),
        const Text('โพสต์จะแสดงให้สมาชิกทุกคนเห็นทันที และสามารถถูกรายงานได้', style: TextStyle(fontSize: 12)),
        if (_problem != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_problem!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        const SizedBox(height: 12),
        FilledButton(
          key: const Key('submitPostButton'),
          onPressed: _busy ? null : _submit,
          child: Text(_busy ? 'กำลังโพสต์...' : 'โพสต์'),
        ),
      ]),
    );
  }
}
