import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/models.dart';
import '../../state/reviews_controller.dart';

/// Review one of the user's own bookings (rating 1-5 in half steps, optional text and tags).
class ReviewFormScreen extends StatefulWidget {
  const ReviewFormScreen({super.key, required this.booking});

  final Booking booking;

  @override
  State<ReviewFormScreen> createState() => _ReviewFormScreenState();
}

class _ReviewFormScreenState extends State<ReviewFormScreen> {
  double _rating = 0;
  final _body = TextEditingController();
  final _tags = TextEditingController();
  bool _saving = false;
  String? _problem;

  @override
  void dispose() {
    _body.dispose();
    _tags.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_rating < 1) return setState(() => _problem = 'กรุณาให้คะแนนอย่างน้อย 1 ดาว');
    final tags = parseTagInput(_tags.text);
    if (tags.length > 10) return setState(() => _problem = 'ใส่แท็กได้ไม่เกิน 10 แท็ก');
    final c = context.read<ReviewsController>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _saving = true;
      _problem = null;
    });
    final ok = await c.reviewBooking(widget.booking.id, _rating, _body.text, tags);
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      navigator.pop();
    } else if (c.hasReviewedBooking(widget.booking.id)) {
      // Saved, but a follow-up step (tags) failed: keep the user informed and leave the form.
      messenger.showSnackBar(SnackBar(content: Text(c.error ?? '')));
      navigator.pop();
    } else {
      setState(() => _problem = c.error ?? 'บันทึกรีวิวไม่สำเร็จ');
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;
    return Scaffold(
      appBar: AppBar(title: const Text('เขียนรีวิว')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(b.title, style: Theme.of(context).textTheme.titleLarge),
          Text(b.code),
          const SizedBox(height: 16),
          const Text('ให้คะแนน'),
          Row(
            children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  key: Key('star$i'),
                  tooltip: '$i ดาว',
                  onPressed: () => setState(() => _rating = i.toDouble()),
                  icon: Icon(_rating >= i ? Icons.star : Icons.star_border, color: Colors.amber),
                ),
            ],
          ),
          TextField(
            key: const Key('reviewBodyField'),
            controller: _body,
            maxLines: 4,
            maxLength: 2000,
            decoration: const InputDecoration(labelText: 'ความเห็น (ไม่บังคับ)'),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('reviewTagsField'),
            controller: _tags,
            decoration: const InputDecoration(
              labelText: 'แท็ก (คั่นด้วยจุลภาค)',
              helperText: 'เช่น ธรรมชาติ, คาเฟ่ — สูงสุด 10 แท็ก แท็กละไม่เกิน 30 ตัวอักษร',
            ),
          ),
          if (_problem != null) ...[
            const SizedBox(height: 12),
            Text(_problem!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('submitReviewButton'),
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'กำลังบันทึก…' : 'ส่งรีวิว'),
          ),
        ],
      ),
    );
  }
}
