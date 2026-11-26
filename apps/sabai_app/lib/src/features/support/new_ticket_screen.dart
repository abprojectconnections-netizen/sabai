import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/support_models.dart';
import '../../state/tickets_controller.dart';

/// Opens a support request. Pops `true` once the server has accepted it.
class NewTicketScreen extends StatefulWidget {
  const NewTicketScreen({super.key});

  @override
  State<NewTicketScreen> createState() => _NewTicketScreenState();
}

class _NewTicketScreenState extends State<NewTicketScreen> {
  final _subject = TextEditingController();
  final _description = TextEditingController();
  String _category = 'OTHER';
  String? _error;
  bool _sending = false;

  @override
  void dispose() {
    _subject.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final subject = _subject.text.trim();
    final description = _description.text.trim();
    if (subject.runes.length < 3) {
      setState(() => _error = 'หัวข้อต้องยาวอย่างน้อย 3 ตัวอักษร');
      return;
    }
    if (description.isEmpty) {
      setState(() => _error = 'กรุณาอธิบายปัญหา');
      return;
    }
    final c = context.read<TicketsController>();
    final nav = Navigator.of(context);
    setState(() {
      _error = null;
      _sending = true;
    });
    final id = await c.create(subject: subject, category: _category, description: description);
    if (!mounted) return;
    if (id == null) {
      setState(() {
        _sending = false;
        _error = c.actionError ?? 'ส่งคำขอไม่สำเร็จ';
      });
      return;
    }
    nav.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('แจ้งปัญหา')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                key: const Key('ticketSubjectField'),
                controller: _subject,
                maxLength: 120,
                decoration: const InputDecoration(labelText: 'หัวข้อ'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                key: const Key('ticketCategoryField'),
                value: _category,
                decoration: const InputDecoration(labelText: 'หมวดหมู่'),
                items: [for (final e in supportCategoriesTh.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                onChanged: (v) => setState(() => _category = v ?? 'OTHER'),
              ),
              const SizedBox(height: 16),
              TextField(
                key: const Key('ticketDescriptionField'),
                controller: _description,
                maxLength: 2000,
                maxLines: 6,
                decoration: const InputDecoration(labelText: 'รายละเอียด', alignLabelWithHint: true),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(_error!, key: const Key('ticketFormError'), style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
              FilledButton(
                key: const Key('submitTicket'),
                onPressed: _sending ? null : _submit,
                child: _sending ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('ส่งคำขอ'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
