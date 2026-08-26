import 'package:flutter/material.dart';
import 'package:budget_book/features/home/domain/entities/dashboard_widget_config.dart';
import '../../../../core/theme/bb_scale.dart';

/// Shows a bottom sheet for editing per-widget settings.
/// Renders appropriate controls based on widget type.
void showWidgetSettingsSheet({
  required BuildContext context,
  required DashboardWidgetConfig config,
  required void Function(Map<String, dynamic> newSettings) onSave,
}) {
  final merged = {
    ...defaultWidgetSettings[config.id] ?? {},
    ...config.settings,
  };

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _WidgetSettingsSheet(
      widgetId: config.id,
      widgetName: config.name,
      initialSettings: Map<String, dynamic>.from(merged),
      onSave: onSave,
    ),
  );
}

class _WidgetSettingsSheet extends StatefulWidget {
  final String widgetId;
  final String widgetName;
  final Map<String, dynamic> initialSettings;
  final void Function(Map<String, dynamic>) onSave;

  const _WidgetSettingsSheet({
    required this.widgetId,
    required this.widgetName,
    required this.initialSettings,
    required this.onSave,
  });

  @override
  State<_WidgetSettingsSheet> createState() => _WidgetSettingsSheetState();
}

class _WidgetSettingsSheetState extends State<_WidgetSettingsSheet> {
  late Map<String, dynamic> _settings;

  @override
  void initState() {
    super.initState();
    _settings = Map<String, dynamic>.from(widget.initialSettings);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Text(
                  '${widget.widgetName} 설정',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const Divider(),
          // Dynamic settings controls
          ..._buildControls(context),
          context.bbSpace.gapV(BbSpaceToken.xxl),
          // Save button
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                widget.onSave(_settings);
                Navigator.pop(context);
              },
              child: const Text('저장'),
            ),
          ),
          context.bbSpace.gapV(BbSpaceToken.xxl),
        ],
      ),
    );
  }

  List<Widget> _buildControls(BuildContext context) {
    switch (widget.widgetId) {
      case 'monthly_summary':
        return _buildCheckboxListControl(
          label: '표시 항목',
          key: 'showItems',
          options: {
            'income': '수입',
            'expense': '지출',
            'balance': '잔액',
            'savingRate': '저축률',
          },
        );
      case 'budget_usage':
        return [
          _buildDropdownControl(
            label: '차트 모드',
            key: 'chartMode',
            options: {'bar': '바 차트', 'pie': '파이 차트'},
          ),
        ];
      case 'recent_transactions':
        return [
          _buildDropdownControl(
            label: '표시 건수',
            key: 'count',
            options: {3: '3건', 5: '5건', 10: '10건'},
          ),
        ];
      case 'payment_breakdown':
        return [
          _buildDropdownControl(
            label: '정렬 기준',
            key: 'sortBy',
            options: {'amount': '금액순', 'count': '건수순'},
          ),
        ];
      case 'asset_balance':
        return [
          _buildDropdownControl(
            label: '표시 유형',
            key: 'showType',
            options: {
              'all': '전체',
              'bank': '은행만',
              'card': '카드만',
            },
          ),
        ];
      case 'spending_plans':
        return [
          _buildDropdownControl(
            label: '표시 상태',
            key: 'showStatus',
            options: {
              'active': '진행 중',
              'all': '전체',
              'completed': '완료',
            },
          ),
        ];
      case 'monthly_trend':
        return [
          _buildDropdownControl(
            label: '기간',
            key: 'months',
            options: {3: '3개월', 6: '6개월', 12: '12개월'},
          ),
          context.bbSpace.gapV(BbSpaceToken.lg),
          ..._buildCheckboxListControl(
            label: '표시 항목',
            key: 'showItems',
            options: {
              'income': '수입',
              'expense': '지출',
              'balance': '잔액',
            },
          ),
        ];
      case 'category_breakdown':
        return [
          _buildDropdownControl(
            label: '표시 유형',
            key: 'type',
            options: {'EXPENSE': '지출', 'INCOME': '수입'},
          ),
          context.bbSpace.gapV(BbSpaceToken.lg),
          _buildDropdownControl(
            label: '표시 개수',
            key: 'count',
            options: {3: '3개', 5: '5개', 10: '10개'},
          ),
        ];
      default:
        return [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('설정 가능한 항목이 없습니다.'),
          ),
        ];
    }
  }

  Widget _buildDropdownControl<T>({
    required String label,
    required String key,
    required Map<T, String> options,
  }) {
    final currentValue = _settings[key];
    // Find matching key, handling int/String type mismatches
    T? selectedKey;
    for (final entry in options.entries) {
      if (entry.key == currentValue) {
        selectedKey = entry.key;
        break;
      }
      if (entry.key.toString() == currentValue.toString()) {
        selectedKey = entry.key;
        break;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          DropdownButton<T>(
            value: selectedKey ?? options.keys.first,
            items: options.entries.map((e) {
              return DropdownMenuItem<T>(
                value: e.key,
                child: Text(e.value),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() => _settings[key] = val);
              }
            },
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCheckboxListControl({
    required String label,
    required String key,
    required Map<String, String> options,
  }) {
    final currentList = _settings[key];
    final selected = <String>{};
    if (currentList is List) {
      selected.addAll(currentList.cast<String>());
    }

    return [
      Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Text(label,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.w500)),
      ),
      ...options.entries.map((entry) {
        return CheckboxListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(entry.value),
          value: selected.contains(entry.key),
          onChanged: (checked) {
            setState(() {
              if (checked == true) {
                selected.add(entry.key);
              } else {
                // Don't allow deselecting all
                if (selected.length > 1) {
                  selected.remove(entry.key);
                }
              }
              _settings[key] = selected.toList();
            });
          },
        );
      }),
    ];
  }
}
