import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/util/format.dart';
import '../../data/models/models.dart';
import '../../state/app_state.dart';

class MyBookingsScreen extends StatelessWidget {
  const MyBookingsScreen({super.key});

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
    if (state.bookings.isEmpty) return const Center(child: Text('ยังไม่มีการจอง'));
    return RefreshIndicator(
      onRefresh: state.refreshAccount,
      child: ListView.separated(
        itemCount: state.bookings.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final b = state.bookings[i];
          return ListTile(
            title: Text(b.title),
            subtitle: Text('${b.code} · ${statusLabel(b.status)}'),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(formatBaht(b.amount)),
                if (b.canRequestRefund)
                  GestureDetector(
                    onTap: () => _cancel(context, b),
                    child: Text('ขอคืนเงิน',
                        style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
