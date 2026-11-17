import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/util/dates.dart';
import '../../state/reviews_controller.dart';

class MyReviewsScreen extends StatefulWidget {
  const MyReviewsScreen({super.key});

  @override
  State<MyReviewsScreen> createState() => _MyReviewsScreenState();
}

class _MyReviewsScreenState extends State<MyReviewsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ReviewsController>().load();
    });
  }

  Future<void> _delete(String id) async {
    final c = context.read<ReviewsController>();
    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ลบรีวิวนี้?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก')),
          FilledButton(key: const Key('confirmDeleteReview'), onPressed: () => Navigator.pop(ctx, true), child: const Text('ลบ')),
        ],
      ),
    );
    if (sure == true) await c.delete(id);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ReviewsController>();
    return Scaffold(
      appBar: AppBar(title: const Text('รีวิวของฉัน')),
      body: c.loading && c.reviews.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : c.reviews.isEmpty
              ? Center(child: Text(c.error ?? 'ยังไม่มีรีวิว เขียนรีวิวได้จากหน้าการจอง'))
              : ListView.separated(
                  itemCount: c.reviews.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final r = c.reviews[i];
                    return ListTile(
                      key: Key('review-${r.id}'),
                      leading: const Icon(Icons.star, color: Colors.amber),
                      title: Text('${r.rating.toStringAsFixed(r.rating == r.rating.roundToDouble() ? 0 : 1)} ดาว'
                          '${r.body.isEmpty ? '' : ' · ${r.body}'}'),
                      subtitle: Text([
                        formatDate(r.date),
                        if (r.tags.isNotEmpty) r.tags.map((t) => '#$t').join(' '),
                      ].join('\n')),
                      isThreeLine: r.tags.isNotEmpty,
                      trailing: IconButton(
                        tooltip: 'ลบรีวิว',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _delete(r.id),
                      ),
                    );
                  },
                ),
    );
  }
}
