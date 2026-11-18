import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/util/dates.dart';
import '../../data/models/community_models.dart';
import '../../state/coupons_controller.dart';

/// Saved coupons. Saving a code does not reduce any price: the booking flow does not use coupons yet.
class CouponsScreen extends StatefulWidget {
  const CouponsScreen({super.key});

  @override
  State<CouponsScreen> createState() => _CouponsScreenState();
}

class _CouponsScreenState extends State<CouponsScreen> {
  final _code = TextEditingController();
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<CouponsController>().load();
    });
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _claim() async {
    final ok = await context.read<CouponsController>().claim(_code.text);
    if (!mounted) return;
    setState(() => _saved = ok);
    if (ok) _code.clear();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<CouponsController>();
    return Scaffold(
      appBar: AppBar(title: const Text('คูปองของฉัน')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            key: const Key('couponNotice'),
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Text('ตอนนี้บันทึกคูปองไว้ดูได้อย่างเดียว ยังใช้ลดราคาในแอปไม่ได้'),
            ),
          ),
          const SizedBox(height: 12),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: TextField(
                key: const Key('couponCodeField'),
                controller: _code,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'รหัสคูปอง', border: OutlineInputBorder()),
                onChanged: (_) => setState(() => _saved = false),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(key: const Key('claimCouponButton'), onPressed: _claim, child: const Text('บันทึก')),
          ]),
          if (c.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(c.error!, key: const Key('couponError'), style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          if (_saved) const Padding(padding: EdgeInsets.only(top: 8), child: Text('บันทึกคูปองแล้ว', key: Key('couponSaved'))),
          const SizedBox(height: 16),
          if (c.loading && c.coupons.isEmpty)
            const Center(child: CircularProgressIndicator())
          else if (c.coupons.isEmpty)
            const Center(child: Text('ยังไม่มีคูปองที่บันทึกไว้'))
          else
            for (final k in c.coupons) _CouponTile(coupon: k),
        ],
      ),
    );
  }
}

class _CouponTile extends StatelessWidget {
  const _CouponTile({required this.coupon});

  final SavedCoupon coupon;

  @override
  Widget build(BuildContext context) {
    final lines = <String>[
      if (coupon.valueLabel.isNotEmpty) coupon.valueLabel,
      if (coupon.validUntil.isNotEmpty) 'ใช้ได้ถึง ${formatDate(coupon.validUntil)}',
    ];
    return Card(
      child: ListTile(
        key: Key('coupon-${coupon.code}'),
        leading: const Icon(Icons.local_offer_outlined),
        title: Text(coupon.title.isEmpty ? coupon.code : '${coupon.title} (${coupon.code})'),
        subtitle: lines.isEmpty ? null : Text(lines.join(' · ')),
        trailing: Chip(
          label: Text(couponStateTh(coupon.state)),
          backgroundColor: coupon.isActive ? null : Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
      ),
    );
  }
}
