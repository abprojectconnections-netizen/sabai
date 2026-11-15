import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/util/format.dart';
import '../../data/models/models.dart';
import '../../state/app_state.dart';
import '../auth/login_screen.dart';
import '../booking/checkout_screen.dart';

class ListingDetailScreen extends StatelessWidget {
  const ListingDetailScreen({super.key, required this.listing});

  final Listing listing;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: Text(listing.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(listing.title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(listing.location),
          const SizedBox(height: 16),
          Text('ราคาเริ่มต้น ${formatBaht(listing.price)}',
              style: Theme.of(context).textTheme.titleLarge),
          Text(listing.isAvailable ? 'วันที่ว่างถัดไป ${listing.serviceDate}' : 'เต็มแล้ว'),
          const SizedBox(height: 4),
          const Text('ราคาสุดท้ายคำนวณโดยเซิร์ฟเวอร์ ไม่มีค่าบริการเพิ่ม'),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            key: const Key('bookButton'),
            onPressed: !listing.isAvailable
                ? null
                : () => Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => state.signedIn
                          ? CheckoutScreen(listing: listing)
                          : const LoginScreen(),
                    )),
            child: Text(state.signedIn ? 'จองและชำระเงิน' : 'เข้าสู่ระบบเพื่อจอง'),
          ),
        ),
      ),
    );
  }
}
