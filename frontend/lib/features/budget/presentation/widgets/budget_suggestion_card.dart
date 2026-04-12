import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:budget_book/features/ai/domain/entities/budget_suggestion.dart';

/// Card showing a budget adjustment suggestion from the smart analysis engine.
class BudgetSuggestionCard extends StatelessWidget {
  final List<BudgetSuggestion> suggestions;

  const BudgetSuggestionCard({super.key, required this.suggestions});

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final formatter = NumberFormat('#,###');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb_outline, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  '예산 조정 제안',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...suggestions.map((s) => _SuggestionItem(
                  suggestion: s,
                  formatter: formatter,
                  onAdjust: () => context.push(
                    '/budgets/edit/${s.budgetId}?amount=${s.suggestedAmount}',
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

class _SuggestionItem extends StatelessWidget {
  final BudgetSuggestion suggestion;
  final NumberFormat formatter;
  final VoidCallback onAdjust;

  const _SuggestionItem({
    required this.suggestion,
    required this.formatter,
    required this.onAdjust,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isIncrease = suggestion.isIncrease;
    final diffColor = isIncrease ? Colors.orange : Colors.green;
    final diffIcon = isIncrease ? Icons.arrow_upward : Icons.arrow_downward;
    final diffText = isIncrease ? '+' : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  suggestion.budgetName,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(diffIcon, size: 14, color: diffColor),
              const SizedBox(width: 2),
              Text(
                '$diffText${formatter.format(suggestion.difference)}원',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: diffColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Current vs suggested bar
          Row(
            children: [
              Text(
                '현재 ${formatter.format(suggestion.currentAmount)}원',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward, size: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
              const SizedBox(width: 8),
              Text(
                '제안 ${formatter.format(suggestion.suggestedAmount)}원',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (suggestion.reason.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              suggestion.reason,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                fontStyle: FontStyle.italic,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onAdjust,
              icon: const Icon(Icons.edit, size: 14),
              label: const Text('조정하기'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 28),
                textStyle: const TextStyle(fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
