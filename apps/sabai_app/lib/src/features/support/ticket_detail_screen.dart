import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/support_models.dart';
import '../../state/tickets_controller.dart';

/// One support request and its conversation. Staff replies appear as "เจ้าหน้าที่" without a name, because the server does not
/// reveal who wrote them.
class TicketDetailScreen extends StatefulWidget {
  const TicketDetailScreen({super.key, required this.ticketId});

  final String ticketId;

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen> {
  final _reply = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<TicketsController>().openDetail(widget.ticketId);
    });
  }

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _reply.text.trim();
    if (text.isEmpty) return;
    final c = context.read<TicketsController>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _sending = true);
    final ok = await c.reply(widget.ticketId, text);
    if (!mounted) return;
    setState(() => _sending = false);
    if (ok) {
      _reply.clear();
    } else {
      messenger.showSnackBar(SnackBar(content: Text(c.actionError ?? 'ส่งไม่สำเร็จ')));
    }
  }

  Future<void> _close() async {
    final c = context.read<TicketsController>();
    final messenger = ScaffoldMessenger.of(context);
    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ปิดคำขอนี้?'),
        content: const Text('เมื่อปิดแล้วจะตอบเพิ่มไม่ได้ หากยังมีปัญหาต้องเปิดคำขอใหม่'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('ยกเลิก')),
          FilledButton(key: const Key('confirmCloseTicket'), onPressed: () => Navigator.of(ctx).pop(true), child: const Text('ปิดคำขอ')),
        ],
      ),
    );
    if (sure != true) return;
    final ok = await c.close(widget.ticketId);
    messenger.showSnackBar(SnackBar(content: Text(ok ? 'ปิดคำขอแล้ว' : (c.actionError ?? 'ทำรายการไม่สำเร็จ'))));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<TicketsController>();
    final d = c.detail;
    Widget body;
    if (d == null) {
      body = c.detailError != null
          ? Center(
              child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(c.detailError!, key: const Key('ticketDetailError')),
                    const SizedBox(height: 12),
                    OutlinedButton(onPressed: () => c.openDetail(widget.ticketId), child: const Text('ลองอีกครั้ง')),
                  ])))
          : const Center(child: CircularProgressIndicator());
    } else {
      final t = d.ticket;
      body = Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(t.subject, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  [ticketCategoryLabelTh(t.category), if (t.bookingCode.isNotEmpty) 'การจอง ${t.bookingCode}', ticketDate(t.createdAt)].join(' · '),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Chip(key: const Key('ticketStatus'), label: Text(ticketStatusLabelTh(t.status))),
                const SizedBox(height: 8),
                Text(d.description, key: const Key('ticketDescription')),
                const Divider(height: 32),
                if (d.messages.isEmpty) const Text('ยังไม่มีข้อความตอบกลับ', key: Key('noMessages')),
                for (final m in d.messages) _Bubble(message: m),
              ],
            ),
          ),
          if (t.isClosed)
            const Padding(padding: EdgeInsets.all(16), child: Text('คำขอนี้ปิดแล้ว หากยังมีปัญหาให้แจ้งใหม่', key: Key('ticketClosedNote')))
          else
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            key: const Key('replyField'),
                            controller: _reply,
                            maxLength: 2000,
                            minLines: 1,
                            maxLines: 4,
                            decoration: const InputDecoration(labelText: 'ตอบกลับ', counterText: ''),
                          ),
                        ),
                        IconButton(key: const Key('sendReply'), onPressed: _sending ? null : _send, icon: const Icon(Icons.send)),
                      ],
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(key: const Key('closeTicketButton'), onPressed: _close, child: const Text('ปิดคำขอนี้')),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('รายละเอียดคำขอ')),
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 800), child: body)),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final SupportMessage message;

  @override
  Widget build(BuildContext context) {
    final staff = message.fromStaff;
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: staff ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        key: Key('msg-${message.id}'),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxWidth: 520),
        decoration: BoxDecoration(
          color: staff ? scheme.secondaryContainer : scheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(staff ? 'เจ้าหน้าที่' : 'คุณ', style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 2),
            Text(message.body),
          ],
        ),
      ),
    );
  }
}
