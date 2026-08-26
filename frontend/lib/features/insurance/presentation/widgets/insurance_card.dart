import 'package:flutter/material.dart';
import 'package:budget_book/core/utils/currency_formatter.dart';
import 'package:budget_book/features/insurance/domain/entities/insurance.dart';
import '../../../../core/theme/bb_scale.dart';

/// Maps insurance type to Korean label.
String insuranceTypeLabel(String type) {
  switch (type) {
    case 'LIFE':
      return '생명보험';
    case 'HEALTH':
      return '건강보험';
    case 'CAR':
      return '자동차보험';
    case 'FIRE':
      return '화재보험';
    case 'ACCIDENT':
      return '상해보험';
    case 'OTHER':
      return '기타';
    default:
      return type;
  }
}

/// Maps insurance type to icon.
IconData insuranceTypeIcon(String type) {
  switch (type) {
    case 'LIFE':
      return Icons.favorite;
    case 'HEALTH':
      return Icons.local_hospital;
    case 'CAR':
      return Icons.directions_car;
    case 'FIRE':
      return Icons.local_fire_department;
    case 'ACCIDENT':
      return Icons.personal_injury;
    case 'OTHER':
      return Icons.shield;
    default:
      return Icons.shield;
  }
}

/// Maps insurance type to color.
Color insuranceTypeColor(String type) {
  switch (type) {
    case 'LIFE':
      return Colors.pink;
    case 'HEALTH':
      return Colors.green;
    case 'CAR':
      return Colors.blue;
    case 'FIRE':
      return Colors.orange;
    case 'ACCIDENT':
      return Colors.red;
    case 'OTHER':
      return Colors.grey;
    default:
      return Colors.grey;
  }
}

/// Maps payment cycle to Korean label.
String paymentCycleLabel(String cycle) {
  switch (cycle) {
    case 'MONTHLY':
      return '매월';
    case 'QUARTERLY':
      return '분기';
    case 'SEMI_ANNUAL':
      return '반기';
    case 'YEARLY':
      return '연간';
    default:
      return cycle;
  }
}

class InsuranceCard extends StatelessWidget {
  final Insurance insurance;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const InsuranceCard({
    super.key,
    required this.insurance,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final typeColor = insuranceTypeColor(insurance.insuranceType);

    return Dismissible(
      key: Key(insurance.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: theme.colorScheme.error,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        onDelete?.call();
        return false;
      },
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: typeColor.withValues(alpha: 0.15),
          child: Icon(
            insuranceTypeIcon(insurance.insuranceType),
            color: typeColor,
            size: context.bbType.iconSm,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                insurance.name,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: insurance.isActive
                      ? null
                      : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ),
            if (!insurance.isActive)
              Container(
                margin: const EdgeInsets.only(left: 4),
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '비활성',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ),
          ],
        ),
        subtitle: _buildSubtitle(theme),
        trailing: Text(
          '${CurrencyFormatter.format(insurance.premiumAmount)}원',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: insurance.isActive
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface.withValues(alpha: 0.4),
          ),
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildSubtitle(ThemeData theme) {
    final parts = <String>[];
    if (insurance.insurer != null && insurance.insurer!.isNotEmpty) {
      parts.add(insurance.insurer!);
    }
    parts.add(paymentCycleLabel(insurance.paymentCycle));
    if (insurance.paymentDay != null) {
      parts.add('${insurance.paymentDay}일');
    }
    return Text(
      parts.join(' | '),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
