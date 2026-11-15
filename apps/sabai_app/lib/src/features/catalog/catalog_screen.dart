import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/util/format.dart';
import '../../data/models/models.dart';
import '../../state/app_state.dart';
import 'listing_detail_screen.dart';

class CatalogScreen extends StatelessWidget {
  const CatalogScreen({super.key});

  static IconData iconFor(ListingType t) => switch (t) {
        ListingType.hotel => Icons.hotel,
        ListingType.flight => Icons.flight,
        ListingType.attraction => Icons.attractions,
      };

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (state.listings.isEmpty) {
      return Center(child: Text(state.error ?? 'ยังไม่มีรายการให้จอง'));
    }
    return ListView.separated(
      itemCount: state.listings.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final l = state.listings[i];
        return ListTile(
          leading: Icon(iconFor(l.type)),
          title: Text(l.title),
          subtitle: Text(l.location),
          trailing: Text(l.isAvailable ? 'เริ่มต้น ${formatBaht(l.price)}' : 'เต็ม'),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => ListingDetailScreen(listing: l)),
          ),
        );
      },
    );
  }
}
