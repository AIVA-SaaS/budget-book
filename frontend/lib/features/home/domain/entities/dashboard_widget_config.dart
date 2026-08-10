/// Configuration for a single dashboard widget (visibility + order + settings).
class DashboardWidgetConfig {
  final String id;
  final String name;
  final String icon;
  final bool enabled;
  final int order;
  final Map<String, dynamic> settings;

  const DashboardWidgetConfig({
    required this.id,
    required this.name,
    required this.icon,
    this.enabled = true,
    required this.order,
    this.settings = const {},
  });

  DashboardWidgetConfig copyWith({
    bool? enabled,
    int? order,
    Map<String, dynamic>? settings,
  }) =>
      DashboardWidgetConfig(
        id: id,
        name: name,
        icon: icon,
        enabled: enabled ?? this.enabled,
        order: order ?? this.order,
        settings: settings ?? this.settings,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'icon': icon,
        'enabled': enabled,
        'order': order,
        'settings': settings,
      };

  factory DashboardWidgetConfig.fromJson(Map<String, dynamic> json) =>
      DashboardWidgetConfig(
        id: json['id'] as String,
        name: json['name'] as String,
        icon: json['icon'] as String,
        enabled: json['enabled'] as bool? ?? true,
        order: json['order'] as int? ?? 0,
        settings: json['settings'] != null
            ? Map<String, dynamic>.from(json['settings'] as Map)
            : const {},
      );
}

/// Default widget settings per widget type.
const defaultWidgetSettings = <String, Map<String, dynamic>>{
  'monthly_summary': {
    'showItems': ['income', 'expense', 'balance', 'savingRate'],
  },
  'budget_usage': {
    'chartMode': 'bar',
  },
  'recent_transactions': {
    'count': 5,
  },
  'payment_breakdown': {
    'sortBy': 'amount',
  },
  'asset_balance': {
    'showType': 'all',
  },
  'spending_plans': {
    'showStatus': 'active',
  },
  'monthly_trend': {
    'months': 6,
    'showItems': ['income', 'expense'],
  },
  'category_breakdown': {
    'count': 5,
    'type': 'EXPENSE',
  },
};

/// Default dashboard widget configuration.
/// Order matters; asset_balance, spending_plans default to OFF.
/// monthly_trend and category_breakdown are new widgets (default OFF).
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
    name: '\uc9c0\ucd9c \uacc4\ud68d',
    icon: 'event_note',
    enabled: false,
    order: 6,
  ),
  DashboardWidgetConfig(
    id: 'ai_insights',
    name: 'AI \uc778\uc0ac\uc774\ud2b8',
    icon: 'auto_awesome',
    enabled: true,
    order: 7,
  ),
  DashboardWidgetConfig(
    id: 'monthly_trend',
    name: '\uc6d4\ubcc4 \ucd94\uc774',
    icon: 'show_chart',
    enabled: false,
    order: 8,
  ),
  DashboardWidgetConfig(
    id: 'category_breakdown',
    name: '\uce74\ud14c\uace0\ub9ac\ubcc4 \ud604\ud669',
    icon: 'donut_large',
    enabled: false,
    order: 9,
  ),
];
