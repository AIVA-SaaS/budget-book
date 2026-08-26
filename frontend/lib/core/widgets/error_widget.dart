import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/bb_scale.dart';

/// A reusable error widget that displays an error icon, message,
/// an optional retry button, and an optional "go home" button.
///
/// Use this across all list/data pages when handling error states
/// to provide a consistent user experience.
class AppErrorWidget extends StatelessWidget {
  /// The error message to display.
  final String message;

  /// Callback invoked when the user taps the "다시 시도" (retry) button.
  /// If null, the retry button is hidden.
  final VoidCallback? onRetry;

  /// Whether to show a "홈으로" (go home) button that navigates to '/home'.
  final bool showHomeButton;

  const AppErrorWidget({
    super.key,
    required this.message,
    this.onRetry,
    this.showHomeButton = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: theme.colorScheme.error,
            ),
            context.bbSpace.gapV(BbSpaceToken.xxl),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            if (onRetry != null) ...[
              context.bbSpace.gapV(BbSpaceToken.xxl),
              FilledButton.icon(
                onPressed: onRetry,
                icon: Icon(Icons.refresh, size: context.bbType.iconSm),
                label: const Text('다시 시도'),
              ),
            ],
            if (showHomeButton) ...[
              context.bbSpace.gapV(BbSpaceToken.lg),
              TextButton.icon(
                onPressed: () => context.go('/home'),
                icon: Icon(Icons.home_outlined, size: context.bbType.iconSm),
                label: const Text('홈으로'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
