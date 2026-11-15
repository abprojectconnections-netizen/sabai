import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/util/format.dart';
import '../../state/app_state.dart';

/// Read-only: the wallet holds refund credit only; it cannot be topped up, transferred or used to pay.
class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final w = context.watch<AppState>().wallet;
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('เครดิตเงินคืน'),
              Text(formatBaht(w.balance), style: Theme.of(context).textTheme.headlineMedium),
            ],
          ),
        ),
        const Divider(height: 1),
        if (w.transactions.isEmpty)
          const Padding(padding: EdgeInsets.all(16), child: Text('ยังไม่มีรายการ')),
        for (final t in w.transactions)
          ListTile(
            title: Text(t.label),
            subtitle: Text(t.date),
            trailing: Text('${t.isCredit ? '+' : '-'}${formatBaht(t.amount)}'),
          ),
      ],
    );
  }
}
