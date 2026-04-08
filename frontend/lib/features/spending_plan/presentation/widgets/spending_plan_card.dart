import 'package:flutter/material.dart';
import 'package:budget_book/core/utils/currency_formatter.dart';
import 'package:budget_book/features/spending_plan/domain/entities/spending_plan.dart';

/// Maps spending plan status to Korean label.
String statusLabel(String status) {
  switch (status) {
    case 'WISHLIST':
      return '구매 목록';
    case 'PLANNED':
      return '계획됨';
    case 'COMPLETED':
      return '완료';
    case 'SKIPPED':
      return '건너뜀';
    case 'OVERDUE':
      return '기한초과';
    default:
      return status;
  }
}

/// Maps spending plan status to icon.
IconData statusIcon(String status) {
  switch (status) {
    case 'WISHLIST':
      return Icons.shopping_cart;
    case 'PLANNED':
      return Icons.schedule;
    case 'COMPLETED':
      return Icons.check_circle;
    case 'SKIPPED':
      return Icons.skip_next;
    case 'OVERDUE':
      return Icons.warning;
    default:
      return Icons.help_outline;
  }
}

/// Maps spending plan status to color.
Color statusColor(String status) {
  switch (status) {
    case 'WISHLIST':
      return Colors.purple;
    case 'PLANNED':
      return Colors.blue;
    case 'COMPLETED':
      return Colors.green;
    case 'SKIPPED':
      return Colors.grey;
    case 'OVERDUE':
      return Colors.red;
    default:
      return Colors.grey;
  }
}

/// Maps priority to color.
Color priorityColor(String priority) {
  switch (priority) {
    case 'HIGH':
      return Colors.red;
    case 'MEDIUM':
      return Colors.orange;
    case 'LOW':
      return Colors.blue;
    default:
      return Colors.grey;
  }
}

/// Maps priority to Korean label.
String priorityLabel(String priority) {
  switch (priority) {
    case 'HIGH':
      return '높음';
    case 'MEDIUM':
      return '보통';
    case 'LOW':
      return '낮음';
    default:
      return priority;
  }
}

class SpendingPlanCard extends StatelessWidget {
  final SpendingPlan plan;
  final VoidCallback? onTap;
  final VoidCallback? onComplete;
  final VoidCallback? onSkip;
  final VoidCallback? onDelete;
  final VoidCallback? onLinkTransaction;
  final VoidCallback? onUnlinkTransaction;

  const SpendingPlanCard({
    super.key,
    required this.plan,
    this.onTap,
    this.onComplete,
    this.onSkip,
    this.onDelete,
    this.onLinkTransaction,
    this.onUnlinkTransaction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = statusColor(plan.status);
    final canAct = plan.status == 'PLANNED' || plan.status == 'OVERDUE';

    return Dismissible(
      key: Key(plan.id),
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        color: Colors.green,
        child: const Icon(Icons.check, color: Colors.white),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.grey,
        child: const Icon(Icons.skip_next, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        if (!canAct) return false;
        if (direction == DismissDirection.startToEnd) {
          onComplete?.call();
        } else {
          onSkip?.call();
        }
        return false;
      },
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(statusIcon(plan.status), color: color, size: 20),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                plan.name,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  decoration: plan.status == 'SKIPPED'
                      ? TextDecoration.lineThrough
                      : null,
                  color: plan.status == 'SKIPPED'
                      ? theme.colorScheme.onSurface.withValues(alpha: 0.4)
                      : null,
                ),
              ),
            ),
            if (plan.categoryName != null)
              Container(
                margin: const EdgeInsets.only(left: 4),
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  plan.categoryName!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
          ],
        ),
        subtitle: _buildSubtitle(theme),
        trailing: Text(
          '${CurrencyFormatter.format(plan.amount)}원',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        onTap: onTap,
        onLongPress: onDelete != null
            ? () => _showOptionsMenu(context)
            : null,
      ),
    );
  }

  void _showOptionsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onTap != null)
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('수정'),
                onTap: () {
                  Navigator.pop(ctx);
                  onTap?.call();
                },
              ),
            if (onComplete != null && (plan.status == 'PLANNED' || plan.status == 'OVERDUE'))
              ListTile(
                leading: const Icon(Icons.check_circle, color: Colors.green),
                title: const Text('완료'),
                onTap: () {
                  Navigator.pop(ctx);
                  onComplete?.call();
                },
              ),
            if (onLinkTransaction != null &&
                plan.linkedTransactionId == null &&
                (plan.status == 'PLANNED' || plan.status == 'OVERDUE'))
              ListTile(
                leading: const Icon(Icons.link, color: Colors.blue),
                title: const Text('기존 거래 연결'),
                onTap: () {
                  Navigator.pop(ctx);
                  onLinkTransaction?.call();
                },
              ),
            if (onUnlinkTransaction != null && plan.linkedTransactionId != null)
              ListTile(
                leading: const Icon(Icons.link_off, color: Colors.orange),
                title: const Text('거래 연결 해제'),
                onTap: () {
                  Navigator.pop(ctx);
                  onUnlinkTransaction?.call();
                },
              ),
            if (onSkip != null && (plan.status == 'PLANNED' || plan.status == 'OVERDUE'))
              ListTile(
                leading: const Icon(Icons.skip_next, color: Colors.grey),
                title: const Text('건너뛰기'),
                onTap: () {
                  Navigator.pop(ctx);
                  onSkip?.call();
                },
              ),
            if (onDelete != null)
              ListTile(
                leading: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
                title: Text('삭제', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                onTap: () {
                  Navigator.pop(ctx);
                  onDelete?.call();
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubtitle(ThemeData theme) {
    if (plan.status == 'COMPLETED' && plan.actualAmount != null) {
      final variance = plan.variance;
      final varianceStr = variance != null
          ? CurrencyFormatter.formatWithSign(variance)
          : '';
      final dateInfo = <String>[];
      if (plan.targetDate != null) dateInfo.add('계획 ${plan.targetDate}');
      if (plan.completedDate != null) dateInfo.add('완료 ${plan.completedDate}');
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '계획 ${CurrencyFormatter.format(plan.amount)} → 실제 ${CurrencyFormatter.format(plan.actualAmount!)}원 ($varianceStr)',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: variance != null && variance < 0
                  ? Colors.green
                  : variance != null && variance > 0
                      ? Colors.red
                      : null,
            ),
          ),
          if (dateInfo.isNotEmpty)
            Text(
              dateInfo.join(' → '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                fontSize: 11,
              ),
            ),
        ],
      );
    }

    final parts = <String>[];
    if (plan.linkedTransactionId != null && plan.status != 'COMPLETED') {
      parts.add('거래 연결됨');
    }
    if (plan.paymentMethodName != null) {
      parts.add(plan.paymentMethodName!);
    }
    if (plan.isRecurring && plan.frequency != null) {
      parts.add(plan.frequency == 'WEEKLY' ? '매주 반복' : '매월 반복');
    }
    parts.add(statusLabel(plan.status));
    return Text(
      parts.join(' | '),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
