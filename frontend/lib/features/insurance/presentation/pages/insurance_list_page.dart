import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:budget_book/core/utils/currency_formatter.dart';
import 'package:budget_book/core/widgets/error_widget.dart';
import 'package:budget_book/core/widgets/empty_state_widget.dart';
import 'package:budget_book/core/widgets/skeleton_loader.dart';
import 'package:budget_book/features/insurance/domain/entities/insurance.dart';
import 'package:budget_book/features/insurance/presentation/bloc/insurance_bloc.dart';
import 'package:budget_book/features/insurance/presentation/bloc/insurance_event.dart';
import 'package:budget_book/features/insurance/presentation/bloc/insurance_state.dart';
import 'package:budget_book/features/insurance/presentation/widgets/insurance_card.dart';

class InsuranceListPage extends StatefulWidget {
  const InsuranceListPage({super.key});

  @override
  State<InsuranceListPage> createState() => _InsuranceListPageState();
}

class _InsuranceListPageState extends State<InsuranceListPage> {
  bool _showActiveOnly = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('보험 관리'),
        actions: [
          FilterChip(
            label: Text(_showActiveOnly ? '활성만' : '전체'),
            selected: _showActiveOnly,
            onSelected: (value) {
              setState(() => _showActiveOnly = value);
              context.read<InsuranceBloc>().add(
                    LoadInsurances(activeOnly: value ? true : null),
                  );
            },
            showCheckmark: false,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: BlocConsumer<InsuranceBloc, InsuranceState>(
        listener: (context, state) {
          if (state is InsuranceError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          } else if (state is InsuranceLoaded &&
              state.operationError != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.operationError!),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          } else if (state is InsuranceLoaded &&
              state.operationSuccess != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.operationSuccess!)),
            );
          }
        },
        builder: (context, state) {
          return switch (state) {
            InsuranceInitial() || InsuranceLoading() =>
              const SkeletonLoader(itemCount: 5),
            InsuranceLoaded() => _buildLoaded(context, state),
            InsuranceError() => _buildError(context),
          };
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/insurances/create'),
        tooltip: '보험 추가',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildLoaded(BuildContext context, InsuranceLoaded state) {
    return Column(
      children: [
        // Summary card
        if (state.summary != null) _buildSummaryCard(context, state),
        // Quick stats if no summary yet
        if (state.summary == null)
          _buildQuickStats(context, state.insurances),
        const Divider(height: 1),
        Expanded(
          child: state.insurances.isEmpty
              ? _buildEmpty(context)
              : _buildGroupedList(context, state),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(BuildContext context, InsuranceLoaded state) {
    final theme = Theme.of(context);
    final summary = state.summary!;
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '이번 달 보험료',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${CurrencyFormatter.format(summary.totalPremium)}원',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    '${summary.activeCount}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  Text(
                    '활성 보험',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStats(BuildContext context, List<Insurance> insurances) {
    final theme = Theme.of(context);
    final activeCount = insurances.where((i) => i.isActive).length;
    final totalPremium = insurances
        .where((i) => i.isActive)
        .fold<int>(0, (sum, i) => sum + i.premiumAmount);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.shield, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            '보험료 합계: ${CurrencyFormatter.format(totalPremium)}원',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            '활성 $activeCount건',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupedList(BuildContext context, InsuranceLoaded state) {
    final grouped = state.groupedByType;
    // Sort type groups by Korean label
    final sortedTypes = grouped.keys.toList()
      ..sort((a, b) => insuranceTypeLabel(a).compareTo(insuranceTypeLabel(b)));

    return ListView.builder(
      key: const PageStorageKey('insurance_list'),
      itemCount: sortedTypes.length + 1,
      itemBuilder: (context, index) {
        if (index == sortedTypes.length) return const SizedBox(height: 88);
        final type = sortedTypes[index];
        final items = grouped[type]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TypeHeader(type: type, count: items.length),
            ...items.map((ins) => InsuranceCard(
                  insurance: ins,
                  onTap: () => context.push('/insurances/edit/${ins.id}'),
                  onDelete: () => _confirmDelete(context, ins),
                )),
          ],
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, Insurance insurance) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('보험 삭제'),
        content: Text('\'${insurance.name}\'을(를) 정말 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.read<InsuranceBloc>().add(DeleteInsurance(insurance.id));
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return EmptyStateWidget(
      icon: Icons.shield_outlined,
      title: '등록된 보험이 없습니다',
      subtitle: '보험 정보를 등록하고 보험료를 관리하세요',
      actionLabel: '보험 추가',
      onAction: () => context.push('/insurances/create'),
    );
  }

  Widget _buildError(BuildContext context) {
    return AppErrorWidget(
      message: '보험 목록을 불러오지 못했습니다',
      onRetry: () {
        context.read<InsuranceBloc>().add(const LoadInsurances());
      },
      showHomeButton: true,
    );
  }
}

class _TypeHeader extends StatelessWidget {
  final String type;
  final int count;

  const _TypeHeader({required this.type, required this.count});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = insuranceTypeColor(type);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.colorScheme.surfaceContainerHighest
          .withValues(alpha: 0.5),
      child: Row(
        children: [
          Icon(insuranceTypeIcon(type), size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            insuranceTypeLabel(type),
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '($count)',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}
