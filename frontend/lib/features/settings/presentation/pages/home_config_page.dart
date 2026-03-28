import 'package:flutter/material.dart';
import 'package:budget_book/features/home/domain/entities/dashboard_widget_config.dart';
import 'package:budget_book/features/home/data/home_config_service.dart';

/// Settings page that allows the user to reorder and toggle dashboard widgets.
class HomeConfigPage extends StatefulWidget {
  const HomeConfigPage({super.key});

  @override
  State<HomeConfigPage> createState() => _HomeConfigPageState();
}

class _HomeConfigPageState extends State<HomeConfigPage> {
  List<DashboardWidgetConfig> _configs = [];
  bool _loading = true;
  final _service = HomeConfigService();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final configs = await _service.loadConfig();
    configs.sort((a, b) => a.order.compareTo(b.order));
    if (mounted) {
      setState(() {
        _configs = configs;
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    final updated = _configs
        .asMap()
        .entries
        .map((e) => e.value.copyWith(order: e.key))
        .toList();
    await _service.saveConfig(updated);
  }

  IconData _getIconData(String name) {
    switch (name) {
      case 'account_balance_wallet':
        return Icons.account_balance_wallet;
      case 'pie_chart':
        return Icons.pie_chart;
      case 'receipt_long':
        return Icons.receipt_long;
      case 'credit_card':
        return Icons.credit_card;
      case 'account_balance':
        return Icons.account_balance;
      case 'lock':
        return Icons.lock;
      default:
        return Icons.widgets;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('\ud648 \ud654\uba74 \uad6c\uc131'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ReorderableListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _configs.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex--;
                  final item = _configs.removeAt(oldIndex);
                  _configs.insert(newIndex, item);
                });
                _save();
              },
              itemBuilder: (context, index) {
                final config = _configs[index];
                return Material(
                  key: ValueKey(config.id),
                  child: ListTile(
                    leading: Icon(
                      _getIconData(config.icon),
                      color: config.enabled
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.38),
                    ),
                    title: Text(
                      config.name,
                      style: TextStyle(
                        color: config.enabled
                            ? null
                            : Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.38),
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: config.enabled,
                          onChanged: (val) {
                            setState(() {
                              _configs[index] = config.copyWith(enabled: val);
                            });
                            _save();
                          },
                        ),
                        ReorderableDragStartListener(
                          index: index,
                          child: const Icon(Icons.drag_handle),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
