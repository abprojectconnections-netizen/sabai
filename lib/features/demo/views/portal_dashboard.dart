import 'package:flutter/material.dart';

import '../controllers/demo_controller.dart';
import '../models/portal_models.dart';

class PortalDashboard extends StatelessWidget {
  const PortalDashboard({super.key, required this.portal, required this.controller});

  final DemoPortal portal;
  final DemoController controller;

  @override
  Widget build(BuildContext context) {
    final PortalDashboardModel model = controller.portal(portal);
    return Scaffold(
      appBar: AppBar(
        title: Text(model.title),
        backgroundColor: const Color(0xFF0A1628),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(model.eyebrow, style: TextStyle(color: model.accent, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          const Text('Overview', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: model.metrics.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.25,
            ),
            itemBuilder: (context, index) =>
                _MetricCard(metric: model.metrics[index], accent: model.accent),
          ),
          const SizedBox(height: 28),
          const Text('Quick actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ...model.actions.map((action) => _ActionTile(
                action: action,
                accent: model.accent,
                onTap: () => controller.runAction(context, action),
              )),
          const SizedBox(height: 20),
          const Text('Recent activity',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ...model.activity.map((item) => _ActivityTile(item: item, accent: model.accent)),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric, required this.accent});
  final PortalMetric metric;
  final Color accent;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: const Color(0xFF162035),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(metric.icon, color: accent, size: 19),
          const Spacer(),
          Text(metric.value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          Text(metric.label, style: const TextStyle(color: Color(0xFFB0C4DE), fontSize: 11)),
          Text(metric.change,
              style: TextStyle(color: accent, fontSize: 10, fontWeight: FontWeight.w600)),
        ]),
      );
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.action, required this.accent, required this.onTap});
  final PortalAction action;
  final Color accent;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
        color: const Color(0xFF162035),
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          onTap: onTap,
          leading: CircleAvatar(
              backgroundColor: accent.withOpacity(.16), child: Icon(action.icon, color: accent)),
          title: Text(action.label, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(action.subtitle),
          trailing: const Icon(Icons.chevron_right),
        ),
      );
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.item, required this.accent});
  final PortalActivity item;
  final Color accent;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white12))),
        child: Row(children: [
          Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.title, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 3),
            Text(item.subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFFB0C4DE))),
          ])),
          Text(item.status,
              style: TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.w600)),
        ]),
      );
}
