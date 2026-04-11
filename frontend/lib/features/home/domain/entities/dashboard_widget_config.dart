/// Configuration for a single dashboard widget (visibility + order).
class DashboardWidgetConfig {
  final String id;
  final String name;
  final String icon;
  final bool enabled;
  final int order;

  const DashboardWidgetConfig({
    required this.id,
    required this.name,
    required this.icon,
    this.enabled = true,
    required this.order,
  });

  DashboardWidgetConfig copyWith({bool? enabled, int? order}) =>
      DashboardWidgetConfig(
        id: id,
        name: name,
        icon: icon,
        enabled: enabled ?? this.enabled,
        order: order ?? this.order,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'icon': icon,
        'enabled': enabled,
        'order': order,
      };

  factory DashboardWidgetConfig.fromJson(Map<String, dynamic> json) =>
      DashboardWidgetConfig(
        id: json['id'] as String,
        name: json['name'] as String,
        icon: json['icon'] as String,
        enabled: json['enabled'] as bool? ?? true,
        order: json['order'] as int? ?? 0,
      );
}

/// Default dashboard widget configuration.
/// Order matters; asset_balance defaults to OFF.
const defaultDashboardWidgets = [
  DashboardWidgetConfig(
    id: 'monthly_summary',
    name: '\uc6d4\uac04 \uc694\uc57d',
    icon: 'account_balance_wallet',
    enabled: true,
    order: 0,
  ),
  DashboardWidgetConfig(
    id: 'budget_usage',
    name: '\uc608\uc0b0 \uc0ac\uc6a9 \ud604\ud669',
    icon: 'pie_chart',
    enabled: true,
    order: 1,
  ),
  DashboardWidgetConfig(
    id: 'recent_transactions',
    name: '\ucd5c\uadfc \uac70\ub798',
    icon: 'receipt_long',
    enabled: true,
    order: 2,
  ),
  DashboardWidgetConfig(
    id: 'payment_breakdown',
    name: '\uacb0\uc81c\uc218\ub2e8\ubcc4 \ud604\ud669',
    icon: 'credit_card',
    enabled: true,
    order: 3,
  ),
  DashboardWidgetConfig(
    id: 'asset_balance',
    name: '\uc790\uc0b0 \ud604\ud669',
    icon: 'account_balance',
    enabled: false,
    order: 4,
  ),
  DashboardWidgetConfig(
    id: 'private_summary',
    name: '\uac1c\uc778 \uac70\ub798 \uc694\uc57d',
    icon: 'lock',
    enabled: true,
    order: 5,
  ),
  DashboardWidgetConfig(
    id: 'spending_plans',
    name: '지출 계획',
    icon: 'event_note',
    enabled: false,
    order: 6,
  ),
  DashboardWidgetConfig(
    id: 'ai_insights',
    name: 'AI 인사이트',
    icon: 'auto_awesome',
    enabled: true,
    order: 7,
  ),
];
