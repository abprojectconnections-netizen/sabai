import 'package:flutter/material.dart';

/// Immutable presentation data for the non-consumer portals in the demo.
class PortalDashboardModel {
  const PortalDashboardModel({
    required this.title,
    required this.eyebrow,
    required this.accent,
    required this.icon,
    required this.metrics,
    required this.actions,
    required this.activity,
  });

  final String title;
  final String eyebrow;
  final Color accent;
  final IconData icon;
  final List<PortalMetric> metrics;
  final List<PortalAction> actions;
  final List<PortalActivity> activity;
}

class PortalMetric {
  const PortalMetric(this.label, this.value, this.change, this.icon);
  final String label;
  final String value;
  final String change;
  final IconData icon;
}

class PortalAction {
  const PortalAction(this.label, this.subtitle, this.icon);
  final String label;
  final String subtitle;
  final IconData icon;
}

class PortalActivity {
  const PortalActivity(this.title, this.subtitle, this.status);
  final String title;
  final String subtitle;
  final String status;
}
