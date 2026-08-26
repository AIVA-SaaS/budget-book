import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:budget_book/core/widgets/bb_card_tile.dart';
import 'package:budget_book/core/utils/ui_helpers.dart';
import 'package:budget_book/core/theme/bb_scale.dart';
import 'package:budget_book/features/statistics/domain/entities/category_statistics.dart';
import 'package:budget_book/core/utils/currency_formatter.dart';

enum CategoryViewMode { group, category }

class CategoryBreakdownTab extends StatefulWidget {
  final List<CategoryStatistics> categoryStats;
  final bool isLoading;
  final String? error;
  final String selectedType;
  final ValueChanged<String> onTypeChanged;
  final int year;
  final int month;

  const CategoryBreakdownTab({
    super.key,
    required this.categoryStats,
    this.isLoading = false,
    this.error,
    this.selectedType = 'EXPENSE',
    required this.onTypeChanged,
    required this.year,
    required this.month,
  });

  @override
  State<CategoryBreakdownTab> createState() => _CategoryBreakdownTabState();
}

class _CategoryBreakdownTabState extends State<CategoryBreakdownTab> {
  CategoryViewMode _viewMode = CategoryViewMode.group;
  String? _selectedGroupId;
  String? _selectedGroupName;

  static const _defaultColors = [
    Color(0xFFFF5733),
    Color(0xFF2196F3),
    Color(0xFF4CAF50),
    Color(0xFFFF9800),
    Color(0xFF9C27B0),
    Color(0xFF00BCD4),
    Color(0xFFE91E63),
    Color(0xFF795548),
    Color(0xFF607D8B),
    Color(0xFFCDDC39),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Type toggle (지출/수입)
        Padding(
          padding:
              context.bbSpace.symmetric(h: BbSpaceToken.xl, v: BbSpaceToken.md),
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'EXPENSE', label: Text('지출')),
              ButtonSegment(value: 'INCOME', label: Text('수입')),
            ],
            selected: {widget.selectedType},
            onSelectionChanged: (set) => widget.onTypeChanged(set.first),
          ),
        ),
        // View mode toggle
        Padding(
          padding: context.bbSpace.symmetric(h: BbSpaceToken.xl),
          child: Row(
            children: [
              if (_selectedGroupId != null) ...[
                // Back button when viewing a specific group
                IconButton(
                  icon: Icon(Icons.arrow_back, size: context.bbType.iconMd),
                  onPressed: () => setState(() {
                    _selectedGroupId = null;
                    _selectedGroupName = null;
                  }),
                  tooltip: '그룹 목록으로',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                context.bbSpace.gapH(BbSpaceToken.md),
                Text(
                  _selectedGroupName ?? '',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
              ] else ...[
                Expanded(
                  child: SegmentedButton<CategoryViewMode>(
                    segments: const [
                      ButtonSegment(
                        value: CategoryViewMode.group,
                        label: Text('그룹별'),
                      ),
                      ButtonSegment(
                        value: CategoryViewMode.category,
                        label: Text('전체 카테고리'),
                      ),
                    ],
                    selected: {_viewMode},
                    onSelectionChanged: (set) =>
                        setState(() => _viewMode = set.first),
                  ),
                ),
              ],
            ],
          ),
        ),
        context.bbSpace.gapV(BbSpaceToken.md),
        Expanded(child: _buildContent(context)),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    if (widget.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (widget.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline,
                size: context.bbType.iconLg * 1.5, color: Colors.red),
            context.bbSpace.gapV(BbSpaceToken.xl),
            Text(widget.error!, textAlign: TextAlign.center),
          ],
        ),
      );
    }
    if (widget.categoryStats.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.pie_chart_outline,
                size: context.bbType.iconLg * 2,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.3)),
            context.bbSpace.gapV(BbSpaceToken.xl),
            Text('이 달에 기록된 거래가 없습니다',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5))),
          ],
        ),
      );
    }

    // Determine which data to display
    if (_selectedGroupId != null) {
      return _buildSubcategoryView(context);
    }

    switch (_viewMode) {
      case CategoryViewMode.group:
        return _buildGroupView(context);
      case CategoryViewMode.category:
        return _buildAllCategoryView(context);
    }
  }

  /// Group view: aggregate by groupName, tap to drill down
  Widget _buildGroupView(BuildContext context) {
    final groupMap = <String, _GroupData>{};
    for (final stat in widget.categoryStats) {
      final gId = stat.category.groupId ?? 'ungrouped';
      final gName = stat.category.groupName ?? '(그룹 미할당)';
      groupMap.putIfAbsent(gId, () => _GroupData(id: gId, name: gName));
      groupMap[gId]!.amount += stat.amount;
      groupMap[gId]!.count += stat.transactionCount;
    }

    final totalAmount = groupMap.values.fold(0, (sum, g) => sum + g.amount);
    final groups = groupMap.values.toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));

    for (final g in groups) {
      g.percentage = totalAmount > 0 ? g.amount / totalAmount * 100 : 0;
    }

    return SingleChildScrollView(
      padding: context.bbSpace.all(BbSpaceToken.xl),
      child: Column(
        children: [
          SizedBox(
            height: 220,
            child: PieChart(PieChartData(
              sections: groups.asMap().entries.map((entry) {
                final color = _defaultColors[entry.key % _defaultColors.length];
                final g = entry.value;
                return PieChartSectionData(
                  value: g.amount.toDouble(),
                  title: g.percentage >= 5
                      ? '${g.percentage.toStringAsFixed(0)}%'
                      : '',
                  color: color,
                  radius: 60,
                  titleStyle: TextStyle(
                      fontSize: context.bbType.label,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                );
              }).toList(),
              centerSpaceRadius: 40,
              sectionsSpace: 2,
            )),
          ),
          context.bbSpace.gapV(BbSpaceToken.xxl),
          // ★항목 사이는 **호스트**가 소유한다.
          ...bbCardItems(context, groups.asMap().entries.map((entry) {
            final index = entry.key;
            final g = entry.value;
            final color = _defaultColors[index % _defaultColors.length];
            return _buildListItem(
              context,
              color: color,
              name: g.name,
              amount: g.amount,
              percentage: g.percentage,
              count: g.count,
              // ungrouped 도 drill-down 가능 (sub-view 에서 미할당 카테고리 표시).
              onTap: () => setState(() {
                _selectedGroupId = g.id;
                _selectedGroupName = g.name;
              }),
            );
          }).toList()),
        ],
      ),
    );
  }

  /// Subcategory view: categories within a selected group
  Widget _buildSubcategoryView(BuildContext context) {
    // ungrouped 가상 그룹 ID 처리: 카테고리의 실제 groupId == null 매치.
    final isUngrouped = _selectedGroupId == 'ungrouped';
    final filtered = widget.categoryStats
        .where((s) => isUngrouped
            ? s.category.groupId == null
            : s.category.groupId == _selectedGroupId)
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));

    final totalAmount = filtered.fold(0, (sum, s) => sum + s.amount);

    return SingleChildScrollView(
      padding: context.bbSpace.all(BbSpaceToken.xl),
      child: Column(
        children: [
          SizedBox(
            height: 220,
            child: PieChart(PieChartData(
              sections: filtered.asMap().entries.map((entry) {
                final stat = entry.value;
                final color = _getStatColor(stat, entry.key);
                final pct =
                    totalAmount > 0 ? stat.amount / totalAmount * 100 : 0.0;
                return PieChartSectionData(
                  value: stat.amount.toDouble(),
                  title: pct >= 5 ? '${pct.toStringAsFixed(0)}%' : '',
                  color: color,
                  radius: 60,
                  titleStyle: TextStyle(
                      fontSize: context.bbType.label,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                );
              }).toList(),
              centerSpaceRadius: 40,
              sectionsSpace: 2,
            )),
          ),
          context.bbSpace.gapV(BbSpaceToken.xxl),
          // ★항목 사이는 **호스트**가 소유한다.
          ...bbCardItems(context, filtered.asMap().entries.map((entry) {
            final stat = entry.value;
            final color = _getStatColor(stat, entry.key);
            final pct = totalAmount > 0 ? stat.amount / totalAmount * 100 : 0.0;
            return _buildListItem(
              context,
              color: color,
              name: stat.category.name,
              amount: stat.amount,
              percentage: pct,
              count: stat.transactionCount,
              onTap: () {
                final catName = Uri.encodeComponent(stat.category.name);
                context.go(
                    '/transactions?year=${widget.year}&month=${widget.month}&categoryId=${stat.category.id}&categoryName=$catName');
              },
            );
          }).toList()),
        ],
      ),
    );
  }

  /// All categories view: flat list regardless of group
  Widget _buildAllCategoryView(BuildContext context) {
    final sorted = widget.categoryStats.toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));

    return SingleChildScrollView(
      padding: context.bbSpace.all(BbSpaceToken.xl),
      child: Column(
        children: [
          SizedBox(
            height: 220,
            child: PieChart(PieChartData(
              sections: sorted.asMap().entries.map((entry) {
                final stat = entry.value;
                final color = _getStatColor(stat, entry.key);
                return PieChartSectionData(
                  value: stat.amount.toDouble(),
                  title: stat.percentage >= 5
                      ? '${stat.percentage.toStringAsFixed(0)}%'
                      : '',
                  color: color,
                  radius: 60,
                  titleStyle: TextStyle(
                      fontSize: context.bbType.label,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                );
              }).toList(),
              centerSpaceRadius: 40,
              sectionsSpace: 2,
            )),
          ),
          context.bbSpace.gapV(BbSpaceToken.xxl),
          // ★항목 사이는 **호스트**가 소유한다.
          ...bbCardItems(context, sorted.asMap().entries.map((entry) {
            final stat = entry.value;
            final color = _getStatColor(stat, entry.key);
            return _buildListItem(
              context,
              color: color,
              name: stat.category.displayName,
              amount: stat.amount,
              percentage: stat.percentage,
              count: stat.transactionCount,
              onTap: () {
                final catName = Uri.encodeComponent(stat.category.name);
                context.go(
                    '/transactions?year=${widget.year}&month=${widget.month}&categoryId=${stat.category.id}&categoryName=$catName');
              },
            );
          }).toList()),
        ],
      ),
    );
  }

  Color _getStatColor(CategoryStatistics stat, int index) {
    if (stat.category.color != null && stat.category.color!.isNotEmpty) {
      return UIHelpers.parseColor(stat.category.color,
          fallback: _defaultColors[index % _defaultColors.length]);
    }
    return _defaultColors[index % _defaultColors.length];
  }

  Widget _buildListItem(
    BuildContext context, {
    required Color color,
    required String name,
    required int amount,
    required double percentage,
    required int count,
    VoidCallback? onTap,
  }) {
    // 세로 리듬은 BbCardTile 이 소유한다(사이 20.0dp @390 · 25.0 @960).
    // 가로는 종전 값 그대로: margin `md`(테마가 주던 값) · 내부 padding `lg`.
    return BbCardTile(
      onTap: onTap,
      hMargin: BbSpaceToken.md,
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          context.bbSpace.gapH(BbSpaceToken.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: Theme.of(context).textTheme.bodyLarge),
                context.bbSpace.gapV(BbSpaceToken.xs),
                ClipRRect(
                  borderRadius: context.bbSpace.radius(BbSpaceToken.xs),
                  child: LinearProgressIndicator(
                    value: (percentage / 100).clamp(0.0, 1.0),
                    backgroundColor: color.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
          context.bbSpace.gapH(BbSpaceToken.lg),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${CurrencyFormatter.format(amount)}원',
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                '${percentage.toStringAsFixed(1)}% ($count건)',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5),
                    ),
              ),
            ],
          ),
          if (onTap != null) ...[
            context.bbSpace.gapH(BbSpaceToken.xs),
            Icon(Icons.chevron_right,
                size: context.bbType.iconSm,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.3)),
          ],
        ],
      ),
    );
  }
}

class _GroupData {
  final String id;
  final String name;
  int amount = 0;
  int count = 0;
  double percentage = 0;

  _GroupData({required this.id, required this.name});
}
