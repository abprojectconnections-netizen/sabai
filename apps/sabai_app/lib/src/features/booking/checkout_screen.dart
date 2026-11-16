import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/util/format.dart';
import '../../data/models/models.dart';
import '../../state/app_state.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key, required this.listing});

  final Listing listing;

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  CheckoutResult? _result;

  Future<void> _pay() async {
    final r = await context.read<AppState>().pay(widget.listing);
    if (mounted) setState(() => _result = r);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final l = widget.listing;
    final result = _result;
    return Scaffold(
      appBar: AppBar(title: const Text('สรุปการจอง')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l.title, style: Theme.of(context).textTheme.titleLarge),
          Text('วันที่ใช้บริการ ${l.serviceDate} · 1 หน่วย'),
          const SizedBox(height: 16),
          if (result == null) ...[
            Text('ยอดที่แสดง ${formatBaht(l.price)}'),
            const Text('ยอดชำระจริงมาจากเซิร์ฟเวอร์หลังสร้างรายการจอง'),
            if (!state.repository.isRealCheckout)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('โหมดทดลอง: การชำระเงินเป็นการจำลองในเครื่อง ไม่มีการตัดเงิน'),
              ),
          ] else if (result.isPaid) ...[
            Text('จองสำเร็จ', style: Theme.of(context).textTheme.headlineSmall),
            Text('รหัสการจอง ${result.bookingCode}', key: const Key('bookingCode')),
            Text('ยอดชำระ ${formatBaht(result.payableTotal)}'),
          ] else ...[
            Text('รอการชำระเงิน', style: Theme.of(context).textTheme.headlineSmall),
            Text('รหัสการจอง ${result.bookingCode}'),
            const Text('การจองจะยืนยันเมื่อผู้ให้บริการชำระเงินแจ้งผลกลับมา ดูสถานะที่แท็บ "การจอง"'),
          ],
          if (state.error != null) ...[
            const SizedBox(height: 12),
            Text(state.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: result == null
              ? FilledButton(
                  key: const Key('payButton'),
                  onPressed: state.busy ? null : _pay,
                  child: Text(state.busy ? 'กำลังดำเนินการ…' : 'ชำระเงิน'),
                )
              : FilledButton(
                  onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                  child: const Text('กลับหน้าหลัก'),
                ),
        ),
      ),
    );
  }
}
