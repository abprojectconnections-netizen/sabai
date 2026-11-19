import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../auth/login_screen.dart';
import '../coupons/coupons_screen.dart';
import '../reviews/my_reviews_screen.dart';
import '../staff/moderation_screen.dart';
import '../support/help_screen.dart';
import '../settings/settings_screen.dart';
import '../wallet/wallet_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _open(BuildContext context, String title, Widget body) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => Scaffold(appBar: AppBar(title: Text(title)), body: body),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = state.session;
    final name = s == null ? '' : (s.displayName.isEmpty ? s.email : s.displayName);
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: s == null
              ? Row(children: [
                  const CircleAvatar(radius: 28, child: Icon(Icons.person_outline)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
                      ),
                      child: const Text('เข้าสู่ระบบ / สมัครสมาชิก'),
                    ),
                  ),
                ])
              : Row(children: [
                  CircleAvatar(radius: 28, child: Text(name.isEmpty ? '?' : name.characters.first.toUpperCase())),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(name, key: const Key('profileName'), style: Theme.of(context).textTheme.titleLarge),
                      if (s.email.isNotEmpty) Text(s.email),
                    ]),
                  ),
                ]),
        ),
        const Divider(height: 1),
        if (state.signedIn)
          ListTile(
            leading: const Icon(Icons.account_balance_wallet_outlined),
            title: const Text('กระเป๋าเงิน'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _open(context, 'กระเป๋าเงิน', const WalletScreen()),
          ),
        if (state.signedIn)
          ListTile(
            key: const Key('myReviewsTile'),
            leading: const Icon(Icons.star_outline),
            title: const Text('รีวิวของฉัน'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const MyReviewsScreen())),
          ),
        if (state.signedIn && state.account.canModerateCommunity)
          ListTile(
            key: const Key('moderationTile'),
            leading: const Icon(Icons.shield_outlined),
            title: const Text('ตรวจสอบรายงานชุมชน (เจ้าหน้าที่)'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ModerationScreen())),
          ),
        if (state.signedIn)
          ListTile(
            key: const Key('couponsTile'),
            leading: const Icon(Icons.local_offer_outlined),
            title: const Text('คูปองของฉัน'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const CouponsScreen())),
          ),
        ListTile(
          key: const Key('helpTile'),
          leading: const Icon(Icons.help_outline),
          title: const Text('ช่วยเหลือ'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const HelpScreen())),
        ),
        ListTile(
          key: const Key('settingsTile'),
          leading: const Icon(Icons.settings_outlined),
          title: const Text('การตั้งค่า'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen())),
        ),
        if (state.signedIn) ...[
          const Divider(height: 1),
          ListTile(
            key: const Key('logoutTile'),
            leading: Icon(Icons.logout, color: Theme.of(context).colorScheme.error),
            title: Text('ออกจากระบบ', style: TextStyle(color: Theme.of(context).colorScheme.error)),
            onTap: state.logout,
          ),
        ],
      ],
    );
  }
}
