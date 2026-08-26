import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:budget_book/features/couple/domain/entities/invitation.dart';
import '../../../../core/theme/bb_scale.dart';

class InvitationCodeWidget extends StatelessWidget {
  final Invitation invitation;

  const InvitationCodeWidget({super.key, required this.invitation});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              '초대 코드',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            context.bbSpace.gapV(BbSpaceToken.xxl),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primaryContainer
                    .withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: SelectableText(
                invitation.code,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                    ),
              ),
            ),
            context.bbSpace.gapV(BbSpaceToken.xxl),
            OutlinedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: invitation.code));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('코드가 복사되었습니다')),
                );
              },
              icon: Icon(Icons.copy, size: context.bbType.iconSm),
              label: const Text('코드 복사'),
            ),
            context.bbSpace.gapV(BbSpaceToken.xl),
            Text(
              '만료: ${_formatExpiry(invitation.expiresAt)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatExpiry(DateTime expiresAt) {
    final remaining = expiresAt.difference(DateTime.now());
    if (remaining.isNegative) return '만료됨';
    if (remaining.inHours >= 1) {
      return '${remaining.inHours}시간 ${remaining.inMinutes % 60}분 남음';
    }
    return '${remaining.inMinutes}분 남음';
  }
}
