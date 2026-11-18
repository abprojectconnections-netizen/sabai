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

  Future<void> _pay({bool simulateFailure = false}) async {
    final r = await context.read<AppState>().pay(widget.listing, simulateFailure: simulateFailure);
    if (mounted) setState(() => _result = r);
  }

  Future<void> _retry({bool simulateFailure = false}) {
    setState(() => _result = null);
    return _pay(simulateFailure: simulateFailure);
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
              )
            else if (state.repository.canSimulatePayment)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('SANDBOX: ผู้ให้บริการชำระเงินเป็นระบบจำลองบนเซิร์ฟเวอร์ทดสอบ ไม่มีการตัดเงินจริง',
                    key: Key('sandboxNotice')),
              ),
          ] else if (result.paymentFailed) ...[
            Text('การชำระเงินไม่สำเร็จ', key: const Key('paymentFailed'), style: Theme.of(context).textTheme.headlineSmall),
            Text('รหัสการจอง ${result.bookingCode}'),
            const Text('การจองนี้ยังไม่ได้ชำระและจะหมดอายุเอง ไม่มีการตัดเงิน ลองชำระใหม่ได้ (จะสร้างรายการจองใหม่)'),
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
          child: result == null || result.paymentFailed
              ? Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  FilledButton(
                    key: const Key('payButton'),
                    onPressed: state.busy ? null : () => _retry(),
                    child: Text(state.busy ? 'กำลังดำเนินการ…' : (result == null ? 'ชำระเงิน' : 'ลองชำระใหม่')),
                  ),
                  if (state.repository.canSimulatePayment)
                    TextButton(
                      key: const Key('simulateFailButton'),
                      onPressed: state.busy ? null : () => _retry(simulateFailure: true),
                      child: const Text('ทดสอบ: จำลองชำระเงินไม่สำเร็จ'),
                    ),
                ])
              : FilledButton(
                  onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                  child: const Text('กลับหน้าหลัก'),
                ),
        ),
      ),
    );
  }
}
