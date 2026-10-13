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
        backgroundColor: const Color(0xFFF7F8F5),
        foregroundColor: const Color(0xFF16241F),
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFF7F8F5),
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final List<PortalWorkItem> workItems = controller.workItems(portal);
          final int openCount = workItems.where((item) => !item.isCompleted).length;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Text(model.eyebrow,
                  style: TextStyle(color: model.accent, fontWeight: FontWeight.w700)),
              const SizedBox(height: 5),
              const Text('ภาพรวมการดำเนินงาน',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text('ข้อมูลตัวอย่างสำหรับ MVP · ยังไม่เชื่อมระบบ production',
                  style: TextStyle(fontSize: 11, color: Color(0xFF64716C))),
              const SizedBox(height: 18),
              LayoutBuilder(builder: (context, constraints) {
                final columns = constraints.maxWidth >= 760 ? 4 : 2;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: model.metrics.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: columns == 2 ? 1.35 : 1.5,
                  ),
                  itemBuilder: (context, index) =>
                      _MetricCard(metric: model.metrics[index], accent: model.accent),
                );
              }),
              const SizedBox(height: 24),
              Row(children: [
                const Expanded(
                    child: Text('งานที่ต้องดำเนินการ',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
                Text('$openCount ค้าง',
                    style:
                        TextStyle(color: model.accent, fontSize: 12, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 10),
              ...model.actions.map((action) => _ActionTile(
                    action: action,
                    accent: model.accent,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => _PortalWorkQueueScreen(
                        portal: portal,
                        controller: controller,
                        title: action.label,
                      ),
                    )),
                  )),
              const SizedBox(height: 22),
              const Text('รายการในคิว',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              ...workItems.map((item) => _WorkItemTile(
                    item: item,
                    accent: model.accent,
                    onAction: item.isCompleted
                        ? null
                        : () => _confirmWorkItem(context, portal, controller, item),
                  )),
              const SizedBox(height: 22),
              const Text('กิจกรรมตัวอย่าง',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              ...model.activity.map((item) => _ActivityTile(item: item, accent: model.accent)),
            ],
          );
        },
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE3E8E3))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(metric.icon, color: accent, size: 19),
          const Spacer(),
          Text(metric.value,
              style: const TextStyle(
                  fontSize: 19, fontWeight: FontWeight.w800, color: Color(0xFF16241F))),
          Text(metric.label, style: const TextStyle(color: Color(0xFF64716C), fontSize: 11)),
          Text(metric.change,
              style: TextStyle(color: accent, fontSize: 10, fontWeight: FontWeight.w700)),
        ]),
      );
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.action, required this.accent, required this.onTap});
  final PortalAction action;
  final Color accent;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE3E8E3)),
        ),
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
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
        decoration:
            const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE3E8E3)))),
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
            Text(item.subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF64716C))),
          ])),
          Text(item.status,
              style: TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.w600)),
        ]),
      );
}

class _PortalWorkQueueScreen extends StatelessWidget {
  const _PortalWorkQueueScreen({
    required this.portal,
    required this.controller,
    required this.title,
  });

  final DemoPortal portal;
  final DemoController controller;
  final String title;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFF7F8F5),
        appBar: AppBar(
          title: Text(title),
          backgroundColor: const Color(0xFFF7F8F5),
          foregroundColor: const Color(0xFF16241F),
        ),
        body: AnimatedBuilder(
          animation: controller,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(_description, style: const TextStyle(color: Color(0xFF64716C))),
              const SizedBox(height: 6),
              const Text('ข้อมูลตัวอย่างสำหรับ MVP',
                  style: TextStyle(fontSize: 11, color: Color(0xFF8A948F))),
              const SizedBox(height: 16),
              for (final item in controller.workItems(portal))
                _WorkItemTile(
                  item: item,
                  accent: controller.portal(portal).accent,
                  onAction: item.isCompleted
                      ? null
                      : () => _confirmWorkItem(context, portal, controller, item),
                ),
            ],
          ),
        ),
      );

  String get _description {
    if (portal == DemoPortal.partner) {
      return 'จัดการการจอง ราคา และโปรโมชันของพาร์ทเนอร์';
    }
    if (portal == DemoPortal.staff) {
      return 'ตรวจสอบการชำระ พาร์ทเนอร์ และเคสบริการลูกค้า';
    }
    return 'ติดตามข้อพิพาท พาร์ทเนอร์ และแคมเปญของระบบ';
  }
}

Future<void> _confirmWorkItem(
  BuildContext context,
  DemoPortal portal,
  DemoController controller,
  PortalWorkItem item,
) async {
  final bool? confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(item.actionLabel),
      content: Text('ยืนยันการเปลี่ยนสถานะ “${item.title}” เป็น “${item.nextStatus}” หรือไม่?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('ยกเลิก'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('ยืนยัน'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) {
    return;
  }
  final bool updated = controller.advanceWorkItem(portal, item.id);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        updated ? 'อัปเดตเป็น “${item.nextStatus}” แล้ว' : 'รายการนี้เปลี่ยนสถานะแล้ว',
      ),
    ),
  );
}

class _WorkItemTile extends StatelessWidget {
  const _WorkItemTile({
    required this.item,
    required this.accent,
    required this.onAction,
  });

  final PortalWorkItem item;
  final Color accent;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE3E8E3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: accent.withOpacity(.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(item.icon, color: accent, size: 19),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 3),
                      Text(item.description,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64716C))),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _StatusBadge(
                  label: item.status,
                  accent: item.isCompleted ? const Color(0xFF28744D) : accent,
                ),
              ],
            ),
            const SizedBox(height: 9),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onAction,
                icon: Icon(
                  item.isCompleted ? Icons.check_circle_outline : Icons.arrow_forward_rounded,
                  size: 16,
                ),
                label: Text(item.isCompleted ? 'ดำเนินการแล้ว' : item.actionLabel),
                style: TextButton.styleFrom(
                  foregroundColor: item.isCompleted ? const Color(0xFF28744D) : accent,
                ),
              ),
            ),
          ],
        ),
      );
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.accent});

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: accent.withOpacity(.1),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          label,
          style: TextStyle(color: accent, fontSize: 10, fontWeight: FontWeight.w700),
        ),
      );
}
