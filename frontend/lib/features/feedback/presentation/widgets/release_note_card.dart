import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:budget_book/features/feedback/domain/entities/release_note.dart';
import '../../../../core/theme/bb_scale.dart';

class ReleaseNoteCard extends StatelessWidget {
  final ReleaseNote releaseNote;
  final VoidCallback? onTap;

  const ReleaseNoteCard({
    super.key,
    required this.releaseNote,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('yyyy.MM.dd');

    return Card(
      // ★세로는 호스트가 갖는다(`BbCardGap`). 가로만 남긴다.
      margin: EdgeInsets.symmetric(horizontal: context.bbSpace.xxl),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      releaseNote.version,
                      style: TextStyle(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (releaseNote.publishedAt != null)
                    Text(
                      dateFormat.format(releaseNote.publishedAt!),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    )
                  else
                    Text(
                      dateFormat.format(releaseNote.createdAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
              context.bbSpace.gapV(BbSpaceToken.lg),
              Text(
                releaseNote.title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              context.bbSpace.gapV(BbSpaceToken.xs),
              Text(
                releaseNote.content,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              if (!releaseNote.isPublished) ...[
                context.bbSpace.gapV(BbSpaceToken.lg),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withAlpha(100)),
                  ),
                  child: const Text(
                    '미게시',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
