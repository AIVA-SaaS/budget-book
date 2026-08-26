import 'package:flutter/material.dart';
import 'package:budget_book/features/couple/domain/entities/user_summary.dart';
import '../../../../core/theme/bb_scale.dart';

class CoupleInfoWidget extends StatelessWidget {
  final UserSummary partner;

  const CoupleInfoWidget({super.key, required this.partner});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundImage: partner.profileImageUrl != null
                  ? NetworkImage(partner.profileImageUrl!)
                  : null,
              child: partner.profileImageUrl == null
                  ? Text(
                      partner.nickname.isNotEmpty
                          ? partner.nickname[0]
                          : '?',
                      style: TextStyle(fontSize: context.bbType.display),
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    partner.nickname,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  context.bbSpace.gapV(BbSpaceToken.xs),
                  Text(
                    '연결됨',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.green,
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
}
