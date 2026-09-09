import 'package:flutter/material.dart';

import '../models/portal_models.dart';

/// Controller for the demo-only navigation and action feedback.
/// Production data sources can replace these fixture models without changing views.
class DemoController extends ChangeNotifier {
  final Map<DemoPortal, PortalDashboardModel> _portals = {
    DemoPortal.partner: const PortalDashboardModel(
      title: 'Partner Portal',
      eyebrow: 'Siam Stay Hotel · Verified Partner',
      accent: Color(0xFF8B5CF6),
      icon: Icons.storefront_outlined,
      metrics: [
        PortalMetric('Bookings', '128', '+18.4%', Icons.calendar_today_outlined),
        PortalMetric('Revenue', '฿486K', '+12.1%', Icons.payments_outlined),
        PortalMetric('Rating', '4.8', '+0.2', Icons.star_outline),
        PortalMetric('Payout due', '฿92K', 'Friday', Icons.account_balance_wallet_outlined),
      ],
      actions: [
        PortalAction('Manage rooms', 'Availability & pricing', Icons.bed_outlined),
        PortalAction('View bookings', '12 need attention', Icons.receipt_long_outlined),
        PortalAction('Create promotion', 'Fill low-demand dates', Icons.local_offer_outlined),
        PortalAction('Payout report', 'Next payout: Fri', Icons.insights_outlined),
      ],
      activity: [
        PortalActivity('New booking · Deluxe River View', 'Nattapong S. · 3 nights', 'Confirmed'),
        PortalActivity('Rate plan updated', 'Weekend package · Sep 14–15', 'Published'),
        PortalActivity('Guest review received', '“Wonderful team and location.”', '4.8 ★'),
      ],
    ),
    DemoPortal.staff: const PortalDashboardModel(
      title: 'Staff Backoffice',
      eyebrow: 'Customer Operations · Bangkok',
      accent: Color(0xFFF59E0B),
      icon: Icons.support_agent_outlined,
      metrics: [
        PortalMetric('My tasks', '12', '4 urgent', Icons.task_alt_outlined),
        PortalMetric('Open tickets', '34', '−8 today', Icons.confirmation_number_outlined),
        PortalMetric('Avg. SLA', '18m', 'Target < 30m', Icons.timer_outlined),
        PortalMetric('Approvals', '7', 'Action needed', Icons.verified_user_outlined),
      ],
      actions: [
        PortalAction('Support queue', '34 open conversations', Icons.forum_outlined),
        PortalAction('Verify payment', '3 payments pending', Icons.verified_outlined),
        PortalAction('Partner approvals', '4 new applications', Icons.business_center_outlined),
        PortalAction('Daily report', 'Operations summary', Icons.bar_chart_outlined),
      ],
      activity: [
        PortalActivity('Refund request #BK-29401', 'Awaiting payment verification', 'Pending'),
        PortalActivity('Partner submitted documents', 'Chiang Mai Eco Tours', 'Review'),
        PortalActivity('Ticket #SUP-8832 escalated', 'Flight change · SLA 12 minutes', 'Urgent'),
      ],
    ),
    DemoPortal.admin: const PortalDashboardModel(
      title: 'Administration',
      eyebrow: 'Executive Command Center · Live',
      accent: Color(0xFF38BDF8),
      icon: Icons.admin_panel_settings_outlined,
      metrics: [
        PortalMetric('GMV', '฿12.8M', '+22.6%', Icons.account_balance_outlined),
        PortalMetric('Active users', '48,291', '+8.1%', Icons.people_outline),
        PortalMetric('Payment success', '98.7%', '+0.4%', Icons.credit_score_outlined),
        PortalMetric('AI requests', '8,420', '฿3,016 today', Icons.auto_awesome_outlined),
      ],
      actions: [
        PortalAction(
            'Review operations', 'Bookings, refunds & disputes', Icons.fact_check_outlined),
        PortalAction('Manage partners', '18 awaiting verification', Icons.handshake_outlined),
        PortalAction('Content & campaigns', '6 scheduled campaigns', Icons.campaign_outlined),
        PortalAction('System health', 'All services operational', Icons.monitor_heart_outlined),
      ],
      activity: [
        PortalActivity('Payment gateway reconciliation', 'Stripe batch completed', 'Healthy'),
        PortalActivity('Promotion campaign activated', 'Amazing Thailand · 14 days', 'Live'),
        PortalActivity('Security review completed', 'No critical findings', 'Secure'),
      ],
    ),
  };

  PortalDashboardModel portal(DemoPortal target) => _portals[target]!;

  void runAction(BuildContext context, PortalAction action) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${action.label}: demo workflow opened')),
    );
  }
}

enum DemoPortal { partner, staff, admin }
