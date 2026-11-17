import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/util/format.dart';
import '../../data/models/models.dart';
import '../../state/app_state.dart';
import '../../state/reviews_controller.dart';
import '../reviews/review_form_screen.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ReviewsController>().ensureLoaded();
    });
  }


  static String statusLabel(BookingStatus s) => switch (s) {
        BookingStatus.pending => 'รอชำระเงิน',
        BookingStatus.confirmed => 'ยืนยันแล้ว',
        BookingStatus.completed => 'เสร็จสิ้น',
        BookingStatus.cancelled => 'ยกเลิก',
        BookingStatus.refunded => 'คืนเงินแล้ว',
        BookingStatus.unknown => 'ไม่ทราบสถานะ',
      };

  Future<void> _cancel(BuildContext context, Booking b) async {
    final state = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ขอคืนเงิน'),
        content: Text('ส่งคำขอคืนเงินสำหรับ ${b.code}? เซิร์ฟเวอร์จะคำนวณยอดคืนตามนโยบายยกเลิก'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ไม่ใช่')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('ยืนยัน')),
        ],
      ),
    );
    if (ok != true) return;
    final r = await state.requestRefund(b);
    messenger.showSnackBar(SnackBar(
      content: Text(r != null
          ? 'ส่งคำขอแล้ว ยอดคืน ${formatBaht(r.calculatedAmount)}'
          : (state.error ?? 'ทำรายการไม่สำเร็จ')),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final reviews = context.watch<ReviewsController>();
    if (state.bookings.isEmpty) return const Center(child: Text('ยังไม่มีการจอง'));
    return RefreshIndicator(
      onRefresh: state.refreshAccount,
      child: ListView.separated(
        itemCount: state.bookings.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final b = state.bookings[i];
          final canReview = b.canRequestRefund && !reviews.hasReviewedBooking(b.id);
          return ListTile(
            isThreeLine: b.canRequestRefund,
            title: Text(b.title),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${b.code} · ${statusLabel(b.status)}'),
                if (b.canRequestRefund)
                  Wrap(
                    spacing: 8,
                    children: [
                      if (canReview)
                        TextButton(
                          key: Key('review-${b.id}'),
                          style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: EdgeInsets.zero),
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(builder: (_) => ReviewFormScreen(booking: b)),
                          ),
                          child: const Text('เขียนรีวิว'),
                        ),
                      TextButton(
                        key: Key('refund-${b.id}'),
                        style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: EdgeInsets.zero),
                        onPressed: () => _cancel(context, b),
                        child: const Text('ขอคืนเงิน'),
                      ),
                    ],
                  ),
              ],
            ),
            trailing: Text(formatBaht(b.amount)),
          );
        },
      ),
    );
  }
}
